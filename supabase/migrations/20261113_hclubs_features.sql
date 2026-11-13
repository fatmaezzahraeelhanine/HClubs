-- HClubs feature migration for the existing schema in schema.sql.
-- Run once in Supabase SQL Editor after the base schema.

-- Align the two sample club identifiers from the first SQL draft with the app.
do $$ begin
  if exists (select 1 from public.clubs where id = 'club-robotics') and not exists (select 1 from public.clubs where id = 'robotique') then
    update public.allowed_roles set club_id = 'robotique' where club_id = 'club-robotics';
    update public.profiles set club_id = 'robotique' where club_id = 'club-robotics';
    update public.events set club_id = 'robotique' where club_id = 'club-robotics';
    update public.room_reservations set club_id = 'robotique' where club_id = 'club-robotics';
    update public.projects set club_id = 'robotique' where club_id = 'club-robotics';
    update public.tasks set club_id = 'robotique' where club_id = 'club-robotics';
    update public.budgets set club_id = 'robotique' where club_id = 'club-robotics';
    update public.clubs set id = 'robotique', name = 'Club Robotique' where id = 'club-robotics';
  end if;
  if exists (select 1 from public.clubs where id = 'club-industrial') and not exists (select 1 from public.clubs where id = 'genie-civil') then
    update public.allowed_roles set club_id = 'genie-civil' where club_id = 'club-industrial';
    update public.profiles set club_id = 'genie-civil' where club_id = 'club-industrial';
    update public.events set club_id = 'genie-civil' where club_id = 'club-industrial';
    update public.room_reservations set club_id = 'genie-civil' where club_id = 'club-industrial';
    update public.projects set club_id = 'genie-civil' where club_id = 'club-industrial';
    update public.tasks set club_id = 'genie-civil' where club_id = 'club-industrial';
    update public.budgets set club_id = 'genie-civil' where club_id = 'club-industrial';
    update public.clubs set id = 'genie-civil', name = 'Club Génie Civil' where id = 'club-industrial';
  end if;
end $$;

insert into public.clubs(id, name) values
  ('robotique','Club Robotique'), ('genie-civil','Club Génie Civil'),
  ('entrepreneuriat','Club Entrepreneuriat'), ('design','Club Design & Créativité'),
  ('enactus','Enactus HESTIM'), ('culture','Club Culture & Arts')
on conflict (id) do update set name = excluded.name;

update public.allowed_roles set email = 'admin@hestim.ma', role = 'admin', bureau_role = null, club_id = null where email = 'test1@hestim.ma';
update public.allowed_roles set email = 'president.robotique@hestim.ma', bureau_role = 'Président', club_id = 'robotique' where email = 'test2@hestim.ma';
update public.allowed_roles set email = 'secretaire.civil@hestim.ma', bureau_role = 'Secrétaire', club_id = 'genie-civil' where email = 'test3@hestim.ma';
insert into public.allowed_roles(email, role, bureau_role, club_id) values
  ('vice.robotique@hestim.ma', 'bureau', 'Vice-président', 'robotique'),
  ('membre.entrepreneuriat@hestim.ma', 'member', 'Membre actif', 'entrepreneuriat')
on conflict (email) do update set role = excluded.role, bureau_role = excluded.bureau_role, club_id = excluded.club_id;

alter table public.events
  add column if not exists status text not null default 'approved',
  add column if not exists max_places integer not null default 30,
  add column if not exists location text not null default 'Campus HESTIM',
  add column if not exists category text not null default 'Campus';

alter table public.events drop constraint if exists events_status_check;
alter table public.events add constraint events_status_check check (status in ('pending','approved','rejected'));
alter table public.events drop constraint if exists events_max_places_check;
alter table public.events add constraint events_max_places_check check (max_places > 0);

alter table public.tasks
  add column if not exists priority text not null default 'medium',
  add column if not exists due_date date,
  add column if not exists assignee text not null default '';
alter table public.tasks drop constraint if exists tasks_priority_check;
alter table public.tasks add constraint tasks_priority_check check (priority in ('low','medium','high'));

alter table public.room_reservations
  add column if not exists purpose text not null default 'Réservation de salle',
  add column if not exists attendees integer not null default 1;
alter table public.room_reservations drop constraint if exists room_reservations_attendees_check;
alter table public.room_reservations add constraint room_reservations_attendees_check check (attendees > 0);

alter table public.allowed_roles drop constraint if exists allowed_roles_role_check;
alter table public.allowed_roles add constraint allowed_roles_role_check check (role in ('bureau','member','admin'));
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check check (role in ('student','bureau','member','admin'));

create table if not exists public.event_registrations (
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  registered_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

create table if not exists public.club_memberships (
  club_id text not null references public.clubs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (club_id, user_id)
);

alter table public.event_registrations enable row level security;
alter table public.club_memberships enable row level security;

drop policy if exists "lire events" on public.events;
drop policy if exists "gerer events" on public.events;
drop policy if exists "hclubs_read_visible_events" on public.events;
drop policy if exists "hclubs_bureau_create_events" on public.events;
drop policy if exists "hclubs_admin_update_events" on public.events;
create policy "hclubs_read_visible_events" on public.events for select to authenticated
  using (status = 'approved' or get_my_role() = 'admin' or (get_my_role() in ('bureau','member') and club_id = get_my_club()));
create policy "hclubs_bureau_create_events" on public.events for insert to authenticated
  with check (get_my_role() in ('bureau','member') and club_id = get_my_club() and status = 'pending');
create policy "hclubs_admin_update_events" on public.events for update to authenticated
  using (get_my_role() = 'admin') with check (get_my_role() = 'admin');

drop policy if exists "voir son profil ou admin" on public.profiles;
create policy "hclubs_read_own_club_profiles" on public.profiles for select to authenticated
  using (id = auth.uid() or get_my_role() = 'admin' or (club_id is not null and club_id = get_my_club()));

drop policy if exists "taches du club" on public.tasks;
drop policy if exists "hclubs_tasks_by_club" on public.tasks;
create policy "hclubs_tasks_by_club" on public.tasks for all to authenticated
  using (get_my_role() in ('admin','bureau','member') and (get_my_role() = 'admin' or club_id = get_my_club()))
  with check (get_my_role() in ('admin','bureau','member') and (get_my_role() = 'admin' or club_id = get_my_club()));

drop policy if exists "projets du club" on public.projects;
drop policy if exists "hclubs_projects_by_club" on public.projects;
create policy "hclubs_projects_by_club" on public.projects for all to authenticated
  using (get_my_role() in ('admin','bureau','member') and (get_my_role() = 'admin' or club_id = get_my_club()))
  with check (get_my_role() in ('admin','bureau','member') and (get_my_role() = 'admin' or club_id = get_my_club()));

drop policy if exists "voir reservations" on public.room_reservations;
drop policy if exists "creer reservation" on public.room_reservations;
drop policy if exists "admin approuve" on public.room_reservations;
create policy "hclubs_read_reservations" on public.room_reservations for select to authenticated
  using (get_my_role() = 'admin' or (get_my_role() in ('bureau','member') and club_id = get_my_club()));
create policy "hclubs_create_reservations" on public.room_reservations for insert to authenticated
  with check (get_my_role() in ('bureau','member') and club_id = get_my_club() and status = 'pending' and requested_by = auth.uid());
create policy "hclubs_admin_approve_reservations" on public.room_reservations for update to authenticated
  using (get_my_role() = 'admin') with check (get_my_role() = 'admin');

drop policy if exists "voir budgets" on public.budgets;
drop policy if exists "hclubs_read_budgets" on public.budgets;
create policy "hclubs_read_budgets" on public.budgets for select to authenticated
  using (get_my_role() = 'admin' or (get_my_role() in ('bureau','member') and club_id = get_my_club()));

drop policy if exists "hclubs_read_event_registrations" on public.event_registrations;
drop policy if exists "hclubs_register_self" on public.event_registrations;
create policy "hclubs_read_event_registrations" on public.event_registrations for select to authenticated using (true);
create policy "hclubs_register_self" on public.event_registrations for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "hclubs_read_memberships" on public.club_memberships;
drop policy if exists "hclubs_join_self" on public.club_memberships;
drop policy if exists "hclubs_admin_memberships" on public.club_memberships;
create policy "hclubs_read_memberships" on public.club_memberships for select to authenticated using (true);
create policy "hclubs_join_self" on public.club_memberships for insert to authenticated with check (user_id = auth.uid());
create policy "hclubs_admin_memberships" on public.club_memberships for delete to authenticated using (get_my_role() = 'admin');

create or replace function public.register_for_event(requested_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare target_event public.events%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise.'; end if;
  select * into target_event from public.events where id = requested_event_id and status = 'approved' for update;
  if not found then raise exception 'Cet événement n’est pas ouvert aux inscriptions.'; end if;
  if (select count(*) from public.event_registrations where event_id = requested_event_id) >= target_event.max_places then
    raise exception 'Cet événement a atteint sa capacité maximale.';
  end if;
  insert into public.event_registrations(event_id, user_id) values (requested_event_id, auth.uid());
exception when unique_violation then
  raise exception 'Vous êtes déjà inscrit à cet événement.';
end;
$$;
revoke all on function public.register_for_event(uuid) from public;
grant execute on function public.register_for_event(uuid) to authenticated;

-- Add tables to Supabase Realtime when the project uses the default publication.
do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin alter publication supabase_realtime add table public.events; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.tasks; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.room_reservations; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.event_registrations; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.club_memberships; exception when duplicate_object then null; end;
  end if;
end $$;
