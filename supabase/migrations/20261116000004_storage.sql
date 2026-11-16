-- Creya schema, part 4: file storage.
-- All three buckets are private. Any signed-in user can view files; each
-- user can only write inside a folder named after their own user id, e.g.
-- `avatars/<user id>/photo.jpg`.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', false, 5 * 1024 * 1024,
   array['image/jpeg', 'image/png', 'image/webp', 'image/heic']),
  ('clips', 'clips', false, 50 * 1024 * 1024,
   array['video/mp4', 'video/quicktime']),
  ('collab-media', 'collab-media', false, 50 * 1024 * 1024,
   array['video/mp4', 'video/quicktime', 'audio/mpeg', 'audio/mp4',
         'audio/aac', 'audio/wav', 'audio/x-wav'])
on conflict (id) do nothing;

create policy "Signed-in users can view Creya files"
  on storage.objects for select to authenticated
  using (bucket_id in ('avatars', 'clips', 'collab-media'));

create policy "Upload into own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id in ('avatars', 'clips', 'collab-media')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Replace files in own folder"
  on storage.objects for update to authenticated
  using (
    bucket_id in ('avatars', 'clips', 'collab-media')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id in ('avatars', 'clips', 'collab-media')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Delete files in own folder"
  on storage.objects for delete to authenticated
  using (
    bucket_id in ('avatars', 'clips', 'collab-media')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
