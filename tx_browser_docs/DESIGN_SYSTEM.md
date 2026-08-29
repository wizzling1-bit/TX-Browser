# Tx Browser — Complete Design System

## 1. Design System Purpose

The Tx Browser design system converts the brand direction into reusable Flutter tokens and components. Screens should be assembled from these primitives rather than styling each screen independently.

## 2. Color Tokens

### Brand
```dart
brandCream = #EDF1D6
brandSage = #9DC08B
brandGreen = #609966
brandForest = #40513B
```

### Light semantic tokens
```text
color.background = #EDF1D6
color.surface = #F7F8EB
color.primary = #609966
color.secondary = #9DC08B
color.textPrimary = #40513B
color.textSecondary = #60705A
color.border = #D5DEC5
```

### Dark semantic tokens
```text
color.background = #1B2419
color.surface = #263323
color.primary = #9DC08B
color.secondary = #609966
color.textPrimary = #EDF1D6
color.textSecondary = #C8D3BD
color.border = #40513B
```

All app widgets consume semantic tokens rather than raw hex values.

## 3. Theme Architecture

Recommended Dart pattern:

```text
DesignTokens
  -> LightTheme
  -> DarkTheme
  -> ThemeData
```

Keep `ThemeData` generation in one place.

## 4. Typography Tokens

```text
display
headlineLarge
headlineMedium
headlineSmall
bodyLarge
bodyMedium
bodySmall
labelLarge
labelMedium
labelSmall
```

Each token defines family, size, weight, line height, and letter spacing.

## 5. Elevation

Use named elevations:

```text
none
subtle
card
floating
modal
```

Do not assign arbitrary elevations in individual widgets.

## 6. Radius Tokens

```text
radius.xs = 8
radius.sm = 12
radius.md = 16
radius.lg = 22
radius.xl = 28
radius.pill = 999
```

## 7. Spacing Tokens

```text
space.1 = 4
space.2 = 8
space.3 = 12
space.4 = 16
space.5 = 20
space.6 = 24
space.8 = 32
space.10 = 40
space.12 = 48
```

## 8. Component Inventory

### Navigation
- `TxTopBar`
- `TxBrowserToolbar`
- `TxBottomNav`
- `TxTabCounter`

### Inputs
- `TxSearchBar`
- `TxTextField`
- `TxSwitch`
- `TxSegmentedControl`

### Cards
- `TxSurfaceCard`
- `TxShortcutCard`
- `TxTabCard`
- `TxHistoryCard`
- `TxDownloadCard`

### Feedback
- `TxProgressBar`
- `TxLoadingState`
- `TxEmptyState`
- `TxErrorState`
- `TxToast`

### Overlays
- `TxBottomSheet`
- `TxConfirmDialog`
- `TxContextMenu`

### Security/privacy
- `TxLockPanel`
- `TxConnectionStatus`
- `TxPrivacyBadge`

### Ads
- `TxAdSlot`

## 9. Search Bar Specification

Properties:

```text
text
hint
leadingIcon
trailingAction
isLoading
isFocused
privateMode
onSubmitted
onChanged
```

Visual requirements:
- Large comfortable hit area.
- Strong focus state.
- Clear distinction between URL/query text and controls.
- Light/dark variants generated from theme tokens.

## 10. Tab Card Specification

States:
- Default.
- Active.
- Private.
- Closing.
- Loading.

Active state should use structural contrast rather than aggressive decoration.

## 11. Buttons

Types:

```text
Primary
Secondary
Tertiary
Destructive
Icon
Floating
```

### Rules
- Primary = main task.
- Secondary = alternative task.
- Destructive = irreversible/removal action.
- Icon buttons always need accessible labels.

## 12. Icons

Use one coherent icon family. Do not mix unrelated icon visual styles.

Icon size tokens:

```text
small 18
standard 22
large 28
hero 36+
```

## 13. Dividers and Borders

Use the semantic `border` token. Avoid heavy outlines. Borders should clarify structure, not compete with content.

## 14. Frosted Glass Rules

Frosted glass components must:
- Maintain readable text contrast.
- Avoid stacking multiple translucent layers.
- Have a solid/opaque fallback if blur is unavailable or too expensive.
- Be used primarily for floating navigation, selected overlays, and premium hero elements.

## 15. Motion Tokens

```text
motion.fast = ~120ms
motion.standard = ~200ms
motion.slow = ~320ms
motion.spatial = ~360ms
```

Curves:
- Standard ease for opacity.
- Spring for spatial card movement.
- Emphasized deceleration for screen entry.

## 16. State Tokens

Every reusable component should define visual states for:

```text
rest
hover/pressed where applicable
focused
selected
disabled
loading
error
success
```

Android touch interactions should rely on Material/Flutter interaction states rather than custom one-off gesture effects.

## 17. Accessibility Tokens

Define:
- Minimum semantic hit area.
- Focus indication.
- Contrast thresholds.
- Text scaling behavior.

Every component requiring user action must expose a semantic label.

## 18. Component API Design

Keep component APIs simple and composable.

Bad:
```text
TxCard(color, borderColor, radius, padding, mode, dark, specialShadow, ...)
```

Better:
```text
TxSurfaceCard(
  variant: TxCardVariant.floating,
  child: ...,
)
```

The design system owns styling decisions.

## 19. File Structure

```text
lib/design_system/
├── tokens/
│   ├── colors.dart
│   ├── spacing.dart
│   ├── radius.dart
│   ├── typography.dart
│   ├── elevation.dart
│   └── motion.dart
├── theme/
│   ├── light_theme.dart
│   ├── dark_theme.dart
│   └── app_theme.dart
├── components/
│   ├── navigation/
│   ├── inputs/
│   ├── cards/
│   ├── feedback/
│   ├── overlays/
│   ├── privacy/
│   └── ads/
└── motion/
    └── motion_helpers.dart
```

## 20. Design QA Checklist

- [ ] Uses design tokens.
- [ ] Both themes tested.
- [ ] Text scales without clipping.
- [ ] Touch targets are accessible.
- [ ] Active/pressed/disabled states exist.
- [ ] Empty/error/loading states exist.
- [ ] No accidental raw brand hex values outside token files.
- [ ] Motion does not block critical actions.
- [ ] Frosted glass has readable fallback.
