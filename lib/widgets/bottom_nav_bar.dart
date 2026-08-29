import 'package:flutter/material.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../core/theme/colors.dart';
import '../core/theme/shapes.dart';
import '../core/theme/spacing.dart';
import 'glass_surface.dart';
import 'buttons/tx_pressable.dart';

/// Floating bottom navigation dock for the Browser screen.
///
/// Refined pill shape, subtle translucent surface, restrained shadow,
/// compact 48px height, and balanced 5-action toolbar:
/// [ ← Back ] [ → Forward ] [ Home ] [ Tabs Badge ] [ Menu ]
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.canGoBack,
    required this.canGoForward,
    required this.tabCount,
    required this.onBack,
    required this.onForward,
    required this.onHome,
    required this.onTabManager,
    required this.onMenu,
    this.isVisible = true,
  });

  final bool canGoBack;
  final bool canGoForward;
  final int tabCount;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onHome;
  final VoidCallback onTabManager;
  final VoidCallback onMenu;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      offset: isVisible ? Offset.zero : const Offset(0, 1.4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: TxSpacing.md, vertical: 4),
            child: GlassSurface(
              borderRadius: TxRadius.borderRadiusFull,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: TxSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Back
                    _NavButton(
                      icon: LucideIcons.chevronLeft,
                      semanticLabel: 'Back',
                      onPressed: canGoBack ? onBack : null,
                      colors: colors,
                    ),
                    // Forward
                    _NavButton(
                      icon: LucideIcons.chevronRight,
                      semanticLabel: 'Forward',
                      onPressed: canGoForward ? onForward : null,
                      colors: colors,
                    ),
                    // Home
                    _NavButton(
                      icon: LucideIcons.home,
                      semanticLabel: 'Home',
                      onPressed: onHome,
                      colors: colors,
                    ),
                    // Tab counter
                    _TabCounterButton(
                      count: tabCount,
                      onPressed: onTabManager,
                      colors: colors,
                    ),
                    // Menu
                    _NavButton(
                      icon: LucideIcons.menu,
                      semanticLabel: 'Menu',
                      onPressed: onMenu,
                      colors: colors,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    required this.colors,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final TxColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: isEnabled,
      child: TxPressable(
        onTap: onPressed,
        scaleDown: 0.90,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: isEnabled
                  ? colors.textPrimary
                  : colors.textSecondary.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabCounterButton extends StatelessWidget {
  const _TabCounterButton({
    required this.count,
    required this.onPressed,
    required this.colors,
  });

  final int count;
  final VoidCallback onPressed;
  final TxColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final displayCount = count > 99 ? '99+' : count.toString();

    return Semantics(
      label: '$count tabs open',
      button: true,
      child: TxPressable(
        onTap: onPressed,
        scaleDown: 0.90,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: colors.primary, width: 1.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  displayCount,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                        height: 1.0,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
