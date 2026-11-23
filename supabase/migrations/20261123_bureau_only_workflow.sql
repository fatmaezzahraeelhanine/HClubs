-- HClubs : seuls les membres du bureau gèrent les tâches et proposent les événements.
-- L'administration est la seule à accepter ou refuser un événement.

create or replace function public.can_manage_club(target_club text) returns boolean
language sql stable security definer set search_path = public,pg_temp
as $$ select public.is_admin() or exists (
  select 1
  from public.club_memberships m
  join public.profiles p on p.id=m.user_id
  join public.allowed_roles w
    on w.email=p.email and w.club_id=m.club_id and w.role='bureau'
  where m.user_id=auth.uid()
    and m.club_id=target_club
    and m.status='active'
    and m.membership_role='bureau'
    and p.role='bureau'
    and p.club_id=target_club
) $$;
revoke all on function public.can_manage_club(text) from public;
grant execute on function public.can_manage_club(text) to authenticated;

create or replace function public.assign_profile_from_whitelist() returns trigger
language plpgsql security definer set search_path = public,pg_temp
as $$
declare
  w public.allowed_roles%rowtype;
  n text;
  requested_role text;
begin
  if lower(coalesce(new.email,'')) not like '%@hestim.ma' then
    raise exception 'Adresse institutionnelle @hestim.ma obligatoire';
  end if;

  select * into w from public.allowed_roles where email=lower(new.email);
  requested_role := coalesce(new.raw_user_meta_data->>'requested_role','student');
  if requested_role not in ('student','bureau','admin') then
    raise exception 'Type de compte invalide';
  end if;
  if requested_role <> 'student' and (not found or w.role <> requested_role) then
    raise exception 'Cette adresse n’est pas préautorisée pour ce rôle';
  end if;

  n := coalesce(nullif(trim(new.raw_user_meta_data->>'name'),''),split_part(lower(new.email),'@',1));
  insert into public.profiles(id,name,email,role,bureau_role,club_id)
  values(new.id,n,lower(new.email),case when requested_role='student' then 'student' else w.role end,case when requested_role='student' then 'Étudiant' else w.bureau_role end,case when requested_role='student' then null else w.club_id end)
  on conflict(id) do update
  set name=excluded.name,email=excluded.email,role=excluded.role,
      bureau_role=excluded.bureau_role,club_id=excluded.club_id;

  if requested_role='bureau' and w.role='bureau' and w.club_id is not null then
    insert into public.club_memberships(club_id,user_id,membership_role,status)
    values(w.club_id,new.id,'bureau','active')
    on conflict(club_id,user_id) do update
    set membership_role='bureau',status='active';
  end if;
  return new;
end $$;
revoke all on function public.assign_profile_from_whitelist() from public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.assign_profile_from_whitelist();

drop policy if exists events_review on public.events;
create policy events_review on public.events for update to authenticated
using (public.is_admin())
with check (public.is_admin());
