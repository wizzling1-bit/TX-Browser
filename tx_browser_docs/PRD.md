# Tx Browser — Product Requirements Document (PRD)

**Product:** Tx Browser  
**Platform:** Android  
**Framework:** Flutter + Dart  
**Storage:** Drift + SQLite (local-only)  
**Web engine:** `flutter_inappwebview` + Android Chromium WebView  
**State management:** Riverpod  
**Monetization:** Google AdMob  
**Android-native layer:** Kotlin  
**Backend:** None

## 1. Product Vision

Tx Browser is a premium, privacy-conscious Android web browser designed to feel faster, calmer, and more refined than conventional mobile browsers. The core product experience is content-first browsing with a branded new-tab homepage, spatial tab management, controlled monetization, private browsing, local history/download storage, biometric app lock, and an optional built-in network privacy layer.

Tx Browser must feel like a production browser rather than a demo WebView wrapper.

## 2. Product Goals

| Goal | Requirement |
|---|---|
| Fast browsing | Minimize perceived latency and unnecessary UI work |
| Premium UX | Strong hierarchy, spacing, motion, and tactile interactions |
| Local-first privacy | No account, no backend, no cloud browser profile |
| Reliable browser core | Navigation, tabs, downloads, history, private mode |
| Controlled monetization | AdMob with non-invasive placements |
| Safe extensibility | Feature modules isolated so future features do not destabilize browser core |
| Non-coder maintainability | Clear folder ownership, naming conventions, feature configuration files |

## 3. Non-Goals for MVP

The MVP does not include account sync, Firebase, Supabase, server-side history sync, password synchronization, cloud bookmarks, remote browser profiles, desktop clients, browser extensions, or a custom browser engine.

## 4. Target Users

### Primary
- Android users wanting a clean, modern browser.
- Users who prefer a minimal new-tab experience.
- Users who value private/local browsing controls without creating an account.

### Secondary
- Users who want a simple browser with an optional privacy network connection.
- Users who want quick access shortcuts and a visual tab manager.

## 5. MVP Functional Scope

### 5.1 Browser Core
- URL/search bar.
- DuckDuckGo as default search engine.
- URL normalization and search fallback.
- Chromium WebView navigation.
- Back, forward, reload, stop.
- Page progress indicator.
- Share current page.
- External-link handling.
- JavaScript enabled by default for normal browsing.
- Desktop-site mode.
- Error/offline state.

### 5.2 Tabs
- Create tab.
- Select active tab.
- Close tab.
- Close all tabs.
- Tab counter.
- Tab previews/cards.
- Private/incognito tabs.
- Restore regular tabs after app restart.
- Do not persist private tab URLs/history.

### 5.3 New Tab / Home
- Branded hero area.
- Smart search bar.
- Pinned shortcuts.
- Add/edit/delete shortcut.
- Recent visits.
- Empty states.
- Optional home-screen ad placement.

### 5.4 History
- Visit records.
- Search records.
- Open item.
- Delete item.
- Clear all.
- Private sessions excluded.

### 5.5 Downloads
- File download interception.
- Download progress.
- Download state: queued/downloading/completed/failed/canceled.
- Download history.
- Open downloaded file through Android intent.
- Delete local record.

### 5.6 Settings
- Theme: Light/Dark/System.
- Search engine selection.
- Homepage settings.
- Clear browsing data.
- Desktop-site default.
- App lock.
- Network privacy/proxy/VPN settings.
- About.

### 5.7 Ads
- Google Mobile Ads SDK.
- Development test ads only during development.
- Home-screen banner or native placement.
- Carefully controlled interstitials.
- No ad overlay covering webpage content.
- `AdService` abstraction so ad SDK code is isolated.

### 5.8 Built-in VPN / Network Privacy
For MVP architecture, the feature is called **Tx Privacy Connection** and has two implementation modes:

1. **Android VPN mode:** Android `VpnService` for a genuine device-level tunnel.
2. **Proxy mode:** Android/Kotlin proxy configuration where supported by the selected network implementation.

A proxy is not treated as equivalent to a VPN. The UI must clearly state which mode is actually active. The MVP must never claim “VPN protection” when only a browser proxy is in use.

## 6. Key User Flows

### First Launch
```text
Launch
  -> App initialization
  -> Local DB migration
  -> Load settings
  -> Determine theme
  -> Prepare WebView
  -> Home screen
```

### Browse
```text
Home
  -> Enter URL/search
  -> Resolve query
  -> Create/select tab
  -> WebView loads
  -> Progress updates
  -> Navigation events
  -> Persist non-private history
```

### New Tab
```text
Current tab
  -> + New Tab
  -> Create tab model
  -> Show New Tab page
  -> Focus search field
```

### Private Tab
```text
Tab manager
  -> Private mode
  -> Create private tab
  -> Browse
  -> No history persistence
  -> Close private tab
  -> Dispose WebView/session state
```

### Download
```text
WebView download event
  -> Validate request
  -> Kotlin download service
  -> Progress callback
  -> Store local metadata
  -> Completed
  -> Open / delete
```

### App Lock
```text
App launch/resume requiring lock
  -> Lock screen
  -> Android biometric prompt
  -> Success -> browser
  -> Cancel/failure -> remain locked
```

## 7. Product Rules

1. Web content always receives the majority of visual space on the browser screen.
2. Navigation controls must remain reachable with one hand on common Android sizes.
3. Private tabs never contribute to persistent history or recently visited records.
4. Clear browsing data must communicate exactly what is being removed.
5. Ads never visually imitate browser controls.
6. Downloaded files are handled by Android storage/file APIs, not by storing binary blobs in SQLite.
7. UI widgets never access SQLite directly; repositories/services mediate all data access.
8. Android-only capabilities stay behind platform service interfaces.
9. Errors must be user-recoverable and should not leave stale loading states.
10. Any feature that affects privacy must have an explicit state in UI.

## 8. MVP Acceptance Criteria

### Browser
- A user can enter a URL or search phrase and receive a page.
- Back/forward/reload/stop work without closing the tab.
- Loading progress is visible during navigation.
- JavaScript-heavy modern websites render correctly within Android WebView limitations.

### Tabs
- At least 20 open tabs can be managed without obvious UI failure on a representative Android device.
- Closing a tab selects a predictable neighboring tab.
- Restorable regular tabs survive normal app restart.
- Private tabs are never restored as persistent tabs.

### History
- Every successful non-private navigation can create a history item according to deduplication rules.
- User can delete one item or all items.

### Downloads
- Common downloadable files can be downloaded.
- User can see progress and completion state.
- Completed files can be opened through Android.

### Ads
- Test ads work in development.
- Production ad IDs can be supplied by configuration without changing feature code.

### Security
- Private mode does not persist browsing history.
- Sensitive local settings are protected where appropriate.
- WebView external navigation is controlled by policy.

### UX
- Light and dark themes both preserve the specified brand identity.
- Main interactions maintain a 60 FPS target under normal conditions.
- Interactive controls have accessible labels and touch targets.

## 9. Product Metrics

MVP analytics should be minimal and privacy-preserving. Do not introduce behavioral analytics by default. Operational metrics may be considered later, but the baseline product works without a user account or telemetry backend.

Recommended product success measures:
- Startup time perceived as fast.
- Search-to-page success rate.
- Tab creation/close reliability.
- Download completion reliability.
- Crash-free sessions.
- Ad fill/revenue only through approved AdMob reporting.

## 10. Future-Ready Extension Points

Potential post-MVP features may include bookmarks, reader mode, find-in-page, site permissions, password manager, custom DNS, advanced tracking protection, sync, widgets, and richer download management. These are intentionally excluded from MVP acceptance scope but the architecture should not block them.
