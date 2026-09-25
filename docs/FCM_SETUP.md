# TX Browser — Production FCM Push Notification Platform Setup Guide

This guide details the complete configuration, deployment, and operational procedures for the **TX Browser Push Notification Platform**, consisting of:
1. **Flutter Mobile Client & Android 14+ Integration** (`com.wizzling.tx_browser`)
2. **Fastify / TypeScript Push API & Transactional Queue Worker** (`backend/`)
3. **PostgreSQL Database with Prisma ORM**
4. **Vite React Admin Console** with Live Android 14+ Notification Preview (`backend/admin/`)

---

## 1. Architecture Overview

```
                      ┌────────────────────────────────────────┐
                      │    Vite React Admin Dashboard (SPA)   │
                      │   - Live Android 14+ Frame Preview     │
                      │   - Topic & Segment Campaign Composer  │
                      └───────────────────┬────────────────────┘
                                          │ Session Cookie / REST
                                          ▼
                      ┌────────────────────────────────────────┐
                      │   Fastify / TypeScript Push Backend    │
                      │   - Argon2id Auth & RBAC               │
                      │   - Device Registry & Heartbeats       │
                      │   - Transactional PostgreSQL Job Queue │
                      │   - Scheduler (Polls every 15s)        │
                      └───────────────┬────────────┬───────────┘
                                      │            │
            Topic Send (tx_all, etc.) │            │ Multicast Chunks (≤ 500 tokens)
                                      ▼            ▼
                      ┌────────────────────────────────────────┐
                      │      Firebase Cloud Messaging (FCM)    │
                      │             HTTP v1 API                │
                      └───────────────────┬────────────────────┘
                                          │ Push Broadcast
                                          ▼
                      ┌────────────────────────────────────────┐
                      │          TX Browser Mobile App         │
                      │  - Non-blocking async FCM init         │
                      │  - Soft contextual permission prompt   │
                      │  - Background & foreground listeners   │
                      │  - Deep Link Router (Strict HTTPS)     │
                      │  - Open tracking & token refresh       │
                      └────────────────────────────────────────┘
```

---

## 2. Firebase Project & Android Client Configuration

### 2.1 Register Android App in Firebase Console
1. Open the [Firebase Console](https://console.firebase.google.com/).
2. Create or select your project (e.g., `tx-browser-production`).
3. Click **Add App** -> **Android**:
   - **Android package name**: `com.wizzling.tx_browser`
   - **App nickname**: `TX Browser`
4. Register the SHA-1 and SHA-256 certificate fingerprints for both Debug and Release keystores:
   ```bash
   # On Windows PowerShell:
   cd android
   ./gradlew signingReport
   ```
5. Download `google-services.json`.

### 2.2 Place `google-services.json`
Place the downloaded file in the Android app directory:
```
tx_browser/android/app/google-services.json
```
*(A placeholder template with the exact package name `com.wizzling.tx_browser` is already configured in the repository).*

### 2.3 Android Notification Channels
TX Browser configures 4 dedicated notification channels matching Android 14+ Material Design 3 guidelines:
- `tx_general` (General Announcements & System Notices)
- `tx_updates` (Browser Version Updates & Engine Upgrades)
- `tx_promotions` (Promotions, Sponsored Perks & Discounts)
- `tx_security` (Critical Security Alerts & Vulnerability Patches)

Users can toggle these channels individually in **Settings > Notifications**, or via Android OS System App Settings.

---

## 3. Backend & PostgreSQL Configuration

### 3.1 Environment Variables
In the `backend/` directory, copy `.env.example` to `.env`:
```bash
cd backend
cp .env.example .env
```

Configure the environment variables:
```env
# Server
PORT=4000
NODE_ENV=production

# Database (PostgreSQL 14+)
DATABASE_URL="postgresql://postgres:YOUR_PASSWORD@localhost:5432/tx_notifications?schema=public"

# Admin Authentication & Session Security (Min 32 random characters)
ADMIN_SESSION_SECRET="generate_a_secure_random_string_of_at_least_32_characters_here"
CORS_ORIGINS="*"

# Firebase Admin Service Account Credentials
FIREBASE_PROJECT_ID="tx-browser"
FIREBASE_CLIENT_EMAIL="firebase-adminsdk@tx-browser.iam.gserviceaccount.com"
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC...\n-----END PRIVATE KEY-----\n"

# Initial Super Admin Seed Credentials
SEED_ADMIN_EMAIL="admin@txbrowser.com"
SEED_ADMIN_PASSWORD="YourStrongInitialAdminPassword123!"
SEED_ADMIN_NAME="TX Super Admin"
```

### 3.2 Obtaining the Firebase Service Account Key
1. In the Firebase Console, navigate to **Project Settings** (gear icon) > **Service accounts**.
2. Click **Generate new private key**.
3. Open the downloaded JSON file:
   - Copy `project_id` into `FIREBASE_PROJECT_ID`.
   - Copy `client_email` into `FIREBASE_CLIENT_EMAIL`.
   - Copy `private_key` into `FIREBASE_PRIVATE_KEY` (ensure `\n` linebreaks are preserved).

### 3.3 Database Migration & Admin Seeding
Run the Prisma migrations and seed the initial Super Admin account:
```bash
cd backend
# Generate Prisma Client
npm run prisma:generate

# Push schema to PostgreSQL database
npm run prisma:push

# Seed the initial Super Admin account (Argon2id hashed)
npm run seed:admin
```

---

## 4. Building & Running the Platform

### 4.1 Production Build (Backend + Admin Console)
The root build script in `backend/` compiles both the TypeScript server and the React Admin Console into an optimized bundle:
```bash
cd backend
npm run build
```
This builds:
- Fastify server -> `backend/dist/src/server.js`
- React Admin Console -> `backend/admin/dist/` (served natively at `/admin/`)

### 4.2 Starting the Production Server
```bash
cd backend
npm start
```
The server will start on port 4000 (or your configured `PORT`):
- **Admin Console**: `http://localhost:4000/admin/`
- **Health Check**: `http://localhost:4000/health`
- **Readiness Check**: `http://localhost:4000/ready`
- **REST APIs**: `http://localhost:4000/api/v1/`

Background workers (`QueueService` and `SchedulerService`) start automatically with graceful shutdown handlers.

### 4.3 Development Mode
Run backend and admin console with hot-reloading:
```bash
# Terminal 1: Backend API dev server (port 4000)
cd backend
npm run dev

# Terminal 2: Admin Dashboard Vite dev server (port 3000, proxies /api to 4000)
cd backend/admin
npm run dev
```

---

## 5. Admin Console Features & Usage

Open `http://localhost:4000/admin/` in any modern browser and log in with your admin credentials.

### 5.1 Campaign Composer (`/composer`)
- **Live Android 14+ Frame Preview**: As you type the title, body, or paste an image URL, the interactive Android phone preview on the right updates reactively.
- **Android Channels**: Select from Promotion, App Update, General, New Feature, Security, or Notice.
- **Destination & Deep Linking**:
  - `Home Screen`: Opens browser start tab.
  - `Web URL`: Strict HTTPS destination link (e.g. `https://txbrowser.com/features`).
  - `Play Store`: Deep links to Google Play store page for TX Browser.
  - `Internal Screen`: Directs to Settings, History, Downloads, Bookmarks, or AdBlock.
- **Audience Targeting**:
  - `All Users`: Broadcasts immediately to all devices subscribed to `tx_all`.
  - `Specific Topic`: Targets `tx_promotions`, `tx_updates`, `tx_security`, or `tx_general`.
  - `Custom Segment`: Queries active devices by version, Android OS, and activity window (chunks tokens into 500-device batches).
- **Safety Confirm Modal**: Shows estimated reach and asks for explicit confirmation before broadcasting.

### 5.2 Device Registry (`/devices`)
Inspect device installations, token states, Android OS versions, and see which topics each device is subscribed to.

### 5.3 Analytics & Delivery Pipeline (`/analytics`)
Tracks 14-day dispatch volume, confirmed tap open rates, failed token classifications, and category distribution.

### 5.4 Audit Logs (`/audit-logs`)
Immutable log of logins, campaign creations, immediate sends, cancellations, and user role updates with IP addresses and user agents.

---

## 6. Mobile Client Verification Checklist

1. **Non-Blocking Startup**:
   - Launching the app does NOT block the UI thread. Notification initialization runs asynchronously.
2. **Soft Contextual Permission**:
   - On the Home screen, after browsing or on return, a Material 3 bottom sheet explains the value of browser updates and promotions before triggering the Android 13+ runtime permission prompt.
3. **Notification Settings**:
   - Navigate to **Settings > Notifications** to test master switch and individual topic toggles (`Promotions & Perks`, `Browser Updates`, `Security Alerts`).
4. **Push Interception & Tap Routing**:
   - With app in **Foreground**: Notification displays with app icon and custom channel sound/vibration.
   - With app in **Background / Terminated**: Tapping notification deep-links directly to the target URL or screen, and pings `/api/v1/devices/notifications/opened` for tracking.
5. **Token Lifecycle**:
   - Token refresh automatically registers with the backend without user intervention.

---

## 7. Security & High-Volume Scaling Guidelines

- **Token Cleanup**: Multicast delivery automatically identifies `messaging/registration-token-not-registered` errors and deactivates expired tokens in PostgreSQL, maintaining pristine list hygiene.
- **Queue Locking**: `QueueService` employs PostgreSQL `FOR UPDATE SKIP LOCKED` so multiple backend worker instances can scale horizontally without duplicate deliveries.
- **Zero-Latency Fanout**: Native FCM topics (`tx_all`, `tx_promotions`, etc.) are leveraged for broad announcements, offloading fan-out compute directly to Google's worldwide edge infrastructure.
- **Strict HTTPS URLs**: All web links and banner images enforce `https://` validation in both frontend Zod schemas and mobile deep-link routers to prevent malicious scheme attacks.
