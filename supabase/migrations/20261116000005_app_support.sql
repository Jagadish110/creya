-- Creya schema, part 5: additions the app needs to run against the backend.

-- A public count of accepted connections, shown on every profile. People can
-- only read their own rows in `connections`, so the count is kept here. It
-- is not in the columns users may update.
alter table public.profiles
  add column connection_count integer not null default 0
  check (connection_count >= 0);

create function private.handle_connection_accepted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
  set connection_count = connection_count + 1
  where id in (new.requester_id, new.addressee_id);
  return new;
end;
$$;

create trigger on_connection_accepted
  after update of status on public.connections
  for each row
  when (old.status <> 'accepted' and new.status = 'accepted')
  execute function private.handle_connection_accepted();

-- A count change is not a profile edit, so updated_at now only moves when
-- one of the profile's own fields is written.
drop trigger profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update of name, city, creative, genres, bio, photo_path, clip_path,
                   onboarded_at
  on public.profiles
  for each row execute function private.set_updated_at();

-- Marks a chat read as of now, using the server's clock.
create function public.mark_chat_read(p_chat_id uuid)
returns void
language sql
security invoker
set search_path = ''
as $$
  insert into public.chat_reads (chat_id, user_id, last_read_at)
  values (p_chat_id, (select auth.uid()), now())
  on conflict (chat_id, user_id) do update set last_read_at = now();
$$;

-- Deletes the caller's account. Everything they own goes with it, since
-- every table hangs off their profile. The app removes their stored files
-- first; storage does not allow deleting those from SQL.
create function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;
  delete from auth.users where id = (select auth.uid());
end;
$$;

revoke all on function public.mark_chat_read(uuid) from public, anon;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.mark_chat_read(uuid) to authenticated;
grant execute on function public.delete_my_account() to authenticated;
