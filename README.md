# HClubs — Vie associative HESTIM

Application React + Vite pour découvrir les clubs, s’inscrire aux événements et gérer les espaces associatifs HESTIM.

## Démarrer

```bash
npm install
npm run dev
```

Le build de production se génère avec `npm run build` et se lance en aperçu avec `npm run preview`.

## Connexion Supabase

Exécutez [`supabase/schema.sql`](supabase/schema.sql), puis [`supabase/migrations/20261113_hclubs_features.sql`](supabase/migrations/20261113_hclubs_features.sql) dans le SQL Editor de votre projet Supabase. Copiez ensuite `.env.example` vers `.env.local`, puis renseignez la clé publique `anon` (ou publishable) du projet `tpatppstlkslhqzmayir`. L’URL fournie est déjà inscrite dans `.env.example`. Ne mettez jamais une clé `service_role` dans une application React.

Quand les deux variables `VITE_SUPABASE_URL` et `VITE_SUPABASE_ANON_KEY` sont définies, l’application utilise Supabase Auth et les tables SQL, en laissant les politiques RLS contrôler les accès. Sans elles, elle reste en mode démonstration `localStorage`.

Le code synchronise `profiles`, `clubs`, `club_memberships`, `events`, `event_registrations`, `rooms`, `room_reservations`, `projects`, `tasks` et `budgets`. Les changements sont relus après écriture et mis à jour en direct lorsque Supabase Realtime est activé. Les inscriptions aux événements passent par une fonction SQL transactionnelle qui bloque les doublons et les places au-delà de la capacité.

La migration ajoute la modération des événements, leur capacité, les inscriptions, les adhésions, les champs de tâche (statut, échéance, priorité, responsable) et les droits RLS des membres actifs. Le SQL ne gère toujours pas les dépenses réelles; le tableau de budget affiche donc les montants alloués et indique cette limite.

Le SQL contient des adresses de démonstration pour la whitelist. Remplacez-les par les adresses réellement autorisées avant d’ouvrir l’inscription Supabase aux utilisateurs HESTIM.

## Comptes de démonstration

Depuis l’écran de connexion, choisissez **Créer un compte**, puis l’un des boutons « Explorer la démo » pour préremplir un profil :

- Étudiant : `etudiant@hestim.ma`
- Bureau robotique : `president.robotique@hestim.ma`
- Administration : `admin@hestim.ma`

Ces comptes préremplis servent au mode local uniquement. Les profils locaux sont enregistrés dans le navigateur; les mots de passe y sont stockés sous forme d’empreintes salées. En mode Supabase, le trigger SQL attribue le rôle depuis `allowed_roles`.

## Architecture

- `src/lib/supabase.js` : client Supabase configuré par variables d’environnement.
- `src/lib/download.js` : export CSV et calendrier ICS.
- `src/context/AuthContext.jsx` : Supabase Auth ou session locale de démonstration.
- `src/context/DataContext.jsx` : synchronisation Supabase des clubs, événements, tâches, salles, réservations et budgets.
- `supabase/migrations/20261113_hclubs_features.sql` : capacités, inscriptions, adhésions, tâches et politiques RLS additionnelles.
- `src/data/mockData.js` : whitelist et données initiales.
- `src/pages/AuthPage.jsx` : authentification et inscription.
- `src/pages/Dashboard.jsx` : vues campus, calendrier, Kanban, réservations, budget et administration.

En mode Supabase, les règles d’accès de production doivent rester dans les politiques RLS côté base. Le mode local est uniquement destiné à la démonstration.
