-- HClubs / HESTIM — schéma canonique Supabase (PostgreSQL)
-- À exécuter une fois dans Supabase > SQL Editor (création vierge ou mise à niveau HClubs).
-- Le rôle ne vient jamais des métadonnées client : il est dérivé de la whitelist.
begin;

create extension if not exists pgcrypto;

create table if not exists public.clubs (
  id text primary key,
  name text not null,
  category text not null default 'Association',
  description text not null default '',
  color text not null default 'blue',
  icon text not null default 'Users',
  meeting_place text not null default '',
  contact_email text,
  status text not null default 'approved' check (status in ('pending','approved','rejected','archived')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.allowed_roles (
  email text primary key check (email = lower(email) and email like '%@hestim.ma'),
  role text not null check (role in ('bureau','member','admin')),
  bureau_role text,
  club_id text references public.clubs(id) on delete cascade,
  created_at timestamptz not null default now(),
  check ((role = 'admin' and club_id is null) or (role <> 'admin' and club_id is not null))
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  email text not null unique check (email = lower(email) and email like '%@hestim.ma'),
  role text not null default 'student' check (role in ('student','bureau','member','admin')),
  bureau_role text,
  club_id text references public.clubs(id) on delete set null,
  created_at timestamptz not null default now(),
  check ((role in ('bureau','member') and club_id is not null) or role in ('student','admin'))
);

create table if not exists public.club_memberships (
  club_id text not null references public.clubs(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  membership_role text not null default 'student' check (membership_role in ('student','bureau','member')),
  status text not null default 'active' check (status in ('pending','active','rejected')),
  joined_at timestamptz not null default now(),
  primary key (club_id,user_id)
);

create table if not exists public.club_requests (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  description text not null,
  proposed_by uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  club_id text not null references public.clubs(id) on delete cascade,
  title text not null,
  description text not null default '',
  event_date timestamptz not null,
  location text not null default 'Campus HESTIM',
  category text not null default 'Campus',
  max_places integer not null default 30 check (max_places > 0),
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  created_by uuid references public.profiles(id) on delete set null,
  reviewed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.event_registrations (
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  registered_at timestamptz not null default now(),
  primary key (event_id,user_id)
);

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  capacity integer check (capacity is null or capacity > 0),
  location text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.equipment (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  quantity integer not null default 1 check (quantity > 0),
  is_active boolean not null default true
);

create table if not exists public.room_reservations (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references public.rooms(id) on delete restrict,
  equipment_id uuid references public.equipment(id) on delete restrict,
  club_id text not null references public.clubs(id) on delete cascade,
  requested_by uuid not null references public.profiles(id) on delete cascade,
  start_time timestamptz not null,
  end_time timestamptz not null,
  purpose text not null,
  attendees integer not null default 1 check (attendees > 0),
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  check (end_time > start_time),
  check ((case when room_id is null then 0 else 1 end) + (case when equipment_id is null then 0 else 1 end) = 1)
);

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  club_id text not null references public.clubs(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique (club_id,name)
);

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  club_id text not null references public.clubs(id) on delete cascade,
  title text not null,
  status text not null default 'todo' check (status in ('todo','doing','done')),
  priority text not null default 'medium' check (priority in ('low','medium','high')),
  due_date date,
  assignee text not null default '',
  assignee_id uuid references public.profiles(id) on delete set null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  check (status <> 'done' or created_at is not null)
);

create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),
  club_id text references public.clubs(id) on delete cascade,
  amount numeric(12,2) not null check (amount >= 0),
  year integer not null check (year between 2020 and 2100),
  label text not null default 'Budget annuel',
  created_at timestamptz not null default now(),
  unique (club_id,year,label)
);

create table if not exists public.budget_expenses (
  id uuid primary key default gen_random_uuid(),
  club_id text references public.clubs(id) on delete cascade,
  amount numeric(12,2) not null check (amount > 0),
  year integer not null check (year between 2020 and 2100),
  description text not null,
  spent_on date not null default current_date,
  submitted_by uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'approved' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);

alter table public.club_memberships add column if not exists membership_role text not null default 'student';
alter table public.club_memberships add column if not exists status text not null default 'active';
alter table public.club_memberships add column if not exists joined_at timestamptz not null default now();
alter table public.club_memberships drop constraint if exists club_memberships_membership_role_check;
alter table public.club_memberships add constraint club_memberships_membership_role_check check (membership_role in ('student','bureau','member'));
alter table public.club_memberships drop constraint if exists club_memberships_status_check;
alter table public.club_memberships add constraint club_memberships_status_check check (status in ('pending','active','rejected'));

-- Mise à niveau de la première version du schéma si ces tables existent déjà.
alter table public.clubs add column if not exists category text not null default 'Association';
alter table public.clubs add column if not exists description text not null default '';
alter table public.clubs add column if not exists color text not null default 'blue';
alter table public.clubs add column if not exists icon text not null default 'Users';
alter table public.clubs add column if not exists meeting_place text not null default '';
alter table public.clubs add column if not exists contact_email text;
alter table public.clubs add column if not exists status text not null default 'approved';
alter table public.clubs add column if not exists created_by uuid references auth.users(id) on delete set null;
alter table public.clubs add column if not exists created_at timestamptz not null default now();
alter table public.profiles add column if not exists bureau_role text;
alter table public.profiles add column if not exists club_id text references public.clubs(id) on delete set null;
alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.events add column if not exists description text not null default '';
alter table public.events add column if not exists location text not null default 'Campus HESTIM';
alter table public.events add column if not exists category text not null default 'Campus';
alter table public.events add column if not exists max_places integer not null default 30;
alter table public.events add column if not exists status text not null default 'approved';
alter table public.events add column if not exists created_by uuid references public.profiles(id) on delete set null;
alter table public.events add column if not exists reviewed_by uuid references public.profiles(id) on delete set null;
alter table public.events add column if not exists created_at timestamptz not null default now();
alter table public.rooms add column if not exists location text not null default '';
alter table public.rooms add column if not exists is_active boolean not null default true;
alter table public.rooms add column if not exists created_at timestamptz not null default now();
alter table public.room_reservations alter column room_id drop not null;
alter table public.room_reservations add column if not exists equipment_id uuid references public.equipment(id) on delete restrict;
alter table public.room_reservations add column if not exists purpose text not null default 'Réservation de salle';
alter table public.room_reservations add column if not exists attendees integer not null default 1;
alter table public.room_reservations add column if not exists reviewed_by uuid references public.profiles(id) on delete set null;
alter table public.room_reservations add column if not exists reviewed_at timestamptz;
alter table public.room_reservations add column if not exists created_at timestamptz not null default now();
alter table public.tasks add column if not exists priority text not null default 'medium';
alter table public.tasks add column if not exists due_date date;
alter table public.tasks add column if not exists assignee text not null default '';
alter table public.tasks add column if not exists assignee_id uuid references public.profiles(id) on delete set null;
alter table public.tasks add column if not exists created_by uuid references public.profiles(id) on delete set null;
alter table public.tasks add column if not exists created_at timestamptz not null default now();
alter table public.budgets add column if not exists label text not null default 'Budget annuel';
alter table public.budgets add column if not exists created_at timestamptz not null default now();
alter table public.budgets alter column amount type numeric(12,2) using amount::numeric(12,2);
alter table public.room_reservations drop constraint if exists room_reservations_resource_check;
alter table public.room_reservations add constraint room_reservations_resource_check
  check ((case when room_id is null then 0 else 1 end) + (case when equipment_id is null then 0 else 1 end) = 1);
alter table public.room_reservations drop constraint if exists room_reservations_time_check;
alter table public.room_reservations add constraint room_reservations_time_check check (end_time > start_time);
alter table public.events drop constraint if exists events_max_places_check;
alter table public.events add constraint events_max_places_check check (max_places > 0);
alter table public.events drop constraint if exists events_status_check;
alter table public.events add constraint events_status_check check (status in ('pending','approved','rejected','cancelled'));
alter table public.clubs drop constraint if exists clubs_status_check;
alter table public.clubs add constraint clubs_status_check check (status in ('pending','approved','rejected','archived'));

create index if not exists events_date_status_idx on public.events(event_date,status);
create index if not exists registrations_user_idx on public.event_registrations(user_id);
create index if not exists memberships_user_idx on public.club_memberships(user_id,status);
create index if not exists reservations_schedule_idx on public.room_reservations(start_time,end_time,status);
create index if not exists tasks_club_status_idx on public.tasks(club_id,status);
create index if not exists budgets_year_idx on public.budgets(year);
create unique index if not exists budgets_club_year_label_uidx on public.budgets(club_id,year,label);
create unique index if not exists rooms_name_uidx on public.rooms(name);

-- Fonctions de vérification RBAC, accessibles uniquement dans le contexte de l'utilisateur.
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public,pg_temp
as $$ select exists(select 1 from public.profiles p join public.allowed_roles w on w.email=p.email and w.role='admin' where p.id=auth.uid() and p.role='admin') $$;

create or replace function public.can_manage_club(target_club text) returns boolean
language sql stable security definer set search_path = public,pg_temp
as $$ select public.is_admin() or exists (
  select 1 from public.club_memberships m
  join public.profiles p on p.id=m.user_id
  join public.allowed_roles w on w.email=p.email and w.club_id=m.club_id and w.role=m.membership_role and p.role=w.role and p.club_id=w.club_id
  where m.user_id=auth.uid() and m.club_id=target_club and m.status='active' and m.membership_role in ('bureau','member')
) $$;
revoke all on function public.is_admin() from public;
revoke all on function public.can_manage_club(text) from public;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.can_manage_club(text) to authenticated;

create or replace function public.is_club_member(target_club text) returns boolean
language sql stable security definer set search_path = public,pg_temp
as $$ select public.is_admin() or exists (
  select 1 from public.club_memberships m where m.user_id=auth.uid() and m.club_id=target_club and m.status='active'
) $$;
revoke all on function public.is_club_member(text) from public;
grant execute on function public.is_club_member(text) to authenticated;

create or replace function public.assign_profile_from_whitelist() returns trigger
language plpgsql security definer set search_path = public,pg_temp
as $$
declare w public.allowed_roles%rowtype; n text; requested_role text;
begin
  if lower(coalesce(new.email,'')) not like '%@hestim.ma' then raise exception 'Adresse institutionnelle @hestim.ma obligatoire'; end if;
  select * into w from public.allowed_roles where email=lower(new.email);
  requested_role := coalesce(new.raw_user_meta_data->>'requested_role','student');
  if requested_role not in ('student','bureau','member','admin') then raise exception 'Rôle demandé invalide'; end if;
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
    values(w.club_id,new.id,w.role,'active') on conflict(club_id,user_id) do update set membership_role=excluded.membership_role,status='active';
  end if;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.assign_profile_from_whitelist();

create or replace function public.protect_profile_role() returns trigger
language plpgsql security definer set search_path = public,pg_temp
as $$
declare w public.allowed_roles%rowtype;
begin
  if auth.uid() is not null and not public.is_admin() then
    if new.role is distinct from old.role or new.club_id is distinct from old.club_id or new.email is distinct from old.email then
      raise exception 'Les rôles et clubs sont gérés par la whitelist administrative';
    end if;
  end if;
  select * into w from public.allowed_roles where email=lower(new.email);
  if not found then new.role:='student'; new.club_id:=null; new.bureau_role:='Étudiant';
  elsif found then new.role:=w.role; new.club_id:=w.club_id; new.bureau_role:=w.bureau_role;
  end if;
  return new;
end $$;
drop trigger if exists profiles_role_guard on public.profiles;
create trigger profiles_role_guard before update on public.profiles for each row execute function public.protect_profile_role();

create or replace function public.validate_membership_role() returns trigger
language plpgsql security definer set search_path = public,pg_temp
as $$
begin
  if new.membership_role in ('bureau','member') and not exists(
    select 1 from public.profiles p join public.allowed_roles w on w.email=p.email
    where p.id=new.user_id and w.club_id=new.club_id and w.role=new.membership_role and p.role=w.role and p.club_id=w.club_id
  ) then raise exception 'Ce rôle de club doit être autorisé dans la whitelist'; end if;
  return new;
end $$;
drop trigger if exists membership_role_guard on public.club_memberships;
create trigger membership_role_guard before insert or update of membership_role,club_id,user_id on public.club_memberships
for each row execute function public.validate_membership_role();

-- Inscription atomique : capacité vérifiée côté serveur, doublons bloqués par la clé primaire.
create or replace function public.register_for_event(requested_event_id uuid) returns void
language plpgsql security definer set search_path = public,pg_temp
as $$
declare e public.events%rowtype; seats integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into e from public.events where id=requested_event_id and status='approved' for update;
  if not found then raise exception 'Événement indisponible'; end if;
  select count(*) into seats from public.event_registrations where event_id=e.id;
  if seats >= e.max_places then raise exception 'Événement complet'; end if;
  insert into public.event_registrations(event_id,user_id) values(e.id,auth.uid());
end $$;
revoke all on function public.register_for_event(uuid) from public;
grant execute on function public.register_for_event(uuid) to authenticated;

create or replace function public.create_club_from_request() returns trigger
language plpgsql security definer set search_path = public,pg_temp
as $$
declare slug text;
begin
  if new.status='approved' and (tg_op='INSERT' or old.status is distinct from 'approved') then
    slug := trim(both '-' from regexp_replace(lower(new.name),'[^a-z0-9]+','-','g'));
    insert into public.clubs(id,name,category,description,status,created_by)
    values(slug||'-'||substr(new.id::text,1,8),new.name,new.category,new.description,'approved',new.proposed_by);
    insert into public.club_memberships(club_id,user_id,membership_role,status)
    select id,new.proposed_by,'student','active' from public.clubs where created_by=new.proposed_by and name=new.name order by created_at desc limit 1
    on conflict(club_id,user_id) do nothing;
  end if;
  return new;
end $$;
drop trigger if exists club_request_approved on public.club_requests;
create trigger club_request_approved after insert or update of status on public.club_requests
for each row execute function public.create_club_from_request();

-- Les réservations approuvées ne peuvent pas se chevaucher sur une même ressource.
create or replace function public.prevent_resource_overlap() returns trigger
language plpgsql set search_path = public,pg_temp
as $$
begin
  if new.room_id is not null and not exists(
    select 1 from public.rooms r where r.id=new.room_id and r.is_active and (r.capacity is null or new.attendees<=r.capacity)
  ) then raise exception 'Salle inactive ou capacité dépassée'; end if;
  if new.equipment_id is not null and not exists(select 1 from public.equipment e where e.id=new.equipment_id and e.is_active) then
    raise exception 'Matériel indisponible';
  end if;
  if new.status='approved' and exists (
    select 1 from public.room_reservations r where r.id<>new.id and r.status='approved'
      and (r.room_id=new.room_id or r.equipment_id=new.equipment_id)
      and tstzrange(r.start_time,r.end_time,'[)') && tstzrange(new.start_time,new.end_time,'[)')
  ) then raise exception 'Cette ressource est déjà réservée sur ce créneau'; end if;
  return new;
end $$;
drop trigger if exists reservation_no_overlap on public.room_reservations;
create trigger reservation_no_overlap before insert or update of status,start_time,end_time,room_id,equipment_id on public.room_reservations
for each row execute function public.prevent_resource_overlap();

create or replace function public.validate_task_assignment() returns trigger
language plpgsql set search_path = public,pg_temp
as $$
begin
  if tg_op='INSERT' and new.status='done' then raise exception 'Une tâche doit être créée au statut à faire ou en cours'; end if;
  if not exists(select 1 from public.projects p where p.id=new.project_id and p.club_id=new.club_id) then
    raise exception 'Le projet sélectionné ne correspond pas au club de la tâche';
  end if;
  if new.assignee_id is not null and not exists(
    select 1 from public.club_memberships m where m.user_id=new.assignee_id and m.club_id=new.club_id and m.status='active'
  ) then raise exception 'Le responsable doit être un membre actif du club'; end if;
  return new;
end $$;
drop trigger if exists tasks_validate_assignment on public.tasks;
create trigger tasks_validate_assignment before insert or update on public.tasks
for each row execute function public.validate_task_assignment();

-- RLS activé partout : absence de policy = aucun accès client.
do $$ declare t text; begin
  foreach t in array array['clubs','allowed_roles','profiles','club_memberships','club_requests','events','event_registrations','rooms','equipment','room_reservations','projects','tasks','budgets','budget_expenses'] loop
    execute format('alter table public.%I enable row level security',t);
  end loop;
end $$;

-- Supprime aussi toutes les anciennes policies ouvertes, y compris celles ajoutées par l'ancienne migration.
drop policy if exists "lire clubs" on public.clubs;
drop policy if exists "admin clubs" on public.clubs;
drop policy if exists "voir son profil ou admin" on public.profiles;
drop policy if exists "admin modifie profils" on public.profiles;
drop policy if exists "hclubs_read_own_club_profiles" on public.profiles;
drop policy if exists "lire events" on public.events;
drop policy if exists "gerer events" on public.events;
drop policy if exists "hclubs_read_visible_events" on public.events;
drop policy if exists "hclubs_bureau_create_events" on public.events;
drop policy if exists "hclubs_admin_update_events" on public.events;
drop policy if exists "lire salles" on public.rooms;
drop policy if exists "admin salles" on public.rooms;
drop policy if exists "voir reservations" on public.room_reservations;
drop policy if exists "creer reservation" on public.room_reservations;
drop policy if exists "admin approuve" on public.room_reservations;
drop policy if exists "hclubs_read_reservations" on public.room_reservations;
drop policy if exists "hclubs_create_reservations" on public.room_reservations;
drop policy if exists "hclubs_admin_approve_reservations" on public.room_reservations;
drop policy if exists "projets du club" on public.projects;
drop policy if exists "hclubs_projects_by_club" on public.projects;
drop policy if exists "taches du club" on public.tasks;
drop policy if exists "hclubs_tasks_by_club" on public.tasks;
drop policy if exists "voir budgets" on public.budgets;
drop policy if exists "admin budgets" on public.budgets;
drop policy if exists "hclubs_read_budgets" on public.budgets;
drop policy if exists "hclubs_read_event_registrations" on public.event_registrations;
drop policy if exists "hclubs_register_self" on public.event_registrations;
drop policy if exists "hclubs_read_memberships" on public.club_memberships;
drop policy if exists "hclubs_join_self" on public.club_memberships;
drop policy if exists "hclubs_admin_memberships" on public.club_memberships;

drop policy if exists allowed_roles_admin_manage on public.allowed_roles;
create policy allowed_roles_admin_manage on public.allowed_roles for all to authenticated
using (public.is_admin()) with check (public.is_admin());

drop policy if exists clubs_read on public.clubs;
create policy clubs_read on public.clubs for select to authenticated using(status='approved' or public.is_admin());
drop policy if exists clubs_admin_all on public.clubs;
create policy clubs_admin_all on public.clubs for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated using(
  id=auth.uid() or public.is_admin() or exists(
    select 1 from public.club_memberships m where m.user_id=profiles.id and m.status='active' and public.can_manage_club(m.club_id)
  )
);
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update to authenticated using(id=auth.uid() or public.is_admin()) with check(id=auth.uid() or public.is_admin());
drop policy if exists memberships_read on public.club_memberships;
create policy memberships_read on public.club_memberships for select to authenticated using(user_id=auth.uid() or public.is_club_member(club_id));
drop policy if exists memberships_join on public.club_memberships;
create policy memberships_join on public.club_memberships for insert to authenticated with check(user_id=auth.uid() and membership_role='student' and status='active');
drop policy if exists memberships_manage on public.club_memberships;
create policy memberships_manage on public.club_memberships for update to authenticated using(public.can_manage_club(club_id)) with check(public.can_manage_club(club_id));
drop policy if exists club_requests_read on public.club_requests;
create policy club_requests_read on public.club_requests for select to authenticated using(proposed_by=auth.uid() or public.is_admin());
drop policy if exists club_requests_create on public.club_requests;
create policy club_requests_create on public.club_requests for insert to authenticated with check(proposed_by=auth.uid() and status='pending');
drop policy if exists club_requests_review on public.club_requests;
create policy club_requests_review on public.club_requests for update to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists events_read on public.events;
create policy events_read on public.events for select to authenticated using(status='approved' or public.is_admin() or public.can_manage_club(club_id));
drop policy if exists events_create on public.events;
create policy events_create on public.events for insert to authenticated with check(public.can_manage_club(club_id) and created_by=auth.uid() and status='pending');
drop policy if exists events_review on public.events;
create policy events_review on public.events for update to authenticated
using(public.is_admin() or (public.can_manage_club(club_id) and status='pending'))
with check(public.is_admin() or (public.can_manage_club(club_id) and status='pending'));
drop policy if exists registrations_read on public.event_registrations;
create policy registrations_read on public.event_registrations for select to authenticated using(user_id=auth.uid() or public.is_admin() or exists(select 1 from public.events e where e.id=event_id and public.can_manage_club(e.club_id)));
-- Aucune insertion directe : seule register_for_event peut enregistrer une présence,
-- afin de garantir l'application atomique de max_places.
drop policy if exists rooms_read on public.rooms;
create policy rooms_read on public.rooms for select to authenticated using(is_active or public.is_admin());
drop policy if exists rooms_admin on public.rooms;
create policy rooms_admin on public.rooms for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists equipment_read on public.equipment;
create policy equipment_read on public.equipment for select to authenticated using(is_active or public.is_admin());
drop policy if exists equipment_admin on public.equipment;
create policy equipment_admin on public.equipment for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists reservations_read on public.room_reservations;
create policy reservations_read on public.room_reservations for select to authenticated using(public.is_admin() or requested_by=auth.uid() or public.can_manage_club(club_id));
drop policy if exists reservations_create on public.room_reservations;
create policy reservations_create on public.room_reservations for insert to authenticated with check(public.can_manage_club(club_id) and requested_by=auth.uid() and status='pending');
drop policy if exists reservations_review on public.room_reservations;
create policy reservations_review on public.room_reservations for update to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists projects_club on public.projects;
create policy projects_club on public.projects for all to authenticated using(public.can_manage_club(club_id)) with check(public.can_manage_club(club_id));
drop policy if exists tasks_club on public.tasks;
create policy tasks_club on public.tasks for all to authenticated using(public.can_manage_club(club_id)) with check(public.can_manage_club(club_id));
drop policy if exists budgets_read on public.budgets;
create policy budgets_read on public.budgets for select to authenticated using(public.is_admin() or (club_id is not null and public.can_manage_club(club_id)));
drop policy if exists budgets_admin on public.budgets;
create policy budgets_admin on public.budgets for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists expenses_read on public.budget_expenses;
create policy expenses_read on public.budget_expenses for select to authenticated using(public.is_admin() or (club_id is not null and public.can_manage_club(club_id)));
drop policy if exists expenses_create on public.budget_expenses;
create policy expenses_create on public.budget_expenses for insert to authenticated with check(submitted_by=auth.uid() and club_id is not null and public.can_manage_club(club_id));
drop policy if exists expenses_admin on public.budget_expenses;
create policy expenses_admin on public.budget_expenses for update to authenticated using(public.is_admin()) with check(public.is_admin());

-- Données de référence du campus; aucune adresse staff de démonstration n'est autorisée.
insert into public.clubs(id,name,category,description,color,icon,meeting_place,status) values
 ('robotique','Club Robotique','Technologie','Imaginer, concevoir et donner vie à des robots.','blue','Cpu','Laboratoire A-12','approved'),
 ('genie-civil','Club Génie Civil','Ingénierie','Projets concrets, visites de chantier et concours.','orange','Construction','Atelier B-04','approved'),
 ('entrepreneuriat','Club Entrepreneuriat','Business','De l’idée au projet et accompagnement entrepreneurial.','violet','Lightbulb','Espace Coworking','approved'),
 ('design','Club Design & Créativité','Créativité','Créer, expérimenter et repousser les limites du design.','pink','Palette','Studio C-02','approved'),
 ('enactus','Enactus HESTIM','Impact social','Entreprendre pour un monde meilleur.','green','Sprout','Salle D-10','approved'),
 ('culture','Club Culture & Arts','Culture','Partager des moments artistiques et culturels.','amber','Music2','Amphithéâtre','approved')
on conflict(id) do update set name=excluded.name,category=excluded.category,description=excluded.description,color=excluded.color,icon=excluded.icon,meeting_place=excluded.meeting_place;

-- Retire les comptes staff fictifs de l'ancienne démo pour éviter tout accès privilégié implicite.
delete from public.allowed_roles where email in (
 'admin@hestim.ma','president.robotique@hestim.ma','vice.robotique@hestim.ma',
 'secretaire.civil@hestim.ma','membre.entrepreneuriat@hestim.ma'
);
delete from public.club_memberships m using public.profiles p
where m.user_id=p.id and p.email in (
 'admin@hestim.ma','president.robotique@hestim.ma','vice.robotique@hestim.ma',
 'secretaire.civil@hestim.ma','membre.entrepreneuriat@hestim.ma'
);
update public.profiles set role='student',bureau_role='Étudiant',club_id=null
where email in (
 'admin@hestim.ma','president.robotique@hestim.ma','vice.robotique@hestim.ma',
 'secretaire.civil@hestim.ma','membre.entrepreneuriat@hestim.ma'
);
update public.profiles p set role='student',bureau_role='Étudiant',club_id=null
where (p.role<>'student' or p.club_id is not null or coalesce(p.bureau_role,'')<>'Étudiant')
and not exists(select 1 from public.allowed_roles w where w.email=p.email);
update public.profiles p set role=w.role,bureau_role=w.bureau_role,club_id=w.club_id
from public.allowed_roles w where w.email=p.email;
insert into public.club_memberships(club_id,user_id,membership_role,status)
select club_id,id,role,'active' from public.profiles where role in ('bureau','member') and club_id is not null
on conflict(club_id,user_id) do update set membership_role=excluded.membership_role,status='active';

insert into public.rooms(name,capacity,location) values
 ('Laboratoire A-12',30,'Bâtiment A'),('Atelier B-04',30,'Bâtiment B'),('Espace Coworking',60,'Bâtiment C'),('Studio C-02',24,'Bâtiment C'),('Salle D-10',40,'Bâtiment D'),('Amphithéâtre',200,'Bâtiment principal'),('Salle A101',30,'Bâtiment A'),('Salle de réunion B2',12,'Bâtiment B')
on conflict(name) do update set capacity=excluded.capacity,location=excluded.location;
insert into public.equipment(name,quantity) values ('Kit maquette',5),('Vidéoprojecteur',4),('Kit robotique',8)
on conflict(name) do update set quantity=excluded.quantity;

-- Budgets prévisionnels de l'année universitaire 2026-2027 (dépenses réelles laissées à zéro).
insert into public.budgets(id,club_id,amount,year,label) values
 ('30000000-0000-4000-8000-000000000001','robotique',18500,2026,'2026-2027'),
 ('30000000-0000-4000-8000-000000000002','genie-civil',14200,2026,'2026-2027'),
 ('30000000-0000-4000-8000-000000000003','entrepreneuriat',22000,2026,'2026-2027'),
 ('30000000-0000-4000-8000-000000000004','design',12000,2026,'2026-2027'),
 ('30000000-0000-4000-8000-000000000005','enactus',25000,2026,'2026-2027'),
 ('30000000-0000-4000-8000-000000000006','culture',11000,2026,'2026-2027'),
 ('30000000-0000-4000-8000-000000000007',null,50000,2026,'2026-2027 · Campus')
on conflict(id) do nothing;

insert into public.events(id,club_id,title,description,event_date,location,category,max_places,status) values
 ('00000000-0000-4000-8000-000000000001','robotique','Hackathon HESTIM 2026','48 heures pour transformer vos idées en solutions concrètes.','2026-11-06 09:00:00+01','Campus HESTIM · Lab A','Technologie',80,'approved'),
 ('00000000-0000-4000-8000-000000000002','genie-civil','Construire la ville de demain','Une conversation autour des villes durables et des nouvelles pratiques.','2026-11-12 14:30:00+01','Amphithéâtre principal','Conférence',120,'approved'),
 ('00000000-0000-4000-8000-000000000003','entrepreneuriat','Pitch Night — Winter Edition','Présentez votre idée, trouvez votre équipe et faites le premier pas.','2026-11-19 18:00:00+01','Espace Coworking','Networking',60,'approved'),
 ('00000000-0000-4000-8000-000000000004','design','Design Sprint : repenser le campus','Un atelier collaboratif pour imaginer une expérience campus améliorée.','2026-11-24 10:00:00+01','Studio C-02','Atelier',30,'pending'),
 ('00000000-0000-4000-8000-000000000005','enactus','Forum des associations','Découvrez les clubs, leurs projets et comment vous engager.','2026-12-02 11:00:00+01','Esplanade HESTIM','Campus',200,'approved'),
 ('00000000-0000-4000-8000-000000000006','culture','Soirée des talents','Une scène ouverte pour célébrer les talents de la communauté HESTIM.','2026-12-10 19:00:00+01','Amphithéâtre principal','Culture',150,'pending')
on conflict(id) do nothing;

insert into public.projects(id,club_id,name) values
 ('10000000-0000-4000-8000-000000000001','robotique','Projets du club'),
 ('10000000-0000-4000-8000-000000000002','genie-civil','Projets du club'),
 ('10000000-0000-4000-8000-000000000003','entrepreneuriat','Projets du club')
on conflict(id) do nothing;
insert into public.tasks(id,project_id,club_id,title,status,priority,due_date,assignee) values
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','robotique','Prototype robot suiveur de ligne','todo','high','2026-11-20','Amine Berrada'),
 ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','robotique','Préparer le matériel du hackathon','doing','medium','2026-11-18','Yasmine El Mansouri'),
 ('20000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000002','genie-civil','Finaliser le dossier sponsor','todo','high','2026-11-22','Salma Idrissi'),
 ('20000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000003','entrepreneuriat','Préparer les pitchs de la soirée','todo','medium','2026-11-18','Omar Alaoui')
on conflict(id) do nothing;

-- L'administration gère les accès depuis HClubs; aucun rôle élevé n'est librement choisi à l'inscription.
create or replace function public.prevent_removing_last_admin_role() returns trigger
language plpgsql security definer set search_path = public,pg_temp
as $$
begin
  if old.role = 'admin' then
    if tg_op = 'DELETE' or (tg_op = 'UPDATE' and new.role is distinct from 'admin') then
      if not exists(select 1 from public.allowed_roles r where r.role='admin' and r.email<>old.email) then
        raise exception 'Au moins une adresse administrateur doit rester autorisée.';
      end if;
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;
drop trigger if exists allowed_roles_keep_admin on public.allowed_roles;
create trigger allowed_roles_keep_admin before update of role or delete on public.allowed_roles
for each row execute function public.prevent_removing_last_admin_role();

create or replace function public.sync_profile_from_allowed_role() returns trigger
language plpgsql security definer set search_path = public,pg_temp
as $$
declare target_user uuid;
begin
  if tg_op = 'DELETE' then
    select id into target_user from public.profiles where email=old.email;
    if target_user is not null then
      update public.club_memberships set membership_role='student',status='active'
      where user_id=target_user and club_id=old.club_id and membership_role in ('bureau','member');
      update public.profiles set role='student',bureau_role='Étudiant',club_id=null where id=target_user;
    end if;
    return old;
  end if;
  select id into target_user from public.profiles where email=new.email;
  if target_user is null then return new; end if;
  if tg_op = 'UPDATE' and old.role in ('bureau','member') then
    if new.role not in ('bureau','member') or new.club_id is distinct from old.club_id then
      update public.club_memberships set membership_role='student',status='active'
      where user_id=target_user and club_id=old.club_id and membership_role in ('bureau','member');
    end if;
  end if;
  update public.profiles set role=new.role,bureau_role=new.bureau_role,club_id=new.club_id where id=target_user;
  if new.role in ('bureau','member') and new.club_id is not null then
    insert into public.club_memberships(club_id,user_id,membership_role,status)
    values(new.club_id,target_user,new.role,'active')
    on conflict(club_id,user_id) do update set membership_role=excluded.membership_role,status='active';
  end if;
  return new;
end $$;
drop trigger if exists allowed_roles_sync_profile on public.allowed_roles;
create trigger allowed_roles_sync_profile after insert or update or delete on public.allowed_roles
for each row execute function public.sync_profile_from_allowed_role();

do $$ declare t text; begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    foreach t in array array['clubs','events','event_registrations','club_memberships','club_requests','room_reservations','tasks','budgets','budget_expenses'] loop
      begin execute format('alter publication supabase_realtime add table public.%I',t);
      exception when duplicate_object then null; end;
    end loop;
  end if;
end $$;

commit;
