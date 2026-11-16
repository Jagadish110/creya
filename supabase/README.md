# Creya backend (Supabase)

The database schema for Creya, as migration files. No Supabase project exists yet; these are ready to apply to a new one.

## Apply

With the Supabase CLI, from the repo root:

```bash
supabase link --project-ref <your project ref>
supabase db push
```

Or paste each file in `migrations/` into the SQL editor in the Supabase dashboard, in filename order.

## What's in it

1. `tables`: profiles, swipes, connections, collab posts and applications, chats, messages, read markers, blocks, reports.
2. `functions`: sign-up creates a profile; a right swipe sends a connection request (or accepts one already waiting); `respond_to_connection`, `respond_to_application` and `discover_deck` are what the app calls.
3. `access_rules`: row-level security. Signed-out visitors get nothing; signed-in users see and change only what is theirs, and a block hides both people from each other everywhere.
4. `storage`: private `avatars`, `clips` and `collab-media` buckets. Each user writes only inside a folder named after their user id.

## Not covered yet

- Deleting an account needs a server function (it must remove the auth user and their stored files).
- Clip length can't be checked by the database; only file size and type are limited.
