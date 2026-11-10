-- =====================================================
-- CAMPUS CLUBS HESTIM - Base de données complète
-- À coller dans Supabase : SQL Editor > New query > Run
-- =====================================================

-- ========== 1. TABLES ==========
create table clubs (
  id text primary key,
  name text not null
);

create table allowed_roles (
  email text primary key check (email like '%@hestim.ma'),
  role text not null check (role in ('bureau','admin')),
  bureau_role text,
  club_id text references clubs(id)
);

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  email text unique not null check (email like '%@hestim.ma'),
  role text not null default 'student' check (role in ('student','bureau','admin')),
  bureau_role text,
  club_id text references clubs(id)
);

create table events (
  id uuid primary key default gen_random_uuid(),
  club_id text not null references clubs(id),
  title text not null,
  description text,
  event_date timestamptz not null
);

create table rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  capacity int
);

create table room_reservations (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id),
  club_id text not null references clubs(id),
  requested_by uuid not null references profiles(id),
  start_time timestamptz not null,
  end_time timestamptz not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  check (end_time > start_time)
);

create table projects (
  id uuid primary key default gen_random_uuid(),
  club_id text not null references clubs(id),
  name text not null
);

create table tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  club_id text not null references clubs(id),
  title text not null,
  status text not null default 'todo' check (status in ('todo','doing','done'))
);

create table budgets (
  id uuid primary key default gen_random_uuid(),
  club_id text references clubs(id),   -- null = budget de l'établissement
  amount numeric not null,
  year int not null
);

-- ========== 2. FONCTIONS UTILITAIRES ==========
create function get_my_role() returns text
language sql security definer set search_path = public stable
as $$ select role from profiles where id = auth.uid() $$;

create function get_my_club() returns text
language sql security definer set search_path = public stable
as $$ select club_id from profiles where id = auth.uid() $$;

-- ========== 3. TRIGGER D'INSCRIPTION ==========
-- Le rôle est attribué ICI, depuis la whitelist (jamais depuis le client)
create function handle_new_user() returns trigger
language plpgsql security definer set search_path = public
as $$
declare w allowed_roles%rowtype;
begin
  if new.email not like '%@hestim.ma' then
    raise exception 'Email institutionnel @hestim.ma obligatoire';
  end if;

  select * into w from allowed_roles where lower(email) = lower(new.email);

  insert into profiles (id, name, email, role, bureau_role, club_id)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', 'Sans nom'),
    new.email,
    coalesce(w.role, 'student'),
    w.bureau_role,
    w.club_id
  );
  return new;
end $$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function handle_new_user();

-- ========== 4. SÉCURITÉ (Row Level Security) ==========
alter table clubs enable row level security;
alter table allowed_roles enable row level security;
alter table profiles enable row level security;
alter table events enable row level security;
alter table rooms enable row level security;
alter table room_reservations enable row level security;
alter table projects enable row level security;
alter table tasks enable row level security;
alter table budgets enable row level security;

-- allowed_roles : aucune policy = inaccessible depuis React (seul le trigger la lit)

-- profiles
create policy "voir son profil ou admin" on profiles for select
  using (id = auth.uid() or get_my_role() = 'admin');
create policy "admin modifie profils" on profiles for all
  using (get_my_role() = 'admin');

-- clubs et salles : lecture pour tous les connectés, écriture admin
create policy "lire clubs" on clubs for select to authenticated using (true);
create policy "admin clubs" on clubs for all using (get_my_role() = 'admin');
create policy "lire salles" on rooms for select to authenticated using (true);
create policy "admin salles" on rooms for all using (get_my_role() = 'admin');

-- événements : lecture pour tous, écriture bureau du club ou admin
create policy "lire events" on events for select to authenticated using (true);
create policy "gerer events" on events for all
  using (get_my_role() = 'admin' or (get_my_role() = 'bureau' and club_id = get_my_club()))
  with check (get_my_role() = 'admin' or (get_my_role() = 'bureau' and club_id = get_my_club()));

-- réservations de salles
create policy "voir reservations" on room_reservations for select
  using (get_my_role() = 'admin' or (get_my_role() = 'bureau' and club_id = get_my_club()));
create policy "creer reservation" on room_reservations for insert
  with check (get_my_role() = 'bureau' and club_id = get_my_club()
              and status = 'pending' and requested_by = auth.uid());
create policy "admin approuve" on room_reservations for update
  using (get_my_role() = 'admin');

-- projets et tâches (Kanban)
create policy "projets du club" on projects for all
  using (get_my_role() = 'admin' or (get_my_role() = 'bureau' and club_id = get_my_club()))
  with check (get_my_role() = 'admin' or (get_my_role() = 'bureau' and club_id = get_my_club()));
create policy "taches du club" on tasks for all
  using (get_my_role() = 'admin' or (get_my_role() = 'bureau' and club_id = get_my_club()))
  with check (get_my_role() = 'admin' or (get_my_role() = 'bureau' and club_id = get_my_club()));

-- budgets
create policy "voir budgets" on budgets for select
  using (get_my_role() = 'admin' or (get_my_role() = 'bureau' and club_id = get_my_club()));
create policy "admin budgets" on budgets for all using (get_my_role() = 'admin');

-- ========== 5. DONNÉES DE DÉPART ==========
insert into clubs values
  ('club-robotics','Club Robotique'),
  ('club-industrial','Club Génie Industriel');

-- Emails de test (à remplacer par les vrais emails plus tard)
insert into allowed_roles values
  ('test1@hestim.ma','admin',null,null),
  ('test2@hestim.ma','bureau','president','club-robotics'),
  ('test3@hestim.ma','bureau','vice-president','club-industrial');

insert into rooms (name, capacity) values
  ('Salle A101', 30),
  ('Amphithéâtre', 120),
  ('Salle de réunion B2', 12);
