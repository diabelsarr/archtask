# ArchTask

Application mobile de gestion de tâches (Flutter) avec une API REST Strapi v5.
Projet du module DEVMOBILE.

## Fonctionnalités

- Inscription, connexion (JWT), connexion automatique, déconnexion
- Tâches personnelles : création, modification, suppression, priorité, date et heure d'échéance
- Recherche, filtres (Toutes / En cours / Terminées, priorité), statistiques
- Cache local Hive : les tâches restent visibles hors ligne
- Profil : nom, e-mail, téléphone, photo de profil
- Rappels (notification locale 10 min avant l'échéance)
- Thème clair / sombre / automatique, partage d'une tâche

## Structure

```
archtask/
├── lib/        # application Flutter
├── android/
├── backend/    # API Strapi v5
└── docs/       # rapport
```

## Prérequis

- Flutter (stable) et Android SDK
- Node.js 20 ou 22 et npm
- Un téléphone Android avec le débogage USB activé

## Lancer le serveur

```bash
cd backend
cp .env.example .env     # puis renseigner les clés
npm install
npm run develop          # http://localhost:1337/admin
```

Créer un compte administrateur au premier lancement.
Dans Settings > Users & Permissions > Roles > Authenticated, autoriser les actions du type `task` (find, findOne, create, update, delete) et `users-permissions` (me, update).

## Lancer l'application

Téléphone branché en USB :

```bash
adb reverse tcp:1337 tcp:1337
flutter pub get
flutter run
```

L'application appelle `http://localhost:1337/api` (voir `lib/utils/api_config.dart`).
Le tunnel `adb reverse` doit être recréé après chaque rebranchement.

## Technologies

Flutter, Dart, `http`, Hive, `shared_preferences`, `image_picker`, `share_plus`, `flutter_local_notifications`, Strapi v5, SQLite.

## Auteur

Projet réalisé par : Diabel SARR
