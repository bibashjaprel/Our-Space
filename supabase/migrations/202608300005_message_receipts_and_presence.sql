alter table public.messages add column if not exists delivered_at timestamptz;
alter table public.messages add column if not exists seen_at timestamptz;
alter table public.space_members add column if not exists last_seen_at timestamptz;

create or replace function public.mark_messages_delivered(target_space_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare requesting_user_id uuid := auth.uid();
begin
  if requesting_user_id is null or not public.can_access_space(target_space_id) then raise exception 'Not allowed.'; end if;
  update public.messages set delivered_at = now()
  where space_id = target_space_id and sender_id <> requesting_user_id and delivered_at is null;
end;
$$;

create or replace function public.mark_messages_seen(target_space_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare requesting_user_id uuid := auth.uid();
begin
  if requesting_user_id is null or not public.can_access_space(target_space_id) then raise exception 'Not allowed.'; end if;
  update public.messages set delivered_at = coalesce(delivered_at, now()), seen_at = coalesce(seen_at, now())
  where space_id = target_space_id and sender_id <> requesting_user_id and seen_at is null;
  update public.space_members set last_seen_at = now()
  where space_id = target_space_id and user_id = requesting_user_id;
end;
$$;

revoke all on function public.mark_messages_delivered(uuid) from public;
revoke all on function public.mark_messages_seen(uuid) from public;
grant execute on function public.mark_messages_delivered(uuid) to authenticated;
grant execute on function public.mark_messages_seen(uuid) to authenticated;

do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'space_members') then
    alter publication supabase_realtime add table public.space_members;
  end if;
end; $$;
