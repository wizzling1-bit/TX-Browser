import 'package:flutter/material.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../core/theme/colors.dart';
import '../core/theme/shapes.dart';
import '../core/theme/spacing.dart';
import 'buttons/tx_pressable.dart';

/// Grouped settings section with uppercase eyebrow header.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return Padding(
      padding: const EdgeInsets.only(
        left: TxSpacing.lg,
        right: TxSpacing.lg,
        top: TxSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: TxSpacing.sm),
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: TxRadius.borderRadiusMd,
              border: Border.all(
                color: colors.border,
                width: 1,
              ),
              boxShadow: TxElevation.elevation1,
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(
                      color: colors.borderSubtle,
                      height: 1,
                      indent: 52,
                      endIndent: 12,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings row with icon, title, subtitle, value chip, and action.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
    this.statusColor,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final itemColor = isDestructive ? colors.error : colors.textPrimary;

    return TxPressable(
      onTap: onTap,
      scaleDown: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TxSpacing.md,
          vertical: 14,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? colors.error.withValues(alpha: 0.1)
                      : colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 18,
                    color: isDestructive ? colors.error : colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: TxSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: itemColor,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (value != null) ...[
              Text(
                value!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: statusColor ?? colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: colors.textTertiary,
                ),
              ],
            ] else if (onTap != null)
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: colors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
