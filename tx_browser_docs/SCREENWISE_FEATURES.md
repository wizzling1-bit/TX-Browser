# Tx Browser — Screenwise Features, Functions, User Flows & Editable Folder Structure

## 1. How to Read This Document

This document maps product behavior to screens and files so a non-coder can understand what each major area does.

Rule of thumb:

```text
Screen = UI
Controller = behavior/state
Service = feature operation
Repository = stored data
Platform = Android-only capability
```

Do not edit database code or Kotlin platform code to change a button label, color, or screen layout. Those belong in the UI/design-system layer.

## 2. Global App Structure

```text
lib/
├── app/                         # Starts and configures the application
├── design_system/               # Brand colors, typography, reusable UI
├── core/                        # Shared helpers and safe utilities
├── features/
│   ├── home/                    # New tab/home screen
│   ├── browser/                 # Main web browsing screen
│   ├── tabs/                    # Tab manager
│   ├── history/                 # Browsing/search history
│   ├── downloads/               # Downloads
│   ├── settings/                # Settings screens
│   ├── private_mode/            # Private-tab behavior
│   ├── app_lock/                # Biometric lock
│   ├── privacy_network/         # VPN/proxy UI and state
│   └── ads/                     # Ad service and ad widgets
├── data/                        # SQLite/Drift data layer
└── platform/                    # Kotlin bridge interfaces
```

## 3. Screen: Home / New Tab

### Purpose
Starting point for browsing.

### UI
- Brand header.
- Smart search bar.
- Shortcut bento grid.
- Add shortcut.
- Recent sites.
- Optional ad slot.
- Tab counter/navigation.

### Functions
| Function | What it does |
|---|---|
| Search | Resolves query and opens page |
| Add shortcut | Opens shortcut editor |
| Edit shortcut | Changes title/URL |
| Delete shortcut | Removes shortcut |
| Open recent | Opens history item in current/new tab according to product rule |
| Open tabs | Opens tab manager |

### Main files
```text
features/home/
├── presentation/home_screen.dart
├── presentation/widgets/shortcut_grid.dart
├── presentation/widgets/recent_section.dart
├── application/home_controller.dart
└── domain/home_models.dart
```

## 4. Screen: Browser

### Purpose
Core web browsing experience.

### UI
- URL/search bar.
- Loading indicator.
- WebView.
- Floating navigation.
- Tab counter.
- More menu.

### Functions
- Enter URL/search.
- Back.
- Forward.
- Reload.
- Stop.
- Share.
- Open external.
- Desktop-site toggle.
- Add shortcut.
- Privacy connection state.

### Screen states
```text
Idle -> Loading -> Loaded
             -> Error
             -> Offline/error recovery
```

### Main files
```text
features/browser/
├── presentation/browser_screen.dart
├── presentation/widgets/browser_toolbar.dart
├── presentation/widgets/browser_webview.dart
├── presentation/widgets/browser_bottom_bar.dart
├── application/browser_controller.dart
├── domain/tab_runtime_state.dart
└── data/webview_manager.dart
```

## 5. Screen: Tab Manager

### Purpose
See, switch, close, and create tabs.

### UI
- Regular/private mode selector where used.
- Tab cards.
- New tab button.
- Close all.
- Context actions.

### Functions
- Switch tab.
- Close tab.
- Close all.
- Create regular tab.
- Create private tab.

### Rules
- Closing active tab chooses the nearest valid tab.
- Closing last regular tab returns to new-tab state.
- Private tab data is excluded from persistent restore.

### Main files
```text
features/tabs/
├── presentation/tab_manager_screen.dart
├── presentation/widgets/tab_card.dart
├── presentation/widgets/tab_grid.dart
├── application/tabs_controller.dart
└── domain/tab.dart
```

## 6. Screen: History

### Purpose
Review and manage previously visited pages.

### Functions
- Open history item.
- Delete item.
- Clear all.
- Search/filter if included in MVP implementation.

### Main files
```text
features/history/
├── presentation/history_screen.dart
├── presentation/widgets/history_item.dart
├── application/history_controller.dart
└── domain/history_item.dart
```

## 7. Screen: Downloads

### Purpose
Track downloaded files.

### Functions
- Observe progress.
- Open completed file.
- Delete record.
- Retry failed downloads where supported.

### States
```text
Queued
Downloading
Completed
Failed
Canceled
```

### Main files
```text
features/downloads/
├── presentation/downloads_screen.dart
├── presentation/widgets/download_item.dart
├── application/downloads_controller.dart
├── domain/download_item.dart
└── data/download_repository.dart
```

## 8. Screen: Settings

### Groups

### Appearance
- Light/Dark/System.

### Search
- Default search engine.

### Homepage
- Home page behavior/settings.

### Browsing
- Desktop-site default.
- Clear browsing data.

### Privacy & Security
- App lock.
- Privacy connection.

### About
- App version.
- Credits/legal links.

### Main files
```text
features/settings/
├── presentation/settings_screen.dart
├── presentation/appearance_screen.dart
├── presentation/search_settings_screen.dart
├── presentation/homepage_settings_screen.dart
├── presentation/privacy_settings_screen.dart
├── application/settings_controller.dart
└── domain/app_settings.dart
```

## 9. Screen: App Lock

### Purpose
Protect browser UI from casual local access.

### User flow
```text
Open app
 -> Lock required?
 -> yes
 -> Tx lock screen
 -> biometric prompt
 -> success -> browser
```

### Main files
```text
features/app_lock/
├── presentation/lock_screen.dart
├── application/app_lock_controller.dart
├── domain/app_lock_state.dart
└── data/app_lock_repository.dart
```

Platform implementation:
```text
platform/biometrics/
├── biometric_service.dart
└── biometric_channel.dart
```

## 10. Screen: Privacy Connection

### Purpose
Control the network privacy feature and expose accurate connection status.

### UI
- Large status indicator.
- Connection type.
- Connect/disconnect button.
- Explanation of scope.
- Error/permission state.

### Main files
```text
features/privacy_network/
├── presentation/privacy_connection_screen.dart
├── presentation/widgets/connection_status.dart
├── application/privacy_network_controller.dart
├── domain/privacy_network_state.dart
└── data/privacy_network_service.dart
```

Android:
```text
android/.../network/
├── TxVpnService.kt
└── ProxyManager.kt
```

## 11. Screen: About

### Content
- Tx Browser name/logo.
- Version/build.
- Open-source notices where applicable.
- Privacy policy link if shipped.
- Terms/legal links if applicable.

Keep this screen simple.

## 12. Reusable UI Components

```text
TxSearchBar
TxSurfaceCard
TxShortcutCard
TxTabCard
TxHistoryItem
TxDownloadItem
TxEmptyState
TxErrorState
TxConfirmDialog
TxBottomSheet
TxPrivacyBadge
TxConnectionStatus
TxAdSlot
```

These live in the design system and should be reused across screens.

## 13. User Flow: Open a Website

```text
Home
 -> Search field
 -> User enters text
 -> BrowserController.navigate()
 -> URL resolver
 -> Active tab selected/created
 -> WebView navigates
 -> WebView callbacks
 -> UI progress update
 -> Successful navigation
 -> History service persists if non-private
```

## 14. User Flow: Create Shortcut

```text
Home
 -> + Shortcut
 -> Bottom sheet
 -> Title + URL
 -> Validate URL
 -> Save via repository
 -> Refresh shortcut grid
```

Validation rules:
- URL cannot be blank.
- Normalize URL.
- Reject unsupported schemes.

## 15. User Flow: Clear Browsing Data

```text
Settings
 -> Clear browsing data
 -> Confirmation dialog
 -> Select categories
 -> Delete records
 -> Clear relevant WebView data
 -> Success message
```

The confirmation must tell the user whether history, searches, cookies/site data, and downloads are affected. Do not imply that every category is cleared unless it truly is.

## 16. User Flow: Download

```text
Web page
 -> Download request
 -> Browser download callback
 -> DownloadService
 -> Android bridge
 -> Download manager
 -> Progress events
 -> Database metadata update
 -> Completed
```

## 17. User Flow: Private Tab

```text
Tab manager
 -> Private
 -> New private tab
 -> Browse
 -> In-memory/private WebView state
 -> No history writes
 -> Close private tab
 -> Dispose state
```

Add tests that fail if a private page reaches the history repository.

## 18. User Flow: App Restart

```text
App closed
 -> Save regular tab metadata
 -> Process ends
 -> Relaunch
 -> Load saved tab metadata
 -> Restore regular tabs
 -> Open active tab
```

Private tabs are excluded.

## 19. Safe Editing Guide for Non-Coders

### To change brand colors
Edit:
```text
lib/design_system/tokens/colors.dart
```

### To change spacing/radius
Edit:
```text
lib/design_system/tokens/spacing.dart
lib/design_system/tokens/radius.dart
```

### To change home layout
Edit:
```text
lib/features/home/presentation/
```

### To change browser toolbar layout
Edit:
```text
lib/features/browser/presentation/widgets/browser_toolbar.dart
```

### To change settings labels/options
Edit:
```text
lib/features/settings/presentation/
lib/features/settings/domain/
```

### To change ad placement configuration
Edit:
```text
lib/features/ads/
```

Do not manually edit SQLite schema unless a database migration is also implemented.

Do not modify Kotlin network/biometric code unless the change is explicitly Android-platform related.

## 20. Feature Ownership Map

| Product area | Primary folder | Native code? | DB? |
|---|---|---:|---:|
| Home | `features/home` | No | Yes |
| Browser | `features/browser` | WebView integration | Sometimes |
| Tabs | `features/tabs` | No | Yes |
| History | `features/history` | No | Yes |
| Downloads | `features/downloads` | Yes | Yes |
| Settings | `features/settings` | Sometimes | Yes |
| App Lock | `features/app_lock` | Yes | Optional |
| Privacy Connection | `features/privacy_network` | Yes | Optional |
| Ads | `features/ads` | SDK integration | No |

## 21. Definition of Done Per Screen

Every screen must include:

- [ ] Main success state.
- [ ] Loading state.
- [ ] Empty state where applicable.
- [ ] Error state where applicable.
- [ ] Dark and light theme support.
- [ ] Accessibility semantics.
- [ ] Keyboard/back behavior.
- [ ] Safe-area handling.
- [ ] No direct database access from widgets.
- [ ] No hard-coded theme colors.
- [ ] UI tests for important interactions.

## 22. AI Coding IDE Rules

When an AI coding IDE modifies Tx Browser:

1. Read the relevant feature folder before editing.
2. Reuse existing design-system components before creating new ones.
3. Do not introduce another state-management library.
4. Do not introduce a backend service.
5. Do not add Firebase/Supabase unless the product scope is intentionally changed.
6. Do not duplicate database access logic.
7. Keep Android-only code in Kotlin/platform folders.
8. Add/modify Drift migrations whenever a schema changes.
9. Preserve private-mode persistence rules.
10. Preserve the exact semantic color tokens.
11. Avoid large architectural rewrites for small UI changes.
12. Keep each feature independently testable.

## 23. Final Project Tree

```text
TX_BROWSER/
├── android/
│   └── app/src/main/kotlin/.../
│       ├── MainActivity.kt
│       ├── network/
│       │   ├── TxVpnService.kt
│       │   └── ProxyManager.kt
│       └── platform/
│           ├── DownloadBridge.kt
│           ├── BiometricBridge.kt
│           ├── NetworkBridge.kt
│           └── IntentBridge.kt
│
├── lib/
│   ├── main.dart
│   ├── app/
│   ├── core/
│   ├── design_system/
│   ├── data/
│   ├── platform/
│   └── features/
│       ├── home/
│       ├── browser/
│       ├── tabs/
│       ├── history/
│       ├── downloads/
│       ├── settings/
│       ├── private_mode/
│       ├── app_lock/
│       ├── privacy_network/
│       └── ads/
│
├── test/
├── integration_test/
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

This structure is the canonical MVP structure for Tx Browser. Add new modules only when there is a clear product feature boundary.
