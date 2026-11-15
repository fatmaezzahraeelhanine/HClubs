-- Signup role comes only from the server-side whitelist; no role selector is used.
create or replace function public.assign_profile_from_whitelist() returns trigger
language plpgsql security definer set search_path = public,pg_temp
as $$
declare w public.allowed_roles%rowtype; n text;
begin
  if lower(coalesce(new.email,'')) not like '%@hestim.ma' then
    raise exception 'Adresse institutionnelle @hestim.ma obligatoire';
  end if;
  select * into w from public.allowed_roles where email=lower(new.email);
  n := coalesce(nullif(trim(new.raw_user_meta_data->>'name'),''),split_part(new.email,'@',1));
  insert into public.profiles(id,name,email,role,bureau_role,club_id)
  values(new.id,n,lower(new.email),coalesce(w.role,'student'),coalesce(w.bureau_role,'Étudiant'),w.club_id)
  on conflict(id) do update set email=excluded.email;
  if w.role='admin' then
    return new;
  elsif w.role in ('bureau','member') then
    insert into public.club_memberships(club_id,user_id,membership_role,status)
    values(w.club_id,new.id,w.role,'active')
    on conflict(club_id,user_id) do update set membership_role=excluded.membership_role,status='active';
  end if;
  return new;
end $$;

-- Ensure the profile is created automatically for every new HESTIM Auth user.
-- Unlisted addresses become students; elevated roles still require allowed_roles.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.assign_profile_from_whitelist();

-- Create missing HESTIM profiles and synchronize existing profiles from the whitelist.
insert into public.profiles(id,name,email,role,bureau_role,club_id)
select u.id,
       coalesce(nullif(trim(u.raw_user_meta_data->>'name'),''),split_part(lower(u.email),'@',1)),
       lower(u.email),
       coalesce(w.role,'student'),
       coalesce(w.bureau_role,case when w.email is null then 'Étudiant' end),
       w.club_id
from auth.users u
left join public.allowed_roles w on w.email=lower(u.email)
where lower(coalesce(u.email,'')) like '%@hestim.ma'
on conflict(id) do update
set name=excluded.name,email=excluded.email,role=excluded.role,
    bureau_role=excluded.bureau_role,club_id=excluded.club_id;

insert into public.club_memberships(club_id,user_id,membership_role,status)
select p.club_id,p.id,p.role,'active'
from public.profiles p
where p.role in ('bureau','member') and p.club_id is not null
on conflict(club_id,user_id) do update
set membership_role=excluded.membership_role,status='active';
