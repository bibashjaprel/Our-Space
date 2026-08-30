-- Apply after the previous migrations. `current_user` is a PostgreSQL keyword
-- (type name), not a safe PL/pgSQL variable name.
create or replace function public.create_couple_space(space_name text default 'Our Space')
returns public.spaces language plpgsql security definer set search_path = public as $$
declare created_space public.spaces; invite text; requesting_user_id uuid := auth.uid();
begin
  if requesting_user_id is null then raise exception 'You need to sign in first.'; end if;
  if exists(select 1 from public.space_members where user_id = requesting_user_id) then raise exception 'You already belong to a space.'; end if;
  loop
    invite := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));
    begin
      insert into public.spaces(name, created_by, invite_code)
      values (coalesce(nullif(trim(space_name), ''), 'Our Space'), requesting_user_id, invite)
      returning * into created_space;
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
