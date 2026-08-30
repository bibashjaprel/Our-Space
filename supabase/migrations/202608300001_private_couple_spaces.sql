-- Private two-person spaces. Apply through the Supabase SQL editor or CLI.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 80),
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.spaces (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Our Space' check (char_length(trim(name)) between 1 and 80),
  created_by uuid not null references auth.users(id) on delete restrict,
  invite_code text not null unique check (invite_code ~ '^[A-Z0-9]{12}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.space_members (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (space_id, user_id),
  unique (user_id)
);

create index if not exists space_members_space_id_idx on public.space_members(space_id);

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
drop trigger if exists spaces_updated_at on public.spaces;
create trigger spaces_updated_at before update on public.spaces for each row execute function public.set_updated_at();

-- Runs once on sign-up; metadata is optional so the onboarding can still ask for a name.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), 'You'))
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- These narrowly scoped helpers avoid recursive RLS policies while never accepting a user id from the browser.
create or replace function public.can_access_space(target_space_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.space_members where space_id = target_space_id and user_id = auth.uid());
$$;

create or replace function public.shares_space_with(target_user_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(
    select 1 from public.space_members mine
    join public.space_members theirs on theirs.space_id = mine.space_id
    where mine.user_id = auth.uid() and theirs.user_id = target_user_id
  );
$$;

alter table public.profiles enable row level security;
alter table public.spaces enable row level security;
alter table public.space_members enable row level security;

drop policy if exists "profiles are private to a couple" on public.profiles;
create policy "profiles are private to a couple" on public.profiles for select using (id = auth.uid() or public.shares_space_with(id));
drop policy if exists "users create their own profile" on public.profiles;
create policy "users create their own profile" on public.profiles for insert with check (id = auth.uid());
drop policy if exists "users update their own profile" on public.profiles;
create policy "users update their own profile" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "members can read their space" on public.spaces;
create policy "members can read their space" on public.spaces for select using (public.can_access_space(id));
-- No direct client updates to spaces are needed in this milestone. Keeping this
-- table read-only avoids allowing a member to alter ownership or invite codes.
drop policy if exists "members can rename their space" on public.spaces;

drop policy if exists "members can read members in their space" on public.space_members;
create policy "members can read members in their space" on public.space_members for select using (public.can_access_space(space_id));

-- Membership can only be created by these atomic server-side database functions.
create or replace function public.create_couple_space(space_name text default 'Our Space')
returns public.spaces language plpgsql security definer set search_path = public as $$
declare created_space public.spaces; invite text; requesting_user_id uuid := auth.uid();
begin
  if requesting_user_id is null then raise exception 'You need to sign in first.'; end if;
  if exists(select 1 from public.space_members where user_id = requesting_user_id) then raise exception 'You already belong to a space.'; end if;
  loop
    -- gen_random_uuid() is cryptographically random in supported Postgres
    -- versions and is already used for the primary keys above. Keeping it in
    -- the public search path avoids a Supabase extension-schema dependency.
    invite := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));
    begin
      insert into public.spaces(name, created_by, invite_code) values (coalesce(nullif(trim(space_name), ''), 'Our Space'), requesting_user_id, invite) returning * into created_space;
      exit;
    exception when unique_violation then null;
    end;
  end loop;
  insert into public.space_members(space_id, user_id) values (created_space.id, requesting_user_id);
  return created_space;
end;
$$;

create or replace function public.join_couple_space(code text)
returns public.spaces language plpgsql security definer set search_path = public as $$
declare target_space public.spaces; requesting_user_id uuid := auth.uid(); member_count integer;
begin
  if requesting_user_id is null then raise exception 'You need to sign in first.'; end if;
  if exists(select 1 from public.space_members where user_id = requesting_user_id) then raise exception 'You already belong to a space.'; end if;
  select * into target_space from public.spaces where invite_code = upper(trim(code));
  if not found then raise exception 'That invitation code is not available.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(target_space.id::text, 0));
  select count(*) into member_count from public.space_members where space_id = target_space.id;
  if member_count >= 2 then raise exception 'This space is already full.'; end if;
  insert into public.space_members(space_id, user_id) values (target_space.id, requesting_user_id);
  return target_space;
end;
$$;

revoke all on function public.create_couple_space(text) from public;
revoke all on function public.join_couple_space(text) from public;
grant execute on function public.create_couple_space(text) to authenticated;
grant execute on function public.join_couple_space(text) to authenticated;
