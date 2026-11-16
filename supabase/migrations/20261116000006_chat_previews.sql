-- Creya schema, part 6: keep each chat's latest message on the chat itself,
-- so the chat list can show a preview without loading any message history.

alter table public.chats
  add column last_message_body text,
  add column last_message_sender_id uuid
    references public.profiles (id) on delete set null;
create index chats_last_message_sender_idx
  on public.chats (last_message_sender_id);

create or replace function private.handle_new_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.chats
  set last_message_at = new.created_at,
      last_message_body = new.body,
      last_message_sender_id = new.sender_id
  where id = new.chat_id;
  return new;
end;
$$;

update public.chats c
set last_message_body = m.body,
    last_message_sender_id = m.sender_id
from (
  select distinct on (chat_id) chat_id, body, sender_id
  from public.messages
  order by chat_id, created_at desc
) m
where m.chat_id = c.id;
