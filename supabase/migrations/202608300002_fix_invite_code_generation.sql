-- Apply this after 202608300001 if it has already been run in Supabase.
-- It fixes invite generation in security-definer functions, whose public-only
-- search path cannot resolve pgcrypto functions installed in the extensions schema.
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
