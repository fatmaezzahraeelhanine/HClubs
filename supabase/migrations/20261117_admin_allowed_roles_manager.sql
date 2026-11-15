-- Admin-managed whitelist. Students remain self-service; only existing admins
-- can grant or revoke club/admin roles from the application.

create or replace function public.prevent_removing_last_admin_role()
returns trigger
language plpgsql security definer set search_path = public,pg_temp
as $$
begin
  if old.role = 'admin' and (tg_op = 'DELETE' or new.role is distinct from 'admin') then
    if not exists (
      select 1 from public.allowed_roles r
      where r.role = 'admin' and r.email <> old.email
    ) then
      raise exception 'Au moins une adresse administrateur doit rester autorisée.';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists allowed_roles_keep_admin on public.allowed_roles;
create trigger allowed_roles_keep_admin
before update of role or delete on public.allowed_roles
for each row execute function public.prevent_removing_last_admin_role();

create or replace function public.sync_profile_from_allowed_role()
returns trigger
language plpgsql security definer set search_path = public,pg_temp
as $$
declare target_user uuid;
begin
  if tg_op = 'DELETE' then
    select id into target_user from public.profiles where email = old.email;
    if target_user is not null then
      update public.club_memberships
      set membership_role = 'student', status = 'active'
      where user_id = target_user and club_id = old.club_id
        and membership_role in ('bureau','member');
      update public.profiles
      set role = 'student', bureau_role = 'Étudiant', club_id = null
      where id = target_user;
    end if;
    return old;
  end if;

  select id into target_user from public.profiles where email = new.email;
  if target_user is null then return new; end if;

  if tg_op = 'UPDATE' and old.role in ('bureau','member')
     and (new.role not in ('bureau','member') or new.club_id is distinct from old.club_id) then
    update public.club_memberships
    set membership_role = 'student', status = 'active'
    where user_id = target_user and club_id = old.club_id
      and membership_role in ('bureau','member');
  end if;

  update public.profiles
  set role = new.role, bureau_role = new.bureau_role, club_id = new.club_id
  where id = target_user;

  if new.role in ('bureau','member') and new.club_id is not null then
    insert into public.club_memberships(club_id,user_id,membership_role,status)
    values(new.club_id,target_user,new.role,'active')
    on conflict(club_id,user_id) do update
      set membership_role = excluded.membership_role, status = 'active';
  end if;
  return new;
end;
$$;

drop trigger if exists allowed_roles_sync_profile on public.allowed_roles;
create trigger allowed_roles_sync_profile
after insert or update or delete on public.allowed_roles
for each row execute function public.sync_profile_from_allowed_role();

drop policy if exists allowed_roles_admin_manage on public.allowed_roles;
create policy allowed_roles_admin_manage on public.allowed_roles
for all to authenticated
using (public.is_admin()) with check (public.is_admin());

-- Reconcile existing accounts without granting roles to unlisted addresses.
update public.profiles p
set role = 'student', bureau_role = 'Étudiant', club_id = null
where p.role in ('bureau','member','admin')
  and not exists (select 1 from public.allowed_roles r where r.email = p.email);

update public.profiles p
set role = r.role, bureau_role = r.bureau_role, club_id = r.club_id
from public.allowed_roles r
where r.email = p.email;

insert into public.club_memberships(club_id,user_id,membership_role,status)
select p.club_id,p.id,p.role,'active'
from public.profiles p
where p.role in ('bureau','member') and p.club_id is not null
on conflict(club_id,user_id) do update
set membership_role = excluded.membership_role, status = 'active';

