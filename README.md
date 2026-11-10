# HClubs — Vie associative HESTIM

Application React + Vite pour découvrir les clubs, s’inscrire aux événements et gérer les espaces associatifs HESTIM.

## Démarrer

```bash
npm install
npm run dev
```

Le build de production se génère avec `npm run build` et se lance en aperçu avec `npm run preview`.

## Connexion Supabase

Exécutez [`supabase/schema.sql`](supabase/schema.sql) dans le SQL Editor de votre projet Supabase. Copiez ensuite `.env.example` vers `.env.local`, puis renseignez l’URL du projet et la clé publique `anon` (ou publishable). Ne mettez jamais une clé `service_role` dans une application React.

Quand les deux variables `VITE_SUPABASE_URL` et `VITE_SUPABASE_ANON_KEY` sont définies, l’application utilise Supabase Auth et les tables SQL, en laissant les politiques RLS contrôler les accès. Sans elles, elle reste en mode démonstration `localStorage`.

Le code mappe `profiles`, `clubs`, `events`, `rooms`, `room_reservations`, `projects`, `tasks` et `budgets`. Les changements de statut des tâches et réservations sont écrits dans la base.

### Limites du schéma actuel

Le SQL ne contient pas de table d’adhésions ou d’inscriptions aux événements, de demandes de nouveaux clubs, de statut d’approbation pour les événements, ni de dépenses. Ces actions sont donc désactivées en mode Supabase au lieu d’être simulées. Le rôle `member` n’est pas accepté par `profiles.role` et aucune politique RLS ne lui accorde d’accès. Le formulaire de salle n’envoie que des ressources existant dans `rooms`; les demandes de matériel ne sont pas prises en charge.

Pour couvrir ces fonctions, le schéma et les politiques RLS doivent être étendus avant de les activer.

## Comptes de démonstration

Depuis l’écran de connexion, choisissez **Créer un compte**, puis l’un des boutons « Explorer la démo » pour préremplir un profil :

- Étudiant : `etudiant@hestim.ma`
- Bureau robotique : `president.robotique@hestim.ma`
- Administration : `admin@hestim.ma`

Ces comptes préremplis servent au mode local uniquement. Les profils locaux sont enregistrés dans le navigateur; les mots de passe y sont stockés sous forme d’empreintes salées. En mode Supabase, le trigger SQL attribue le rôle depuis `allowed_roles`.

## Architecture

- `src/lib/supabase.js` : client Supabase configuré par variables d’environnement.
- `src/context/AuthContext.jsx` : Supabase Auth ou session locale de démonstration.
- `src/context/DataContext.jsx` : synchronisation Supabase des clubs, événements, tâches, salles, réservations et budgets.
- `src/data/mockData.js` : whitelist et données initiales.
- `src/pages/AuthPage.jsx` : authentification et inscription.
- `src/pages/Dashboard.jsx` : vues campus, calendrier, Kanban, réservations, budget et administration.

En mode Supabase, les règles d’accès de production doivent rester dans les politiques RLS côté base. Le mode local est uniquement destiné à la démonstration.
