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
- `allowed_roles` attribue les rôles bureau, membre actif et administration côté serveur. Le sélecteur de rôle de l’inscription ne confère aucun privilège.
- RLS limite les événements publics approuvés, les tâches/réservations/budgets à l’équipe du club, et les actions de modération à l’administration.
- Les inscriptions aux événements passent par une fonction SQL transactionnelle. Les places ne peuvent pas dépasser `max_places` même en cas d’inscriptions simultanées.
- Les données sensibles ne doivent jamais être exposées avec une clé Supabase `service_role`. La clé publishable est la seule clé adaptée au navigateur.

Le script ne crée volontairement aucun compte staff fictif. Avant d’inscrire les responsables, ajoutez leurs vraies adresses dans la whitelist, par exemple :

```sql
insert into public.allowed_roles(email, role, bureau_role, club_id) values
  ('admin.reel@hestim.ma', 'admin', 'Administration', null),
  ('president.reel@hestim.ma', 'bureau', 'Président', 'robotique')
on conflict (email) do update
set role = excluded.role, bureau_role = excluded.bureau_role, club_id = excluded.club_id;
```

Inscrivez ensuite ces comptes via l’écran HClubs. Le trigger créera leurs profils et rôles depuis la whitelist. Supabase Auth doit également autoriser les adresses HESTIM selon la politique de l’établissement.

### Connexion de l’application

Le client utilise `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` et `VITE_AUTH_REDIRECT_URL`; créez `.env.local` pour le développement et définissez ces variables dans Vercel pour la production. La redirection de confirmation par défaut vise `https://h-clubs.vercel.app`, jamais une URL Vercel de prévisualisation. Dans Supabase > Authentication > URL Configuration, définissez cette URL comme **Site URL** et ajoutez `https://h-clubs.vercel.app/**` aux **Redirect URLs**. Ajoutez aussi les URLs locales de développement (`http://localhost:5173/**` et `http://127.0.0.1:5173/**`) si nécessaire. Sans configuration Supabase, l’application reste en mode démonstration `localStorage`.

Pour mettre à jour un projet existant avec la vérification du rôle demandé à l’inscription, exécutez une fois [`supabase/migrations/20261116_auth_signup_whitelist.sql`](supabase/migrations/20261116_auth_signup_whitelist.sql) après le schéma principal.

Après l’installation, créez un utilisateur étudiant avec une adresse `@hestim.ma`. Pour créer l’administrateur ou un responsable, ajoutez son adresse dans `allowed_roles` avant l’inscription Auth; le trigger crée alors son profil et son adhésion avec le rôle autorisé.

## Architecture

- `src/lib/supabase.js` : client Supabase.
- `src/lib/download.js` : exports CSV et calendrier ICS.
- `src/context/AuthContext.jsx` : Supabase Auth ou session de démonstration locale.
- `src/context/DataContext.jsx` : synchronisation des clubs, événements, membres, tâches, ressources, réservations et budgets.
- `supabase/schema.sql` : schéma complet, seeds, fonctions, triggers et politiques RLS.
- `src/data/mockData.js` : données du mode local et adresses de démonstration.
- `src/pages/AuthPage.jsx` : connexion et inscription.
- `src/pages/Dashboard.jsx` : annuaire, calendrier, Kanban, réservations, budget et administration.

Le mode `localStorage` sert à la démonstration. Pour la sécurité en production, les règles Supabase RLS restent l’autorité finale.
