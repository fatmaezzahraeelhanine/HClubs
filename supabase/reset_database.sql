-- ATTENTION : ce script efface définitivement les comptes Auth et toutes les données HClubs.
-- À exécuter seulement dans Supabase SQL Editor avec le rôle postgres,
-- puis exécuter immédiatement supabase/schema.sql dans le même projet.

begin;

delete from auth.users;
drop schema public cascade;
create schema public;
grant all on schema public to postgres;
grant usage on schema public to anon, authenticated, service_role;

commit;
