# Tx Browser — Technical Architecture Document (TAD)

## 1. Architecture Overview

Tx Browser uses a layered, feature-oriented Flutter architecture with a small Kotlin bridge for Android-specific capabilities.

```text
Flutter UI
   |
Riverpod Controllers / Notifiers
   |
Feature Services / Use Cases
   |
Repositories
   |----------------------|
Drift/SQLite          Platform Interfaces
                         |
                      Kotlin
                         |
            WebView / Downloads / Biometrics
            VPN/Network / Android Intents
```

The core design principle is **Flutter owns product behavior and UI; Kotlin owns Android platform capabilities**.

## 2. Technology Stack

| Layer | Technology | Responsibility |
|---|---|---|
| UI | Flutter + Material 3 | Screens/widgets/themes |
| Language | Dart | Product/application logic |
| Web | `flutter_inappwebview` | WebView lifecycle/navigation |
| Engine | Android Chromium WebView | Page rendering |
| State | Riverpod | Reactive application state |
| Database | Drift + SQLite | Local metadata |
| Secure storage | Android Keystore-backed mechanism | Secrets/security-sensitive preferences |
| Biometrics | Android BiometricPrompt | App lock authentication |
| Native bridge | Kotlin + MethodChannel/EventChannel or plugin abstraction | Android-only APIs |
| Ads | Google Mobile Ads | Monetization |

## 3. Layer Responsibilities

### Presentation
Screens, widgets, animations, theme tokens, accessibility labels.

Presentation code must not perform SQL or invoke Kotlin channels directly.

### State
Riverpod providers, controllers, notifiers, immutable state models, lifecycle coordination.

### Domain/Application
Use-case level logic such as `OpenUrl`, `CreateTab`, `CloseTab`, `ClearHistory`, `StartDownload`, `AuthenticateAppLock`, and `ConnectPrivacyNetwork`.

### Data
Drift tables, DAOs, repositories, migrations, mapping between DB entities and domain models.

### Platform
Interfaces exposed in Dart and implemented through Android/Kotlin.

## 4. Recommended Project Structure

```text
lib/
├── app/
│   ├── app.dart
│   ├── app_router.dart
│   └── app_lifecycle.dart
│
├── core/
│   ├── constants/
│   ├── errors/
│   ├── extensions/
│   ├── logging/
│   ├── routing/
│   ├── utils/
│   └── widgets/
│
├── design_system/
│   ├── tokens/
│   ├── theme/
│   ├── components/
│   └── motion/
│
├── features/
│   ├── home/
│   ├── browser/
│   ├── tabs/
│   ├── history/
│   ├── downloads/
│   ├── settings/
│   ├── private_mode/
│   ├── app_lock/
│   ├── privacy_network/
│   └── ads/
│
├── data/
│   ├── database/
│   ├── repositories/
│   └── models/
│
├── platform/
│   ├── webview/
│   ├── downloads/
│   ├── biometrics/
│   ├── network/
│   └── intents/
│
└── main.dart
```

Android:

```text
android/app/src/main/kotlin/.../
├── MainActivity.kt
├── platform/
│   ├── DownloadBridge.kt
│   ├── BiometricBridge.kt
│   ├── NetworkBridge.kt
│   └── IntentBridge.kt
└── network/
    ├── TxVpnService.kt
    └── ProxyManager.kt
```

## 5. Browser Architecture

Each open tab has a domain model containing:

```text
Tab
- id
- url
- title
- faviconUrl
- isPrivate
- canGoBack
- canGoForward
- isLoading
- progress
- createdAt
- lastActiveAt
```

The WebView instance is owned by the browser feature. `Tab` is metadata, not the WebView itself.

A `TabController` manages tab ordering and active selection. A separate `WebViewControllerRegistry` maps active tab IDs to their runtime WebView controllers when needed.

## 6. URL Resolution

Input resolution algorithm:

```text
Trim input
  -> empty?
     yes: ignore
     no:
  -> looks_like_url?
     yes -> normalize scheme if needed -> navigate
     no  -> encode as search query -> selected search engine -> navigate
```

Do not treat arbitrary strings as hosts. Use a robust URL parser and explicit scheme rules.

## 7. WebView Configuration

Baseline settings:
- JavaScript enabled.
- DOM storage enabled as required by modern websites.
- Media autoplay policy chosen conservatively.
- File access configured narrowly.
- Debugging enabled only in debug builds.
- Mixed content disabled unless a business requirement proves otherwise.
- Third-party navigation and external intents handled through a navigation policy.
- Download events forwarded to download service.

Do not weaken WebView security settings just to make a specific site work without evaluating the tradeoff.

## 8. State Management

Use Riverpod with dependency injection by provider composition.

Recommended providers:

```text
appSettingsProvider
searchEngineProvider
browserTabsProvider
activeTabProvider
historyRepositoryProvider
downloadRepositoryProvider
webViewManagerProvider
adServiceProvider
appLockProvider
privacyNetworkProvider
```

Controllers should expose intent-focused methods rather than raw state mutation.

Example:

```text
BrowserController
  navigate(input)
  goBack()
  goForward()
  reload()
  stop()
  sharePage()
```

## 9. Drift Database

Recommended tables:

### `history_entries`
- `id`
- `url`
- `title`
- `visitedAt`
- `visitType`
- `domain`

### `search_entries`
- `id`
- `query`
- `searchEngine`
- `createdAt`

### `downloads`
- `id`
- `url`
- `fileName`
- `mimeType`
- `localPath`
- `status`
- `bytesReceived`
- `totalBytes`
- `createdAt`
- `completedAt`

### `pinned_shortcuts`
- `id`
- `title`
- `url`
- `position`
- `createdAt`

### `restorable_tabs`
- `id`
- `url`
- `title`
- `position`
- `createdAt`
- `lastActiveAt`

Do not store private-tab records in persistent tables.

## 10. Persistence Rules

Persist:
- Settings.
- Regular tab restoration metadata.
- Regular history/search history.
- Shortcuts.
- Download metadata.

Do not persist:
- Private browsing history.
- Private search history.
- Private tab restoration state.
- WebView cookies explicitly for private mode beyond what Android WebView itself manages in the isolated strategy selected for private sessions.

## 11. Secure Storage

Use Android Keystore-backed secure storage for sensitive configuration values when required. Regular UI settings such as theme choice do not need secure storage.

Never store encryption keys or sensitive authentication artifacts as plain SharedPreferences.

## 12. Native Communication

Prefer typed Dart interfaces:

```dart
abstract interface class BiometricService {
  Future<bool> authenticate();
}
```

The implementation communicates with Kotlin through a narrow platform channel.

Never expose one giant `PlatformService` with dozens of unrelated methods. Keep platform interfaces feature-specific.

## 13. Download Architecture

WebView detects download request.

```text
WebView
 -> Dart DownloadService
 -> Android bridge
 -> Kotlin DownloadManager / controlled downloader
 -> file system
 -> progress events
 -> Drift metadata update
```

Use Android's appropriate download/storage APIs for the target SDK. Do not store large files in SQLite.

## 14. Privacy Network Architecture

Use a single Flutter abstraction:

```text
PrivacyNetworkService
- state
- mode
- connect()
- disconnect()
- getStatus()
```

Native implementation:

```text
Flutter
  -> NetworkBridge
      -> TxVpnService OR ProxyManager
```

A true VPN is implemented using Android `VpnService`. A browser proxy is separate. Product copy must distinguish them.

The network feature must have:
- Explicit connect/disconnect.
- Connection state.
- Failure state.
- Permission/consent state.
- Clear indication of scope: browser-only proxy vs device VPN.

## 15. Ad Architecture

```text
UI
 -> AdSlot widget
 -> AdService interface
 -> AdMob implementation
```

Ad placement identifiers must be configuration values, not hard-coded inside widgets.

Recommended slots:
- `homePrimary`
- `homeSecondary`
- `browserInterstitial`

The app should be able to disable ads in debug builds through an environment/config flag.

## 16. Error Handling

Use typed failures:

```text
NavigationFailure
DownloadFailure
DatabaseFailure
BiometricFailure
NetworkPrivacyFailure
AdFailure
```

UI should convert technical failures into user-facing messages without exposing stack traces.

## 17. Performance Rules

- Keep WebView rebuilds isolated from unrelated widgets.
- Avoid rebuilding the entire browser screen on progress updates.
- Use selectors/listenables for small state slices.
- Lazy-load history and downloads lists.
- Dispose controllers when tabs close.
- Do not run expensive DB operations on the UI isolate unnecessarily.
- Precache key design-system assets only when useful.

## 18. Testing Strategy

### Unit
- URL resolver.
- Search-engine resolver.
- History deduplication.
- Tab selection/close behavior.
- Download state reducer.
- Settings persistence.

### Widget
- Search bar.
- Tab card.
- Empty states.
- Settings rows.
- App lock state.

### Integration
- Open URL.
- Create/close/switch tab.
- Download file.
- Clear history.
- Restart and restore tabs.
- Private tab does not write history.

### Manual Android verification
- Multiple WebView versions/devices.
- Dark mode.
- Rotation/configuration changes where supported.
- Back gesture.
- External link handling.
- File opening.
- Biometric fallback.
- VPN permission flow.

## 19. Definition of Done

A feature is complete when:

1. UI is connected to real state.
2. Persistence is implemented where required.
3. Error states exist.
4. Loading/empty/success states exist.
5. Private-mode rules are enforced.
6. Accessibility labels are present.
7. Tests cover core behavior.
8. No debug-only behavior is shipped unintentionally.
9. Android lifecycle behavior has been tested.
