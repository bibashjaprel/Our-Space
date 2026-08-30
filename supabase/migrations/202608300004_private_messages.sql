create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(trim(content)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists messages_space_created_at_idx on public.messages(space_id, created_at);
alter table public.messages enable row level security;
drop policy if exists "members can read messages in their space" on public.messages;
create policy "members can read messages in their space" on public.messages for select using (public.can_access_space(space_id));
drop policy if exists "members can send messages in their space" on public.messages;
create policy "members can send messages in their space" on public.messages for insert with check (sender_id = auth.uid() and public.can_access_space(space_id));
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages') then
    alter publication supabase_realtime add table public.messages;
  end if;
end; $$;
