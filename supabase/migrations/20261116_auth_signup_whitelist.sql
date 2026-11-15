-- Aligns signup requests with the server-side whitelist on existing projects.
-- The requested role is checked, never trusted as the source of privilege.
create or replace function public.assign_profile_from_whitelist() returns trigger
language plpgsql security definer set search_path = public,pg_temp
as $$
declare w public.allowed_roles%rowtype; n text; requested_role text;
begin
  if lower(coalesce(new.email,'')) not like '%@hestim.ma' then
    raise exception 'Adresse institutionnelle @hestim.ma obligatoire';
  end if;
  select * into w from public.allowed_roles where email=lower(new.email);
  requested_role := coalesce(new.raw_user_meta_data->>'requested_role','student');
  if requested_role not in ('student','bureau','member','admin') then
    raise exception 'Rôle demandé invalide';
  end if;
  if requested_role='student' then
    if found then raise exception 'Cette adresse est pré-autorisée avec le rôle %, sélectionnez ce rôle.',w.role; end if;
  elsif not found then
    raise exception 'Adresse absente de la whitelist HESTIM pour le rôle demandé';
  elsif w.role<>requested_role then
    raise exception 'Le rôle demandé ne correspond pas à la whitelist HESTIM';
  end if;
  n := coalesce(nullif(trim(new.raw_user_meta_data->>'name'),''),split_part(new.email,'@',1));
  insert into public.profiles(id,name,email,role,bureau_role,club_id)
  values(new.id,n,lower(new.email),coalesce(w.role,'student'),w.bureau_role,w.club_id)
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

-- Also promotes existing Auth profiles whose e-mail was whitelisted after signup.
update public.profiles p
set role=w.role,bureau_role=w.bureau_role,club_id=w.club_id
from public.allowed_roles w
where w.email=p.email
  and (p.role is distinct from w.role or p.bureau_role is distinct from w.bureau_role or p.club_id is distinct from w.club_id);

insert into public.club_memberships(club_id,user_id,membership_role,status)
select p.club_id,p.id,p.role,'active'
from public.profiles p
where p.role in ('bureau','member') and p.club_id is not null
on conflict(club_id,user_id) do update
set membership_role=excluded.membership_role,status='active';
