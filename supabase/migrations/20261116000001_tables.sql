-- Creya schema, part 1: types, tables and indexes.
-- Access rules live in the next migration; nothing here is reachable by the
-- app until that one grants it.

create type public.swipe_direction as enum ('left', 'right');
create type public.request_status as enum ('pending', 'accepted', 'declined');
create type public.collab_media as enum ('audio', 'clip');

-- One row per signed-in user, created automatically on sign-up.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null default '' check (char_length(name) <= 80),
  city text not null default '' check (char_length(city) <= 80),
  creative text not null default '' check (char_length(creative) <= 60),
  genres text[] not null default '{}' check (cardinality(genres) <= 12),
  bio text not null default '' check (char_length(bio) <= 500),
  -- Paths inside the `avatars` and `clips` storage buckets.
  photo_path text,
  clip_path text,
  -- Set when onboarding finishes. Other people only see onboarded profiles.
  onboarded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint onboarding_needs_photo_and_clip check (
    onboarded_at is null
    or (photo_path is not null and clip_path is not null and name <> '')
  )
);

-- Every card a user has swiped on Discover.
create table public.swipes (
  swiper_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  target_id uuid not null references public.profiles (id) on delete cascade,
  direction public.swipe_direction not null,
  created_at timestamptz not null default now(),
  primary key (swiper_id, target_id),
  check (swiper_id <> target_id)
);
create index swipes_target_idx on public.swipes (target_id);

-- A connection request and its outcome. Rows are created by a right swipe
-- and answered through respond_to_connection(); the app never writes here.
create table public.connections (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles (id) on delete cascade,
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status public.request_status not null default 'pending',
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (requester_id <> addressee_id)
);
-- At most one connection per pair of people, whichever way it was requested.
create unique index connections_pair_idx on public.connections (
  least(requester_id, addressee_id),
  greatest(requester_id, addressee_id)
);
create index connections_requester_idx on public.connections (requester_id);
create index connections_addressee_idx
  on public.connections (addressee_id, status);

create table public.collab_posts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  skill text not null check (char_length(skill) between 1 and 60),
  description text not null default '' check (char_length(description) <= 1000),
  media_type public.collab_media,
  -- Path inside the `collab-media` storage bucket.
  media_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((media_type is null) = (media_path is null))
);
create index collab_posts_owner_idx on public.collab_posts (owner_id);
create index collab_posts_created_idx on public.collab_posts (created_at desc);

-- Someone applying to a collab post. Linked by post id, so renaming a post
-- keeps its applicants. Answered through respond_to_application().
create table public.collab_applications (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.collab_posts (id) on delete cascade,
  applicant_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  status public.request_status not null default 'pending',
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (post_id, applicant_id)
);
create index collab_applications_applicant_idx
  on public.collab_applications (applicant_id);

-- A conversation between two people. user_a is always the smaller id, so a
-- pair can only ever have one chat. Created when a request is accepted.
create table public.chats (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles (id) on delete cascade,
  user_b uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now(),
  unique (user_a, user_b),
  check (user_a < user_b)
);
create index chats_user_b_idx on public.chats (user_b);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats (id) on delete cascade,
  sender_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index messages_chat_idx on public.messages (chat_id, created_at);
create index messages_sender_idx on public.messages (sender_id);

-- When each person last opened a chat. A chat is unread for a user when
-- chats.last_message_at is later than their last_read_at here.
create table public.chat_reads (
  chat_id uuid not null references public.chats (id) on delete cascade,
  user_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (chat_id, user_id)
);
create index chat_reads_user_idx on public.chat_reads (user_id);

create table public.blocks (
  blocker_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index blocks_blocked_idx on public.blocks (blocked_id);

-- Reports of a person, optionally pointing at a post or message. The app can
-- only add reports; they are reviewed from the Supabase dashboard.
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  reported_user_id uuid not null
    references public.profiles (id) on delete cascade,
  post_id uuid references public.collab_posts (id) on delete set null,
  message_id uuid references public.messages (id) on delete set null,
  reason text not null check (char_length(reason) between 1 and 60),
  details text not null default '' check (char_length(details) <= 1000),
  created_at timestamptz not null default now(),
  check (reporter_id <> reported_user_id)
);
create index reports_reporter_idx on public.reports (reporter_id);
create index reports_reported_user_idx on public.reports (reported_user_id);
create index reports_post_idx on public.reports (post_id);
create index reports_message_idx on public.reports (message_id);
