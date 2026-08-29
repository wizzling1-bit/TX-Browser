import 'package:flutter/material.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../buttons/tx_pressable.dart';

/// Bento card container for the Home screen grid.
///
/// Provides tactile micro-interaction scaling on press, subtle border,
/// and soft brand-tinted elevation.
class BentoCard extends StatelessWidget {
  const BentoCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.isGlass = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isGlass;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return TxPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleDown: 0.95,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: TxRadius.borderRadiusMd,
          border: Border.all(
            color: colors.border.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: TxElevation.elevation1,
        ),
        child: ClipRRect(
          borderRadius: TxRadius.borderRadiusMd,
          child: child,
        ),
      ),
    );
  }
}

/// Shortcut tile used inside the Home bento grid.
class ShortcutTile extends StatelessWidget {
  const ShortcutTile({
    super.key,
    required this.label,
    this.faviconUrl,
    this.onTap,
    this.onLongPress,
  });

  final String label;
  final String? faviconUrl;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return BentoCard(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TxSpacing.sm,
          vertical: TxSpacing.md,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Favicon badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
              child: faviconUrl != null && faviconUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        faviconUrl!,
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackIcon(colors),
                      ),
                    )
                  : _buildFallbackIcon(colors),
            ),
            const SizedBox(height: TxSpacing.sm),
            // Label
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackIcon(TxColorScheme colors) {
    return Center(
      child: Text(
        label.isNotEmpty ? label[0].toUpperCase() : '?',
        style: TextStyle(
          color: colors.primary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// "Add shortcut" tile with a refined + action.
class AddShortcutTile extends StatelessWidget {
  const AddShortcutTile({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return BentoCard(
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.border,
                  width: 1.5,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: Icon(
                LucideIcons.plus,
                size: 20,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: TxSpacing.sm),
            Text(
              'Add',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
