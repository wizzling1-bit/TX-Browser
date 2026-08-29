# Tx Browser — Complete UI/UX Document

## 1. Design Direction

**World-class premium mobile browser UI/UX**
+
Modern minimalist design + spatial interface + subtle frosted glass + layered depth + Arc-inspired browsing experience + Apple-level motion detail + Linear-level information hierarchy + premium dark mode + sophisticated neutral palette + one distinctive green accent + floating navigation + smart search + bento new-tab page + card-based tabs + meaningful micro-interactions + spring transitions + context-aware motion + accessibility-first design + content-first browser layout + strategic whitespace + fast perceived performance + 60 FPS target + responsive Android layouts + pixel-precise spacing + production-ready design system.

Do not copy proprietary visual assets or exact layouts from other browsers. Use the listed references only as directional quality references.

## 2. Brand Palette

### Brand Colors

| Token | Hex | Purpose |
|---|---|---|
| Brand Cream | `#EDF1D6` | Light background, high-emphasis surfaces |
| Brand Sage | `#9DC08B` | Secondary accents/surfaces |
| Brand Green | `#609966` | Primary action/accent |
| Brand Forest | `#40513B` | Dark text, dark structural color |

### Light Theme

```text
Background  #EDF1D6
Surface     #F7F8EB
Primary     #609966
Secondary   #9DC08B
Text        #40513B
Secondary   #60705A
Border      #D5DEC5
```

### Dark Theme

```text
Background  #1B2419
Surface     #263323
Primary     #9DC08B
Secondary   #609966
Text        #EDF1D6
Secondary   #C8D3BD
Border      #40513B
```

Use semantic tokens so individual screens never hard-code theme colors.

## 3. Visual Language

### Surfaces
Use a restrained layered-surface system:
- Base background.
- Elevated surface.
- Floating card.
- Modal/sheet surface.

Frosted glass is an accent, not the default for every component. Excessive translucency harms readability and performance.

### Corners
Recommended radius system:

```text
XS  8
SM  12
MD  16
LG  22
XL  28
Pill 999
```

### Shadows
Use low-contrast, low-opacity elevation. Shadows should separate layers rather than look decorative.

## 4. Typography

Use a highly legible modern sans-serif available reliably on Android or bundled/licensed for the product.

Suggested semantic scale:

| Token | Size | Weight | Use |
|---|---:|---|---|
| Display | 32 | 700 | Hero/title |
| H1 | 24 | 700 | Major screen heading |
| H2 | 20 | 700 | Section heading |
| Body | 16 | 400/500 | Main content |
| Body Small | 14 | 400/500 | Supporting content |
| Caption | 12 | 500 | Metadata |
| Button | 14 | 600 | Actions |

Maintain predictable line-height and avoid compressed text blocks.

## 5. Spacing System

Base unit: 4 px.

```text
4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48
```

Prefer consistent rhythm over per-screen arbitrary values.

## 6. Home / New Tab UX

### Layout

```text
┌─────────────────────────────┐
│ Tx Browser          [menu]  │
│                             │
│      Welcome / Brand        │
│                             │
│  ┌───────────────────────┐  │
│  │ 🔎 Search or enter... │  │
│  └───────────────────────┘  │
│                             │
│ ┌──────┐ ┌──────┐ ┌──────┐ │
│ │ Site │ │ Site │ │  +   │ │
│ └──────┘ └──────┘ └──────┘ │
│                             │
│ Recent                     │
│ ┌─────────────────────────┐ │
│ │ title             time  │ │
│ └─────────────────────────┘ │
│                             │
│          [tabs] [menu]      │
└─────────────────────────────┘
```

### Behavior
- Search field receives focus when appropriate.
- Shortcut cards support long-press contextual actions.
- Add shortcut uses a bottom sheet.
- Empty recent state explains how to begin browsing.
- Home ad appears in a designated content region, never over controls.

## 7. Browser Screen UX

### Principles
- Web content dominates.
- Navigation controls float visually above the page without obscuring important content.
- URL/search field is readable, compact, and stateful.
- Loading state is obvious but quiet.

### Browser chrome states

```text
Idle
Loading
Loaded
Error
Offline
Private
```

The chrome changes minimally between states to preserve spatial stability.

## 8. Browser Navigation

Primary actions:
- Back.
- Forward.
- Reload/Stop.
- Tab count.
- More menu.

Secondary actions through the more menu:
- Share.
- Add shortcut.
- Open externally.
- Desktop site.
- Privacy/network status.
- Page actions as implemented in MVP.

## 9. Search Bar UX

The search field should accept both URL and query input.

States:
- Idle.
- Focused.
- Editing.
- Loading.
- Error.

When focused:
- Preserve the current URL as selectable content.
- Provide clear button when text exists.
- Keyboard action should submit.
- Do not animate the entire screen unnecessarily.

## 10. Tab Manager

### Visual Language
- Spatial card layout.
- Layered depth.
- Large, readable page titles.
- Favicon where available.
- Clear active/private states.

### Card Anatomy
```text
┌───────────────────────┐
│ favicon     [•••]     │
│ Page title             │
│ domain                 │
│                       X│
└───────────────────────┘
```

### Gestures
- Tap = activate.
- Swipe card = close, only if discoverable and undo is possible.
- Long press = contextual actions.
- Add button = new tab.

### Empty tabs
Show branded empty state with one clear “Open new tab” action.

## 11. History

Use a clean chronological list.

Each item:
- Favicon/icon.
- Page title.
- Domain.
- Time/date.
- Swipe or overflow delete action.

Group by Today / Yesterday / Earlier when useful.

## 12. Downloads

Each item shows:
- File name.
- Size/progress.
- Status.
- Source domain.
- Open action when complete.
- Delete record action.

Use progress indicators during active downloads and avoid making each row visually noisy.

## 13. Settings

Information architecture:

```text
Settings
├── Appearance
├── Search
├── Homepage
├── Browsing
├── Privacy & Security
├── App Lock
├── Privacy Connection
├── Downloads
└── About
```

Use grouped cards/sections with clear descriptions. Avoid deeply nested settings for simple controls.

## 14. App Lock UX

The lock screen should feel trustworthy rather than alarming.

```text
          Tx Browser

       Welcome back

    [ biometric icon ]

       Unlock browser
```

Show a clear fallback message if biometric authentication is unavailable.

## 15. Privacy Connection UX

### States

```text
Disconnected
Connecting
Connected
Disconnecting
Error
Permission required
```

Use a single primary action.

Connected state must show:
- Connection type.
- Status.
- Disconnect action.

Do not display fake technical values that are not actually measured.

## 16. Ads UX

Ads must follow the surrounding visual system without becoming visually deceptive.

Rules:
- Never place ads where users expect navigation controls.
- Never place interstitials immediately after every click.
- Do not interrupt critical browser actions.
- Mark ad areas clearly enough to avoid confusion.

## 17. Motion Design

Motion is functional and should communicate cause/effect.

Recommended motion categories:

| Motion | Duration |
|---|---:|
| Micro feedback | 100–160 ms |
| Card state | 160–220 ms |
| Sheet enter/exit | 220–320 ms |
| Major navigation | 280–420 ms |

Use spring curves for spatial movement and standard ease curves for opacity/state changes.

Respect Android “reduce motion” or accessibility preferences where practical.

## 18. Accessibility

- Minimum touch target should be appropriate for Android accessibility guidelines.
- Do not communicate state using color alone.
- Provide semantics labels.
- Maintain readable contrast in both themes.
- Ensure dialogs and sheets have logical focus order.
- Support large text settings without clipping.

## 19. Responsive Rules

Adapt layouts by available width, not by arbitrary device model names.

Small phones:
- Compact tab controls.
- Single-column home.

Larger phones/tablet-like widths:
- Wider search field.
- Multi-column shortcut grid.
- Larger tab cards or split layouts where practical.

## 20. UI State Matrix

Every major screen must define:

```text
Loading
Success
Empty
Error
Disabled
Refreshing
Private (where applicable)
```

No production screen should rely on an unhandled blank state.
