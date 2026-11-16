# HClubs — Vie associative HESTIM

Application React + Vite pour découvrir les clubs, s’inscrire aux événements et gérer les espaces associatifs HESTIM.

## Démarrer

```bash
npm install
npm run dev
```

Le build de production se génère avec `npm run build` et se lance en aperçu avec `npm run preview`.

## Base de données Supabase

Le schéma de référence est [`supabase/schema.sql`](supabase/schema.sql). Ouvrez le SQL Editor du projet Supabase correspondant à l’URL configurée dans `src/lib/supabase.js`, collez le fichier complet et exécutez-le une fois. Le script crée ou complète les tables, installe les fonctions/triggers, remplace les anciennes policies permissives et active les abonnements Realtime disponibles.

Le script est conçu pour mettre à niveau la première structure HClubs déjà déployée. Faites tout de même un export de sauvegarde Supabase avant de l’exécuter sur une base contenant des données importantes. Il ne supprime pas les comptes Auth ni les données existantes.

Les tables couvrent les profils et rôles autorisés, clubs et demandes de création, adhésions, événements et inscriptions avec capacité, salles et matériel, demandes de réservation, projets et tâches Kanban, budgets annuels et dépenses.

### Règles d’accès

- Les comptes étudiants doivent utiliser une adresse `@hestim.ma`.
- `allowed_roles` attribue les rôles bureau, membre actif et administration côté serveur. Le choix à l’inscription est une demande; les droits restent attribués côté serveur.
- RLS limite les événements publics approuvés, les tâches/réservations/budgets à l’équipe du club, et les actions de modération à l’administration.
- Les inscriptions aux événements passent par une fonction SQL transactionnelle. Les places ne peuvent pas dépasser `max_places` même en cas d’inscriptions simultanées.
- Les données sensibles ne doivent jamais être exposées avec une clé Supabase `service_role`. La clé publishable est la seule clé adaptée au navigateur.

Tous les utilisateurs suivent le même formulaire avec une adresse `@hestim.ma`. Supabase attribue le rôle étudiant par défaut, ou celui déjà associé à l’adresse dans `allowed_roles`. Le choix du type de compte ne modifie pas les droits attribués par Supabase.

Pour autoriser les responsables d’un bureau, l’admin ajoute leurs vraies adresses HESTIM dans le même panneau, choisit la fonction (président, vice-président, secrétaire ou trésorier) et le club. Les étudiants conservent l’inscription libre avec leur adresse `@hestim.ma`.

Pour la première mise en service, un administrateur doit être autorisé une seule fois dans Supabase **Table Editor → allowed_roles**. Il n’y a pas d’adresse admin codée dans le projet. Après cette étape, les accès se gèrent depuis HClubs, dans **Administration → Autorisations des responsables**.

Pour un ajout manuel ponctuel, le SQL est :

```sql
insert into public.allowed_roles(email, role, bureau_role, club_id) values
  ('admin.reel@hestim.ma', 'admin', 'Administration', null),
  ('president.reel@hestim.ma', 'bureau', 'Président', 'robotique')
on conflict (email) do update
set role = excluded.role, bureau_role = excluded.bureau_role, club_id = excluded.club_id;
```

Inscrivez ensuite ces comptes via l’écran HClubs. Le trigger créera leurs profils et rôles depuis la whitelist. Supabase Auth doit également autoriser les adresses HESTIM selon la politique de l’établissement.

### Connexion de l’application

Le client utilise `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` et `VITE_AUTH_REDIRECT_URL`; créez `.env.local` pour le développement et définissez ces variables dans Vercel pour la production. La redirection de confirmation par défaut vise `https://h-clubs.vercel.app`, jamais une URL Vercel de prévisualisation. Dans Supabase > Authentication > URL Configuration, définissez cette URL comme **Site URL** et ajoutez `https://h-clubs.vercel.app/**` aux **Redirect URLs**. Ajoutez aussi les URLs locales de développement (`http://localhost:5173/**` et `http://127.0.0.1:5173/**`) si nécessaire. L’authentification utilise uniquement Supabase; les comptes de démonstration et le paramètre `?demo=1` ont été supprimés.

Pour mettre à jour un projet existant avec le parcours simplifié, exécutez une fois [`supabase/migrations/20261118_simple_auth_signup.sql`](supabase/migrations/20261118_simple_auth_signup.sql) dans Supabase SQL Editor.

Après l’installation, créez un utilisateur étudiant avec une adresse `@hestim.ma`. Pour créer l’administrateur ou un responsable, ajoutez son adresse dans `allowed_roles` avant l’inscription Auth; le trigger crée alors son profil et son adhésion avec le rôle autorisé.

## Architecture

- `src/lib/supabase.js` : client Supabase.
- `src/lib/download.js` : exports CSV et calendrier ICS.
- `src/context/AuthContext.jsx` : Supabase Auth et validation du type de connexion choisi.
- `src/context/DataContext.jsx` : synchronisation des clubs, événements, membres, tâches, ressources, réservations et budgets.
- `supabase/schema.sql` : schéma complet, seeds, fonctions, triggers et politiques RLS.
- `src/data/mockData.js` : données initiales et métadonnées de présentation des clubs.
- `src/pages/AuthPage.jsx` : connexion et inscription.
- `src/pages/Dashboard.jsx` : annuaire, calendrier, Kanban, réservations, budget et administration.

Les règles Supabase RLS restent l’autorité finale pour les permissions.

## Inscription étudiant / administrateur

La création de compte propose Étudiant ou Administrateur. Le choix est enregistré dans les métadonnées Auth de l’utilisateur, sous `requested_role`. Il exprime une demande et ne donne aucun droit. Dans Supabase, consultez **Authentication → Users** et les métadonnées du compte pour identifier les demandes administrateur.

Pour autoriser un administrateur, ajoutez sa vraie adresse `@hestim.ma` dans **Table Editor → allowed_roles**, avec `role = admin`, `bureau_role = Administration` et `club_id = NULL`. Le trigger de synchronisation du schéma doit être installé pour mettre à jour un profil existant. La personne doit ensuite se reconnecter.

La connexion est identique pour tous : les droits viennent du profil Supabase. Aucun compte ou mot de passe de démonstration n’est accepté par l’application.
