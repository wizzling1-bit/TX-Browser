# TX Browser — Production FCM Push Notification Platform Design Specification

**Date:** 2026-09-25  
**Status:** Approved  
**Author:** Antigravity Architect  
**Target Platform:** Android (TX Browser Flutter App) + Node.js/TypeScript Fastify Backend + PostgreSQL + Vite/React Admin Dashboard  

---

## 1. Overview & System Goals

TX Browser requires an enterprise-grade, secure, production-ready push notification platform to deliver:
* Browser version updates and announcements
* Feature promotions, sponsored affiliate recommendations, and perks
* Critical security advisories and safe browsing notices
* Auxiliary download/activity notifications

The platform consists of three core subsystems:
1. **TX Browser Mobile Integration (Flutter + Android)**: Non-blocking Firebase/FCM client, token lifecycle synchronization, Android notification channels, runtime permission handling, deep link routing, and delivery/open tracking.
2. **Backend Notification Service (Fastify + PostgreSQL + Prisma + FCM Admin SDK)**: REST API, device registration/heartbeat, job queue worker, scheduler, Argon2id authentication, RBAC, and rate limiting.
3. **Admin Dashboard (Vite + React + TypeScript + Tailwind CSS)**: Premium, dark/light responsive control panel, live Android notification preview composer, audience management, analytics, and audit logging.

---

## 2. High-Level Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                   TX Browser Flutter App                    │
│                                                             │
│   ┌────────────────────────┐    ┌────────────────────────┐  │
│   │   FCM Client Service   │    │  Local Notification    │  │
│   └───────────┬────────────┘    └───────────▲────────────┘  │
│               │ Token Sync / Messages       │               │
│               ▼                             │ Foreground    │
│   ┌────────────────────────┐                │ Alerts        │
│   │ Notification Controller├────────────────┘               │
│   └───────────┬────────────┘                                │
│               │ Repositories                                │
│               ▼                                             │
│   ┌────────────────────────┐    ┌────────────────────────┐  │
│   │  Drift Local Database  │    │ Notification Settings  │  │
│   └────────────────────────┘    └────────────────────────┘  │
└───────────────────────┬─────────────────────────────────────┘
                        │ HTTPS (Register / Heartbeat / Open)
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                 Fastify Backend Service                     │
│                                                             │
│  ┌─────────────────────────┐     ┌───────────────────────┐  │
│  │   Device REST APIs      │     │  Admin Auth & REST    │  │
│  │ (/api/v1/devices/*)     │     │  (/api/v1/admin/*)    │  │
│  └────────────┬────────────┘     └───────────┬───────────┘  │
│               │                              │              │
│               ▼                              ▼              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │          PostgreSQL Database (Prisma ORM)             │  │
│  │ - device_installations       - notifications          │  │
│  │ - device_topics              - notification_jobs      │  │
│  │ - admin_users                - notification_deliveries│  │
│  │ - admin_audit_logs           - platform_settings      │  │
│  └────────────────────────┬──────────────────────────────┘  │
│                           │                                 │
│                           ▼                                 │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  PostgreSQL Job Queue Worker & Scheduler Service      │  │
│  │  - SELECT ... FOR UPDATE SKIP LOCKED                  │  │
│  │  - Topic Broadcasts & Multicast Chunking (500/batch)  │  │
│  └────────────────────────┬──────────────────────────────┘  │
└───────────────────────────┼─────────────────────────────────┘
                            │ FCM HTTP v1 / Firebase Admin SDK
                            ▼
             ┌──────────────────────────────┐
             │ Firebase Cloud Messaging API │
             └──────────────┬───────────────┘
                            │ Native Push / Topics
                            ▼
                 [ Real Android Devices ]
```

---

## 3. Subsystem 1: TX Browser Mobile Integration

### 3.1 Android Platform Setup
* **Application ID**: `com.wizzling.tx_browser` (Matches Google Play Store identifier).
* **Compile / Target SDK**: 36; **Min SDK**: 26.
* **Gradle Configuration**:
  * Apply Google Services plugin (`com.google.gms.google-services`) in `android/app/build.gradle.kts`.
  * Declare `com.google.gms:google-services` in root/settings plugin management.
* **Android Manifest**:
  * Ensure runtime permission `android.permission.POST_NOTIFICATIONS` is declared for Android 13+ (API 33+).
  * Configure default notification channel and icon metadata pointing to `@mipmap/ic_launcher`.

### 3.2 Notification Channels
Define 4 distinct Android notification channels upon initialization:
1. `tx_general`: General announcements and browser communications (Importance: `DEFAULT`).
2. `tx_updates`: Version updates and new feature releases (Importance: `HIGH`).
3. `tx_security`: Critical security advisories and safe browsing notices (Importance: `HIGH`).
4. `tx_promotions`: Featured deals, perks, and partner offers (Importance: `DEFAULT`).

### 3.3 Flutter Layer (Riverpod 3 Architecture)
* **Non-Blocking Startup**:
  * `main.dart` and `app.dart` bootstrap the browser UI immediately.
  * FCM initialization runs asynchronously in the background so browser cold start remains fast and responsive.
* **State Providers**:
  * `notificationServiceProvider`: Wraps FCM client, token listeners, and `flutter_local_notifications`.
  * `notificationRepositoryProvider`: Handles network communication with `/api/v1/devices/*`.
  * `notificationSettingsProvider`: Riverpod notifier exposing user notification preferences persisted in Drift.
* **Installation Identity & Token Lifecycle**:
  * A stable UUID `installation_id` is generated once and stored in Drift `settings`.
  * Calls `FirebaseMessaging.instance.getToken()` on launch.
  * Listens to `FirebaseMessaging.instance.onTokenRefresh` to keep the backend updated without requiring app restarts.
  * Subscribes to approved topics (`tx_all`, `tx_updates`, `tx_security`, `tx_promotions`) based on user preferences.
* **Permission UX Flow**:
  * Soft onboarding explanation sheet displayed on the Home Screen after the user's first browsing session.
  * Full settings toggle and topic customization in `SettingsScreen` under "Push Notifications".
* **Deep Link Router (`NotificationDeepLinkHandler`)**:
  * Sanitizes and parses `destinationType` and `destinationValue`:
    * `home`: Navigates to `/`.
    * `web_url`: Validates `https://` only, rejects untrusted schemes, and opens tab in `/browser`.
    * `play_store`: Validates Google Play Store URL for TX Browser and opens via external Android intent.
    * `downloads`, `bookmarks`, `history`, `tabs`, `settings`: Routes to internal GoRouter paths.
* **Open Tracking**:
  * Tapping a notification dispatches an asynchronous `POST /api/v1/devices/notification-open` payload containing `notificationId` and `installationId`.

---

## 4. Subsystem 2: Backend Notification Service & Database

### 4.1 Technology Stack
* **Framework**: Fastify (Node.js + TypeScript).
* **Database**: PostgreSQL with Prisma ORM.
* **Push Gateway**: Firebase Admin SDK (FCM HTTP v1 API).
* **Validation**: Zod schema validation for all incoming requests.
* **Security**: Argon2id for password hashing, `@fastify/cookie` + `@fastify/session` with secure HTTP-only cookies, `@fastify/helmet`, and `@fastify/cors`.

### 4.2 Database Schema (Prisma)

```prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

generator client {
  provider = "prisma-client-js"
}

enum AdminRole {
  SUPER_ADMIN
  ADMIN
  EDITOR
}

enum NotificationType {
  GENERAL
  BROWSER_UPDATE
  PROMOTION
  NEW_FEATURE
  SECURITY
  ANNOUNCEMENT
  MAINTENANCE
}

enum DestinationType {
  HOME
  WEB_URL
  PLAY_STORE
  INTERNAL_SCREEN
  NO_ACTION
}

enum AudienceType {
  ALL_USERS
  TOPIC
  SEGMENT
}

enum NotificationStatus {
  DRAFT
  SCHEDULED
  QUEUED
  SENDING
  SENT
  PARTIALLY_FAILED
  FAILED
  CANCELLED
}

enum JobStatus {
  PENDING
  PROCESSING
  COMPLETED
  FAILED
}

model AdminUser {
  id             String      @id @default(uuid())
  email          String      @unique
  passwordHash   String      @map("password_hash")
  name           String
  role           AdminRole   @default(ADMIN)
  isActive       Boolean     @default(true) @map("is_active")
  failedAttempts Int         @default(0) @map("failed_attempts")
  lockedUntil    DateTime?   @map("locked_until")
  lastLoginAt    DateTime?   @map("last_login_at")
  createdAt      DateTime    @default(now()) @map("created_at")
  updatedAt      DateTime    @updatedAt @map("updated_at")

  notifications  Notification[]
  auditLogs      AdminAuditLog[]

  @@map("admin_users")
}

model DeviceInstallation {
  id                     String    @id @default(uuid())
  installationId         String    @unique @map("installation_id")
  fcmToken               String    @map("fcm_token")
  platform               String    @default("android")
  appVersion             String    @map("app_version")
  buildNumber            Int       @map("build_number")
  androidVersion         String    @map("android_version")
  deviceModel            String    @map("device_model")
  notificationPermission String    @default("unknown") @map("notification_permission") // granted | denied | unknown
  isActive               Boolean   @default(true) @map("is_active")
  lastSeenAt             DateTime  @default(now()) @map("last_seen_at")
  createdAt              DateTime  @default(now()) @map("created_at")
  updatedAt              DateTime  @updatedAt @map("updated_at")

  topics                 DeviceTopic[]
  deliveries             NotificationDelivery[]

  @@index([fcmToken])
  @@index([isActive])
  @@index([lastSeenAt])
  @@index([appVersion])
  @@map("device_installations")
}

model DeviceTopic {
  id             String             @id @default(uuid())
  installationId String             @map("installation_id")
  topic          String
  createdAt      DateTime           @default(now()) @map("created_at")

  device         DeviceInstallation @relation(fields: [installationId], references: [installationId], onDelete: Cascade)

  @@unique([installationId, topic])
  @@map("device_topics")
}

model Notification {
  id               String             @id @default(uuid())
  title            String
  body             String
  imageUrl         String?            @map("image_url")
  notificationType NotificationType   @default(GENERAL) @map("notification_type")
  destinationType  DestinationType    @default(HOME) @map("destination_type")
  destinationValue String?            @map("destination_value")
  audienceType     AudienceType       @default(ALL_USERS) @map("audience_type")
  audienceConfig   Json?              @map("audience_config")
  status           NotificationStatus @default(DRAFT)
  scheduledAt      DateTime?          @map("scheduled_at")
  startedAt        DateTime?          @map("started_at")
  completedAt      DateTime?          @map("completed_at")
  createdById      String?            @map("created_by")
  createdAt        DateTime           @default(now()) @map("created_at")
  updatedAt        DateTime           @updatedAt @map("updated_at")

  createdBy        AdminUser?         @relation(fields: [createdById], references: [id])
  deliveries       NotificationDelivery[]
  jobs             NotificationJob[]

  @@index([status])
  @@index([scheduledAt])
  @@index([createdAt])
  @@map("notifications")
}

model NotificationJob {
  id             String       @id @default(uuid())
  notificationId String       @map("notification_id")
  jobType        String       @map("job_type") // TOPIC_SEND | MULTICAST_BATCH
  payload        Json
  status         JobStatus    @default(PENDING)
  attempts       Int          @default(0)
  maxAttempts    Int          @default(3) @map("max_attempts")
  errorMessage   String?      @map("error_message")
  lockedAt       DateTime?    @map("locked_at")
  lockedBy       String?      @map("locked_by")
  createdAt      DateTime     @default(now()) @map("created_at")
  updatedAt      DateTime     @updatedAt @map("updated_at")

  notification   Notification @relation(fields: [notificationId], references: [id], onDelete: Cascade)

  @@index([status, lockedAt])
  @@map("notification_jobs")
}

model NotificationDelivery {
  id                String              @id @default(uuid())
  notificationId    String              @map("notification_id")
  installationId    String?             @map("installation_id")
  providerMessageId String?             @map("provider_message_id")
  status            String              @default("SENT") // SENT | FAILED | OPENED
  errorCode         String?             @map("error_code")
  errorMessage      String?             @map("error_message")
  sentAt            DateTime?           @map("sent_at")
  deliveredAt       DateTime?           @map("delivered_at")
  openedAt          DateTime?           @map("opened_at")
  createdAt         DateTime            @default(now()) @map("created_at")
  updatedAt         DateTime            @updatedAt @map("updated_at")

  notification      Notification        @relation(fields: [notificationId], references: [id], onDelete: Cascade)
  device            DeviceInstallation? @relation(fields: [installationId], references: [installationId], onDelete: SetNull)

  @@index([notificationId])
  @@index([installationId])
  @@map("notification_deliveries")
}

model AdminAuditLog {
  id           String     @id @default(uuid())
  adminUserId  String?    @map("admin_user_id")
  action       String
  resourceType String     @map("resource_type")
  resourceId   String?    @map("resource_id")
  metadata     Json?
  ipAddress    String?    @map("ip_address")
  userAgent    String?    @map("user_agent")
  createdAt    DateTime   @default(now()) @map("created_at")

  adminUser    AdminUser? @relation(fields: [adminUserId], references: [id], onDelete: SetNull)

  @@index([adminUserId])
  @@index([action])
  @@map("admin_audit_logs")
}
```

### 4.3 Delivery Engine & Job Worker
* **Mass Broadcast via FCM Topics**:
  * Topic sends (`tx_all`, `tx_promotions`, `tx_updates`, `tx_security`, `tx_announcements`) execute via `messaging().send({ topic: ... })`.
  * Instantaneous, highly scalable, zero DB bottleneck.
* **Segmented Multicast Batches**:
  * Partitions device tokens into batches of 500.
  * Dispatches via `messaging().sendEachForMulticast()`.
  * Evaluates responses:
    * `messaging/registration-token-not-registered` or `messaging/invalid-registration-token` automatically flags `is_active = false` on the device installation.
* **PostgreSQL Queue Worker**:
  * Polling worker uses transactional `SELECT ... FOR UPDATE SKIP LOCKED` to lock jobs safely across instances.
  * Retries transient network failures with exponential backoff (up to 3 attempts).
* **Scheduler Worker**:
  * Runs every minute to find notifications with `status = SCHEDULED` and `scheduledAt <= NOW()`. Transitions them to `QUEUED` and enqueues worker jobs.

---

## 5. Subsystem 3: Admin Dashboard (Vite + React)

### 5.1 Architecture & Build
* Monorepo directory: `backend/admin` built into `backend/dist/admin` and served directly by Fastify under `/admin` (or root) with client-side SPA fallback.
* Tailwind CSS palette aligned with TX Browser's forest green & sage theme.
* Lucide React icons.

### 5.2 Screens & Capabilities
1. **Login (`/login`)**: Email/password authentication, CSRF cookie persistence, lockout countdown.
2. **Dashboard (`/dashboard`)**:
   * Overview bento cards (Total devices, active 30d, push-enabled %, sent today, sent month, delivery success rate).
   * Live recent campaign table with status badges and quick actions.
3. **Notification List (`/notifications`)**:
   * Filterable tabs: `All`, `Scheduled`, `Sent`, `Drafts`.
   * Search by title, status, and notification type.
4. **Composer (`/notifications/new` & `/notifications/:id/edit`)**:
   * Form inputs with strict Zod client validation.
   * **Live Android Preview Card**: Real-time reactive mockup showing the TX Browser push notification with expandable text and image preview.
   * **Send Confirmation Dialog**: For mass sends ("All Users"), shows total target audience estimation and requires explicit confirmation.
5. **Campaign Detail (`/notifications/:id`)**:
   * Delivery stats breakdown (Sent, Opened, Failed).
   * Error breakdown log.
   * Duplicate draft or cancel scheduled actions.
6. **Audiences (`/audiences`)**: Topic subscriber distributions and segment size calculator.
7. **Devices (`/devices`)**: Device registry table with version distribution, permission status, and last seen timestamps.
8. **Analytics (`/analytics`)**: Delivery rate trends, open rates, and category performance charts.
9. **Admin User Management (`/admin-users`)**: Super-admin user invitation and role updates.
10. **Audit Logs (`/audit-logs`)**: Complete historical log of administrative actions.

---

## 6. Security, Rate Limiting & Privacy

1. **No Credentials in Mobile App**: The Flutter app contains zero service account keys, admin secrets, or database URLs.
2. **Strict Privacy**:
   * Zero browsing history, URLs, bookmarks, passwords, or contacts collected.
   * Only installation UUID, FCM token, app version, Android version, device model, and permission status are stored.
   * Inactive devices (> 180 days) marked for retention purge.
3. **API Hardening**:
   * Rate limiting: 100 requests/minute for device API; 5 attempts/15 minutes for admin login.
   * Helmet security headers and CORS origin validation.
   * Input sanitization and SSRF prevention on external URLs.

---

## 7. Verification & Testing Strategy

1. **Backend Unit & Integration Tests**:
   * Test device registration & token refresh upsert.
   * Test admin login, rate limiting, and password hashing.
   * Test notification creation, audience resolution, and mock FCM dispatch.
   * Test invalid token deactivation logic.
2. **Flutter Integration Tests**:
   * Test Riverpod notification state notifier and repository.
   * Test deep link parsing (`web_url`, `home`, `play_store`, internal routes).
   * Test permission dialog flow and settings toggle.
3. **End-to-End Delivery Verification**:
   * Admin schedules/sends notification.
   * Backend worker processes job and contacts FCM.
   * Android client receives message, displays notification, and records open event upon tap.
