-- Creya schema, part 3: who can read and write what.
-- Signed-out visitors get nothing. Signed-in users get exactly the grants
-- below, narrowed row by row by the policies. Blocking hides both people
-- from each other everywhere.

alter table public.profiles enable row level security;
alter table public.swipes enable row level security;
alter table public.connections enable row level security;
alter table public.collab_posts enable row level security;
alter table public.collab_applications enable row level security;
alter table public.chats enable row level security;
alter table public.messages enable row level security;
alter table public.chat_reads enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;

revoke all on all tables in schema public from anon, authenticated;

-- ---- profiles: created by the sign-up trigger, edited by their owner ------

grant select on public.profiles to authenticated;
grant update (name, city, creative, genres, bio, photo_path, clip_path,
              onboarded_at)
  on public.profiles to authenticated;

create policy "See own profile and onboarded, unblocked people"
  on public.profiles for select to authenticated
  using (
    id = (select auth.uid())
    or (
      onboarded_at is not null
      and not private.is_blocked_between((select auth.uid()), id)
    )
  );

create policy "Edit own profile"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- ---- swipes ---------------------------------------------------------------

grant select, insert, delete on public.swipes to authenticated;

create policy "See own swipes"
  on public.swipes for select to authenticated
  using (swiper_id = (select auth.uid()));

create policy "Swipe as yourself"
  on public.swipes for insert to authenticated
  with check (swiper_id = (select auth.uid()));

-- Lets "Refresh queue" bring skipped people back.
create policy "Undo own skips"
  on public.swipes for delete to authenticated
  using (swiper_id = (select auth.uid()) and direction = 'left');

-- ---- connections: read only; written by the swipe trigger and
--      respond_to_connection() -----------------------------------------------

grant select on public.connections to authenticated;

create policy "See own connections"
  on public.connections for select to authenticated
  using (
    (select auth.uid()) in (requester_id, addressee_id)
    and not private.is_blocked_between(requester_id, addressee_id)
  );

-- ---- collab_posts ---------------------------------------------------------

grant select, insert, delete on public.collab_posts to authenticated;
grant update (title, skill, description, media_type, media_path)
  on public.collab_posts to authenticated;

create policy "See posts from unblocked people"
  on public.collab_posts for select to authenticated
  using (
    owner_id = (select auth.uid())
    or not private.is_blocked_between((select auth.uid()), owner_id)
  );

create policy "Post as yourself"
  on public.collab_posts for insert to authenticated
  with check (owner_id = (select auth.uid()));

create policy "Edit own posts"
  on public.collab_posts for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "Delete own posts"
  on public.collab_posts for delete to authenticated
  using (owner_id = (select auth.uid()));

-- ---- collab_applications: answered through respond_to_application() ------

grant select, insert, delete on public.collab_applications to authenticated;

create policy "See own applications and applicants to own posts"
  on public.collab_applications for select to authenticated
  using (
    applicant_id = (select auth.uid())
    or exists (
      select 1 from public.collab_posts p
      where p.id = post_id
        and p.owner_id = (select auth.uid())
        and not private.is_blocked_between(p.owner_id, applicant_id)
    )
  );

-- The post lookup runs under the caller's own rules, so a post hidden by a
-- block cannot be applied to.
create policy "Apply to other people's posts"
  on public.collab_applications for insert to authenticated
  with check (
    applicant_id = (select auth.uid())
    and status = 'pending'
    and responded_at is null
    and exists (
      select 1 from public.collab_posts p
      where p.id = post_id and p.owner_id <> (select auth.uid())
    )
  );

create policy "Withdraw own pending applications"
  on public.collab_applications for delete to authenticated
  using (applicant_id = (select auth.uid()) and status = 'pending');

-- ---- chats: read only; created when a request is accepted ----------------

grant select on public.chats to authenticated;

create policy "See own chats"
  on public.chats for select to authenticated
  using (
    (select auth.uid()) in (user_a, user_b)
    and not private.is_blocked_between(user_a, user_b)
  );

-- ---- messages: the chat lookups rely on the chats policy above, so only
--      members of an unblocked chat can read or send ------------------------

grant select, insert on public.messages to authenticated;

create policy "Read messages in own chats"
  on public.messages for select to authenticated
  using (exists (select 1 from public.chats c where c.id = chat_id));

create policy "Send messages in own chats"
  on public.messages for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and exists (select 1 from public.chats c where c.id = chat_id)
  );

-- ---- chat_reads -----------------------------------------------------------

grant select, insert on public.chat_reads to authenticated;
grant update (last_read_at) on public.chat_reads to authenticated;

create policy "See own read markers"
  on public.chat_reads for select to authenticated
  using (user_id = (select auth.uid()));

create policy "Mark own chats read"
  on public.chat_reads for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.chats c where c.id = chat_id)
  );

create policy "Update own read markers"
  on public.chat_reads for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- ---- blocks ---------------------------------------------------------------

grant select, insert, delete on public.blocks to authenticated;

create policy "See own blocks"
  on public.blocks for select to authenticated
  using (blocker_id = (select auth.uid()));

create policy "Block as yourself"
  on public.blocks for insert to authenticated
  with check (blocker_id = (select auth.uid()));

create policy "Unblock"
  on public.blocks for delete to authenticated
  using (blocker_id = (select auth.uid()));

-- ---- reports: write only. The app must insert without asking for the row
--      back (no `.select()` after `.insert()`), since nobody can read them. --

grant insert on public.reports to authenticated;

create policy "Report as yourself"
  on public.reports for insert to authenticated
  with check (reporter_id = (select auth.uid()));

-- ---- Realtime: live delivery of new messages and chat-list changes --------

alter publication supabase_realtime add table public.messages, public.chats;
