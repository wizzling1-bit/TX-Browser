# TX Browser

A fast, privacy-focused, and extensible production Android web browser built with Flutter and Native Android components.

## Features

- **Blazing Fast Browsing Engine**: Optimized webview runtime with smooth tab management and session caching.
- **Privacy & AdBlock Suite**: Built-in content blocking, tracking protection, and private browsing modes.
- **Production FCM Push Notification Platform**:
  - Flutter & Android 14+ FCM integration with non-blocking lifecycle.
  - Dedicated Android notification channels: General, Updates, Promotions, Security.
  - Soft contextual permission onboarding prompt and granular in-app settings toggles.
  - Strict HTTPS deep-link routing (`WEB_URL`, `HOME`, `PLAY_STORE`, `INTERNAL_SCREEN`).
  - Fastify / TypeScript backend API with PostgreSQL and Prisma ORM.
  - High-throughput push delivery engine (native topic broadcast + 500-token chunked multicast).
  - PostgreSQL transactional queue worker (`FOR UPDATE SKIP LOCKED`) and automated scheduler.
  - Premium Vite React Admin Dashboard with live Android 14+ notification preview frame.
  - Token health tracking, invalid token auto-deactivation, and Argon2id RBAC security.

## Setup Guides

- **Push Notification Platform Setup**: Detailed instructions for Firebase, backend deployment, database migrations, and admin dashboard usage can be found in [docs/FCM_SETUP.md](docs/FCM_SETUP.md).

## Project Structure

```
tx_browser/
├── android/              # Native Android configuration (Target SDK 36, FCM manifest)
├── backend/              # Fastify TypeScript push notification backend
│   ├── admin/            # Vite + React + Tailwind premium admin console
│   ├── prisma/           # PostgreSQL schema and migrations
│   ├── src/              # Server, API routes, FCM delivery engine, queue worker
│   └── tests/            # Vitest unit & integration test suites
├── lib/                  # Flutter application source code
│   ├── features/         # Browser, settings, downloads, history, tabs
│   ├── services/         # NotificationService, deep-link router, ad blocker
│   └── state/            # Riverpod state notifiers and providers
└── test/                 # Flutter test suites
```

## Running the Project

### Flutter Mobile App
```bash
flutter pub get
flutter run
```

### Notification Backend & Admin Dashboard
```bash
cd backend
npm install
npm run build
npm start
```
The Admin Console will be accessible at `http://localhost:4000/admin/`.
