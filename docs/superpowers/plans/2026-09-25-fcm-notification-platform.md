# TX Browser — Production FCM Notification Platform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete, secure, production-ready push notification platform for TX Browser, comprising mobile Flutter/Android integration, Fastify/PostgreSQL backend with FCM delivery worker, and a premium Vite React admin dashboard.

**Architecture:** Layered Riverpod 3 client in Flutter handling non-blocking FCM token lifecycle and deep links; Fastify Node.js/TypeScript REST API backed by PostgreSQL (Prisma ORM) with transactional row-level queue workers for topic/batch multicast FCM sends; and an embedded responsive Vite React admin dashboard.

**Tech Stack:** 
- Mobile: Flutter, Dart, Riverpod 3, Drift/SQLite, `firebase_core`, `firebase_messaging`, `flutter_local_notifications`, Kotlin (Android SDK 36)
- Backend: Node.js, TypeScript, Fastify, Prisma ORM, PostgreSQL, Firebase Admin SDK, Zod, Argon2id, `@fastify/session`, `@fastify/cookie`, `@fastify/helmet`, `@fastify/cors`
- Admin UI: Vite, React, TypeScript, Tailwind CSS, Lucide React

## Global Constraints
- Target Android SDK: 36, Compile SDK: 36, Min SDK: 26.
- Application ID: `com.wizzling.tx_browser` (Do NOT alter).
- Browser cold startup must remain fast and non-blocking (FCM initialization asynchronous).
- Flutter app must NEVER contain Firebase service account keys, admin passwords, or database secrets.
- Mass broadcast must use FCM topics (`tx_all`, `tx_updates`, `tx_security`, `tx_promotions`) to prevent DB bottlenecks; granular segments must chunk tokens in batches of 500.
- Strict input validation via Zod; plain text notifications only; deep links must enforce `https://` only.
- Passwords hashed with Argon2id; sessions managed via HTTP-only secure cookies.

---

### Task 1: Mobile Dependencies & Android Platform Configuration

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/settings.gradle.kts`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/google-services.json` (Mock template for development/build)

**Interfaces:**
- Consumes: Existing Android build configuration
- Produces: Google Services Gradle plugin applied, `firebase_core`, `firebase_messaging`, and `flutter_local_notifications` available to Dart

- [ ] **Step 1: Update pubspec.yaml with Firebase and Local Notifications packages**
Add `firebase_core: ^3.13.0`, `firebase_messaging: ^15.2.5`, and `flutter_local_notifications: ^19.0.0` under dependencies.

- [ ] **Step 2: Run flutter pub get**
Run: `flutter pub get`
Verify resolution succeeds without dependency conflicts.

- [ ] **Step 3: Update android/settings.gradle.kts with google-services plugin**
Add `id("com.google.gms.google-services") version "4.4.2" apply false` in `plugins { ... }`.

- [ ] **Step 4: Update android/app/build.gradle.kts**
Apply `id("com.google.gms.google-services")` in `plugins { ... }`. Add `coreLibraryDesugaring` if needed for notifications.

- [ ] **Step 5: Provide default development google-services.json template**
Create template in `android/app/google-services.json` matching `package_name: com.wizzling.tx_browser` so build passes.

- [ ] **Step 6: Update AndroidManifest.xml for notification metadata**
Ensure `POST_NOTIFICATIONS` is declared, and add default notification channel and icon metadata.

- [ ] **Step 7: Verify Flutter analysis passes**
Run: `flutter analyze`
Expected: No errors related to added dependencies.

- [ ] **Step 8: Commit**
```bash
git add pubspec.yaml pubspec.lock android/settings.gradle.kts android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml android/app/google-services.json
git commit -m "feat(mobile): add firebase and notification dependencies to android and flutter"
```

---

### Task 2: Flutter Notification Core Services & Deep Link Router

**Files:**
- Create: `lib/services/notification_service/notification_models.dart`
- Create: `lib/services/notification_service/notification_deep_link_handler.dart`
- Create: `lib/services/notification_service/notification_service.dart`
- Create: `lib/services/notification_service/notification_repository.dart`
- Create: `test/notification_deep_link_test.dart`
- Modify: `lib/data/database/tables/settings.dart` (or SettingsKeys)

**Interfaces:**
- Consumes: `firebase_messaging`, `flutter_local_notifications`, `http`, `uuid`
- Produces: `NotificationService` handling initialization, token retrieval, `onTokenRefresh`, topic subscriptions, and deep link routing

- [ ] **Step 1: Write test for NotificationDeepLinkHandler**
Create `test/notification_deep_link_test.dart` asserting:
- `web_url` with valid `https://example.com` resolves successfully to navigation payload.
- `web_url` with `javascript:alert(1)` or `http://` or malformed URL is safely rejected.
- `home`, `downloads`, `bookmarks`, `history`, `tabs`, `settings` resolve to valid app routes.
- `play_store` validates package ID and produces store intent URL.

- [ ] **Step 2: Run test to verify it fails**
Run: `flutter test test/notification_deep_link_test.dart`
Expected: FAIL (classes not implemented).

- [ ] **Step 3: Implement notification_models.dart**
Define `NotificationPayload`, `DestinationType`, `ApprovedTopic`, and `DeviceRegistrationPayload`.

- [ ] **Step 4: Implement notification_deep_link_handler.dart**
Validate and route incoming payloads with strict security guards against unsafe schemes.

- [ ] **Step 5: Implement notification_repository.dart**
Implement HTTP methods to communicate with `/api/v1/devices/register`, `/heartbeat`, and `/notification-open`.

- [ ] **Step 6: Implement notification_service.dart**
Handle:
- Background handler `@pragma('vm:entry-point')`
- Channel creation (`tx_general`, `tx_updates`, `tx_security`, `tx_promotions`)
- Firebase init, FCM token retrieval, `onTokenRefresh` listener
- Foreground message interception & local notification display
- Tap listener routing through `NotificationDeepLinkHandler` and reporting open events

- [ ] **Step 7: Run test to verify it passes**
Run: `flutter test test/notification_deep_link_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**
```bash
git add lib/services/notification_service/ test/notification_deep_link_test.dart
git commit -m "feat(mobile): implement notification service and deep link routing"
```

---

### Task 3: Flutter State Management & Settings UI Integration

**Files:**
- Create: `lib/state/notification_provider.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/features/home/home_screen.dart` (or contextual soft onboarding prompt sheet)
- Modify: `lib/app.dart` (initialize notification service asynchronously after bootstrap)
- Create: `test/notification_provider_test.dart`

**Interfaces:**
- Consumes: `NotificationService`, `NotificationRepository`, `databaseProvider`
- Produces: `notificationSettingsProvider`, contextual explanation sheet, push settings toggles in UI

- [ ] **Step 1: Write unit tests for notification_provider.dart**
Test:
- Initial state defaults (permission state, topic subscription map).
- Toggling notifications on/off calls service subscribe/unsubscribe.
- Toggling specific topics (`promotions`, `updates`, `security`) updates state and persists.

- [ ] **Step 2: Run test to verify it fails**
Run: `flutter test test/notification_provider_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement notification_provider.dart**
Build Riverpod 3 `NotificationNotifier` exposing state and methods for permission request, topic toggles, and sync.

- [ ] **Step 4: Integrate Push Notifications into SettingsScreen**
Add a clean "Push Notifications" group under Settings with:
- Master notification toggle
- Sub-toggles: Browser Updates (`tx_updates`), Security Advisories (`tx_security`), Featured Promotions (`tx_promotions`)
- Permission status indicator

- [ ] **Step 5: Add contextual explanation dialog/sheet**
Create `NotificationExplanationSheet` explaining benefits (downloads, updates, announcements) with [Allow] and [Not Now] buttons, shown after initial browsing.

- [ ] **Step 6: Wire asynchronous initialization in app.dart**
Call `ref.read(notificationServiceProvider).initialize()` asynchronously without blocking UI startup.

- [ ] **Step 7: Run test to verify it passes**
Run: `flutter test test/notification_provider_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**
```bash
git add lib/state/notification_provider.dart lib/features/settings/settings_screen.dart lib/app.dart test/notification_provider_test.dart
git commit -m "feat(mobile): integrate notification settings, permissions, and riverpod providers"
```

---

### Task 4: Backend Scaffolding, Fastify Server & Prisma PostgreSQL Database

**Files:**
- Create: `backend/package.json`
- Create: `backend/tsconfig.json`
- Create: `backend/.env.example`
- Create: `backend/prisma/schema.prisma`
- Create: `backend/src/config/env.ts`
- Create: `backend/src/db/prisma.ts`
- Create: `backend/src/server.ts`

**Interfaces:**
- Consumes: Node.js, PostgreSQL connection string
- Produces: Fastify server running on port 4000, Prisma client with PostgreSQL schema, environment loader with validation

- [ ] **Step 1: Initialize backend/package.json**
Add dependencies: `fastify`, `@fastify/cors`, `@fastify/helmet`, `@fastify/cookie`, `@fastify/session`, `@fastify/rate-limit`, `@fastify/static`, `prisma`, `@prisma/client`, `firebase-admin`, `zod`, `argon2`, `pino`.
Add devDependencies: `typescript`, `@types/node`, `tsx`, `vitest`, `supertest`.

- [ ] **Step 2: Create backend/tsconfig.json**
Target ES2022, module NodeNext, strict typechecking enabled.

- [ ] **Step 3: Define backend/prisma/schema.prisma**
Add complete models as specified in Design Document:
- `admin_users`, `device_installations`, `device_topics`, `notifications`, `notification_jobs`, `notification_deliveries`, `admin_audit_logs`.
Add all recommended indexes on `fcmToken`, `isActive`, `lastSeenAt`, `status`, `scheduledAt`, `createdAt`.

- [ ] **Step 4: Implement backend/src/config/env.ts**
Use Zod to validate `DATABASE_URL`, `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`, `ADMIN_SESSION_SECRET`, `PORT`, `CORS_ORIGINS`.

- [ ] **Step 5: Implement backend/src/server.ts**
Register Fastify plugins (helmet, cors, cookies, session, rate-limit), health check endpoints (`GET /health`, `GET /ready`).

- [ ] **Step 6: Create backend/.env.example**
Document all required environment variables with clear descriptions.

- [ ] **Step 7: Verify TypeScript build compiles**
Run: `npm run build` inside `backend/`
Expected: Clean compilation.

- [ ] **Step 8: Commit**
```bash
git add backend/
git commit -m "feat(backend): scaffold fastify server, prisma schema, and config"
```

---

### Task 5: Backend Device Registration, Heartbeat & Open Tracking APIs

**Files:**
- Create: `backend/src/schemas/device.schema.ts`
- Create: `backend/src/routes/device.routes.ts`
- Create: `backend/src/services/device.service.ts`
- Create: `backend/tests/device.test.ts`

**Interfaces:**
- Consumes: Prisma client
- Produces: `POST /api/v1/devices/register`, `POST /api/v1/devices/heartbeat`, `POST /api/v1/devices/notification-open`

- [ ] **Step 1: Write test for device registration and heartbeat in backend/tests/device.test.ts**
Test:
- Valid payload upserts `device_installations`.
- Token refresh updates existing device installation by `installation_id`.
- Heartbeat updates `last_seen_at` and permission.
- Invalid token/empty payload fails with 400 validation error.

- [ ] **Step 2: Run test to verify it fails**
Run: `npx vitest run tests/device.test.ts`
Expected: FAIL.

- [ ] **Step 3: Implement device.schema.ts with Zod**
Enforce validation for `installationId` (UUID), `fcmToken`, `appVersion`, `buildNumber`, `androidVersion`, `deviceModel`.

- [ ] **Step 4: Implement device.service.ts**
Upsert device record, update topics, update last seen timestamp, record notification opens.

- [ ] **Step 5: Implement device.routes.ts**
Register endpoints under `/api/v1/devices` with Fastify rate limiting.

- [ ] **Step 6: Run test to verify it passes**
Run: `npx vitest run tests/device.test.ts`
Expected: PASS.

- [ ] **Step 7: Commit**
```bash
git add backend/src/schemas/device.schema.ts backend/src/routes/device.routes.ts backend/src/services/device.service.ts backend/tests/device.test.ts
git commit -m "feat(backend): implement device registration, heartbeat, and open tracking endpoints"
```

---

### Task 6: Admin Authentication, RBAC & Audit Logging

**Files:**
- Create: `backend/src/schemas/auth.schema.ts`
- Create: `backend/src/services/auth.service.ts`
- Create: `backend/src/routes/auth.routes.ts`
- Create: `backend/src/middleware/auth.guard.ts`
- Create: `backend/src/services/audit.service.ts`
- Create: `backend/src/scripts/seed-admin.ts`
- Create: `backend/tests/auth.test.ts`

**Interfaces:**
- Consumes: Argon2, `@fastify/session`, Prisma client
- Produces: Secure admin login/logout, session verification, RBAC guard (`SUPER_ADMIN`, `ADMIN`, `EDITOR`), audit logging

- [ ] **Step 1: Write test for auth in backend/tests/auth.test.ts**
Test:
- Argon2id password verification.
- Login returns session cookie and user profile.
- Failed attempts increment and lock out after 5 failures.
- RBAC guard permits/rejects based on role.

- [ ] **Step 2: Run test to verify it fails**
Run: `npx vitest run tests/auth.test.ts`
Expected: FAIL.

- [ ] **Step 3: Implement auth.service.ts with Argon2id**
Hash passwords with Argon2id; verify passwords; manage lockout window; generate audit logs.

- [ ] **Step 4: Implement auth.routes.ts & auth.guard.ts**
Add `POST /api/v1/auth/login`, `POST /api/v1/auth/logout`, `GET /api/v1/auth/me`. Protect routes with `requireAuth` and `requireRole(roles)`.

- [ ] **Step 5: Implement seed-admin.ts script**
Provide a seed command (`npm run seed:admin`) to create the initial `SUPER_ADMIN` safely via environment variables.

- [ ] **Step 6: Run test to verify it passes**
Run: `npx vitest run tests/auth.test.ts`
Expected: PASS.

- [ ] **Step 7: Commit**
```bash
git add backend/src/schemas/auth.schema.ts backend/src/services/auth.service.ts backend/src/routes/auth.routes.ts backend/src/middleware/auth.guard.ts backend/src/services/audit.service.ts backend/src/scripts/seed-admin.ts backend/tests/auth.test.ts
git commit -m "feat(backend): implement admin authentication with argon2id, rbac, and audit logging"
```

---

### Task 7: FCM Delivery Engine, Job Queue Worker & Scheduler

**Files:**
- Create: `backend/src/services/fcm.service.ts`
- Create: `backend/src/services/queue.service.ts`
- Create: `backend/src/services/scheduler.service.ts`
- Create: `backend/tests/fcm_delivery.test.ts`

**Interfaces:**
- Consumes: Firebase Admin SDK, Prisma client
- Produces: Topic sending, 500-token chunked multicast sending, token deactivation, PostgreSQL job queue worker with `FOR UPDATE SKIP LOCKED`, scheduler worker

- [ ] **Step 1: Write test for FCM delivery engine in backend/tests/fcm_delivery.test.ts**
Mock Firebase Admin SDK messaging:
- Test topic send formats payload correctly.
- Test multicast send batches 1,200 tokens into 3 chunks (500, 500, 200).
- Test invalid token errors (`messaging/registration-token-not-registered`) mark devices inactive.
- Test queue worker locks and completes jobs.

- [ ] **Step 2: Run test to verify it fails**
Run: `npx vitest run tests/fcm_delivery.test.ts`
Expected: FAIL.

- [ ] **Step 3: Implement fcm.service.ts**
Initialize Firebase Admin SDK; build message payloads; handle topic send; handle `sendEachForMulticast`; handle response classification and token deactivation.

- [ ] **Step 4: Implement queue.service.ts**
Use PostgreSQL row locking (`SELECT ... FOR UPDATE SKIP LOCKED`) to fetch pending jobs, process topic/multicast chunks, and record delivery records.

- [ ] **Step 5: Implement scheduler.service.ts**
Poll due notifications (`scheduledAt <= NOW() && status = 'SCHEDULED'`), transition them to `QUEUED`, and enqueue delivery jobs.

- [ ] **Step 6: Run test to verify it passes**
Run: `npx vitest run tests/fcm_delivery.test.ts`
Expected: PASS.

- [ ] **Step 7: Commit**
```bash
git add backend/src/services/fcm.service.ts backend/src/services/queue.service.ts backend/src/services/scheduler.service.ts backend/tests/fcm_delivery.test.ts
git commit -m "feat(backend): implement fcm delivery engine, chunked multicast, queue worker, and scheduler"
```

---

### Task 8: Backend Admin REST API (Campaigns, Audiences, Analytics)

**Files:**
- Create: `backend/src/schemas/notification.schema.ts`
- Create: `backend/src/routes/notification.routes.ts`
- Create: `backend/src/routes/audience.routes.ts`
- Create: `backend/src/routes/device_admin.routes.ts`
- Create: `backend/src/routes/analytics.routes.ts`
- Create: `backend/src/routes/audit.routes.ts`
- Create: `backend/src/routes/admin_user.routes.ts`
- Create: `backend/tests/notification_crud.test.ts`

**Interfaces:**
- Consumes: Auth guard, Prisma client, queue service
- Produces: Complete Admin API endpoints under `/api/v1/`

- [ ] **Step 1: Write test for notification CRUD and send trigger in backend/tests/notification_crud.test.ts**
Test:
- Create draft notification with Zod validation.
- Schedule notification for future date.
- Send notification enqueues job and updates status to `QUEUED`.
- Cancel notification cancels scheduled jobs.
- Audience stats endpoint returns real subscriber numbers.

- [ ] **Step 2: Run test to verify it fails**
Run: `npx vitest run tests/notification_crud.test.ts`
Expected: FAIL.

- [ ] **Step 3: Implement notification.schema.ts with Zod**
Validate title, body, optional image URL (HTTPS), destination type and value, audience type and config.

- [ ] **Step 4: Implement notification.routes.ts**
CRUD + Send (`POST /:id/send`) + Cancel (`POST /:id/cancel`). Include idempotency checks.

- [ ] **Step 5: Implement audience.routes.ts, analytics.routes.ts, and device_admin.routes.ts**
Return real counts: active devices, permission-granted counts, deliveries, opens, topics distribution.

- [ ] **Step 6: Implement audit.routes.ts and admin_user.routes.ts**
List audit logs and manage admin users (restricted to `SUPER_ADMIN`).

- [ ] **Step 7: Run test to verify it passes**
Run: `npx vitest run tests/notification_crud.test.ts`
Expected: PASS.

- [ ] **Step 8: Commit**
```bash
git add backend/src/schemas/notification.schema.ts backend/src/routes/ backend/tests/notification_crud.test.ts
git commit -m "feat(backend): implement admin notification management, analytics, and audience apis"
```

---

### Task 9: Premium Admin Dashboard UI (Vite + React + Tailwind)

**Files:**
- Create: `backend/admin/package.json`
- Create: `backend/admin/vite.config.ts`
- Create: `backend/admin/tailwind.config.js`
- Create: `backend/admin/src/index.css`
- Create: `backend/admin/src/App.tsx`
- Create: `backend/admin/src/components/layout/Sidebar.tsx`
- Create: `backend/admin/src/components/layout/Header.tsx`
- Create: `backend/admin/src/pages/Login.tsx`
- Create: `backend/admin/src/pages/Dashboard.tsx`
- Create: `backend/admin/src/pages/NotificationsList.tsx`
- Create: `backend/admin/src/pages/NotificationComposer.tsx` (with Live Android Preview & Confirm Modal)
- Create: `backend/admin/src/pages/NotificationDetail.tsx`
- Create: `backend/admin/src/pages/Audiences.tsx`
- Create: `backend/admin/src/pages/Devices.tsx`
- Create: `backend/admin/src/pages/Analytics.tsx`
- Create: `backend/admin/src/pages/AdminUsers.tsx`
- Create: `backend/admin/src/pages/AuditLogs.tsx`
- Modify: `backend/src/server.ts` (serve static admin bundle under `/admin` and root fallback)

**Interfaces:**
- Consumes: Backend REST APIs (`/api/v1/*`)
- Produces: Complete, responsive admin dashboard SPA styled with TX Browser forest/sage palette

- [ ] **Step 1: Initialize backend/admin with Vite + React + TypeScript + Tailwind**
Install `lucide-react`, `clsx`, `tailwind-merge`. Configure Tailwind with brand colors (`#1B2419`, `#609966`, `#9DC08B`, `#EDF1D6`).

- [ ] **Step 2: Build API client and Auth Context**
Handle session state, login, logout, and automatic redirect on 401.

- [ ] **Step 3: Implement Sidebar and Layout**
Responsive navigation with desktop sticky sidebar, mobile drawer, user profile indicator, and navigation badges.

- [ ] **Step 4: Implement Dashboard page**
Bento grid of real metrics (Total devices, active 30d, notification-enabled %, delivery success rate, open rate) and live recent notification table.

- [ ] **Step 5: Implement NotificationComposer with Live Android Preview & Confirm Modal**
- Left side: Title, body, type selector (`Promotion`, `Browser Update`, etc.), destination type, image URL, audience selector, schedule picker.
- Right side: Live Android Notification preview card updating reactively.
- Send confirmation modal with audience size estimation.

- [ ] **Step 6: Implement NotificationsList, Detail, Audiences, Devices, and Analytics pages**
Tables with search, status filters, delivery breakdown metrics, and real device list.

- [ ] **Step 7: Build admin bundle and configure Fastify static serving**
Add `npm run build:admin` and wire `@fastify/static` in `server.ts` so the dashboard runs seamlessly from the backend server.

- [ ] **Step 8: Commit**
```bash
git add backend/admin/ backend/src/server.ts
git commit -m "feat(admin): build premium responsive admin dashboard with live android notification preview"
```

---

### Task 10: Documentation, Production Verification & Real Device Setup

**Files:**
- Create: `docs/FCM_SETUP.md`
- Modify: `README.md`
- Run: Complete backend and Flutter test suites
- Run: Flutter static analysis and release compilation check

**Interfaces:**
- Consumes: Complete project implementation
- Produces: Setup documentation, passing automated tests, verified production build

- [ ] **Step 1: Write docs/FCM_SETUP.md**
Document:
1. Firebase project setup and downloading `google-services.json`.
2. Service Account key generation for backend.
3. PostgreSQL database initialization and Prisma migration command.
4. Admin seeding (`npm run seed:admin`).
5. Running backend and admin locally.
6. Android verification matrix and deep-link testing.

- [ ] **Step 2: Run all backend tests**
Run: `npm test` inside `backend/`
Expected: All unit & integration tests pass.

- [ ] **Step 3: Run Flutter tests**
Run: `flutter test`
Expected: All Flutter unit and widget tests pass.

- [ ] **Step 4: Run flutter analyze**
Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 5: Commit documentation and final integration**
```bash
git add docs/FCM_SETUP.md README.md
git commit -m "docs: add fcm setup instructions and production deployment guide"
```
