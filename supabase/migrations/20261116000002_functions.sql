-- Creya schema, part 2: server-side behaviour.
-- Helpers live in the `private` schema, which the API does not expose, so
-- the app can only reach the three public functions at the bottom.

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

-- True when either person has blocked the other.
create function private.is_blocked_between(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.blocks
    where (blocker_id = a and blocked_id = b)
       or (blocker_id = b and blocked_id = a)
  );
$$;

-- Returns the chat for a pair of people, creating it if needed.
create function private.ensure_chat(a uuid, b uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_chat_id uuid;
begin
  insert into public.chats (user_a, user_b)
  values (least(a, b), greatest(a, b))
  on conflict (user_a, user_b) do nothing
  returning id into v_chat_id;

  if v_chat_id is null then
    select id into v_chat_id
    from public.chats
    where user_a = least(a, b) and user_b = greatest(a, b);
  end if;
  return v_chat_id;
end;
$$;

revoke all on function private.is_blocked_between(uuid, uuid) from public;
revoke all on function private.ensure_chat(uuid, uuid) from public;
grant execute on function private.is_blocked_between(uuid, uuid)
  to authenticated;

-- ---- Triggers --------------------------------------------------------------

create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function private.set_updated_at();

create trigger collab_posts_set_updated_at
  before update on public.collab_posts
  for each row execute function private.set_updated_at();

-- Gives every new account a profile, prefilled with the name from Google.
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, name)
  values (
    new.id,
    left(
      coalesce(
        new.raw_user_meta_data ->> 'full_name',
        new.raw_user_meta_data ->> 'name',
        ''
      ),
      80
    )
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- A right swipe sends a connection request. If the other person had already
-- asked, it accepts theirs instead and opens the chat.
create function private.handle_swipe()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing public.connections;
begin
  if new.direction <> 'right'
     or private.is_blocked_between(new.swiper_id, new.target_id) then
    return new;
  end if;

  select * into v_existing
  from public.connections
  where least(requester_id, addressee_id)
          = least(new.swiper_id, new.target_id)
    and greatest(requester_id, addressee_id)
          = greatest(new.swiper_id, new.target_id);

  if not found then
    insert into public.connections (requester_id, addressee_id)
    values (new.swiper_id, new.target_id)
    on conflict do nothing;
  elsif v_existing.status = 'pending'
        and v_existing.addressee_id = new.swiper_id then
    update public.connections
    set status = 'accepted', responded_at = now()
    where id = v_existing.id;
    perform private.ensure_chat(new.swiper_id, new.target_id);
  end if;
  return new;
end;
$$;

create trigger on_swipe
  after insert on public.swipes
  for each row execute function private.handle_swipe();

-- Keeps the chat list ordered by latest activity.
create function private.handle_new_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.chats
  set last_message_at = new.created_at
  where id = new.chat_id;
  return new;
end;
$$;

create trigger on_message_created
  after insert on public.messages
  for each row execute function private.handle_new_message();

-- ---- Functions the app calls ----------------------------------------------

-- Accept or decline a connection request sent to the caller.
-- Returns the chat id when accepted, null when declined.
create function public.respond_to_connection(
  p_connection_id uuid,
  p_accept boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_connection public.connections;
begin
  update public.connections
  set status = case when p_accept then 'accepted' else 'declined' end
               ::public.request_status,
      responded_at = now()
  where id = p_connection_id
    and addressee_id = (select auth.uid())
    and status = 'pending'
  returning * into v_connection;

  if not found then
    raise exception 'Request not found or already answered'
      using errcode = 'P0002';
  end if;
  if not p_accept then
    return null;
  end if;
  return private.ensure_chat(
    v_connection.requester_id,
    v_connection.addressee_id
  );
end;
$$;

-- Accept or decline an application to one of the caller's collab posts.
-- Returns the chat id when accepted, null when declined.
create function public.respond_to_application(
  p_application_id uuid,
  p_accept boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_application public.collab_applications;
begin
  update public.collab_applications a
  set status = case when p_accept then 'accepted' else 'declined' end
               ::public.request_status,
      responded_at = now()
  from public.collab_posts p
  where a.id = p_application_id
    and p.id = a.post_id
    and p.owner_id = (select auth.uid())
    and a.status = 'pending'
  returning a.* into v_application;

  if not found then
    raise exception 'Application not found or already answered'
      using errcode = 'P0002';
  end if;
  if not p_accept then
    return null;
  end if;
  return private.ensure_chat(
    (select auth.uid()),
    v_application.applicant_id
  );
end;
$$;

-- The Discover deck: onboarded people the caller has not swiped, is not
-- already connected to and has no block with. Runs with the caller's own
-- permissions, so the row-level rules still apply.
create function public.discover_deck(p_limit integer default 20)
returns setof public.profiles
language sql
stable
security invoker
set search_path = ''
as $$
  select p.*
  from public.profiles p
  where p.id <> (select auth.uid())
    and p.onboarded_at is not null
    and not exists (
      select 1 from public.swipes s
      where s.swiper_id = (select auth.uid()) and s.target_id = p.id
    )
    and not exists (
      select 1 from public.connections c
      where (c.requester_id = (select auth.uid()) and c.addressee_id = p.id)
         or (c.addressee_id = (select auth.uid()) and c.requester_id = p.id)
    )
  order by p.onboarded_at desc
  limit least(greatest(p_limit, 1), 50);
$$;

revoke all on function public.respond_to_connection(uuid, boolean)
  from public, anon;
revoke all on function public.respond_to_application(uuid, boolean)
  from public, anon;
revoke all on function public.discover_deck(integer) from public, anon;
grant execute on function public.respond_to_connection(uuid, boolean)
  to authenticated;
grant execute on function public.respond_to_application(uuid, boolean)
  to authenticated;
grant execute on function public.discover_deck(integer) to authenticated;
