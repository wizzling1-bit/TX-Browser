import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/shapes.dart';
import '../core/theme/spacing.dart';

/// Small colored status pill (Connected / Disconnected / etc.)
///
/// See DESIGN_SYSTEM.md §5.9.

enum StatusPillType { success, idle, error, warning }

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.type,
  });

  final String label;
  final StatusPillType type;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    Color dotColor;
    Color textColor;

    switch (type) {
      case StatusPillType.success:
        dotColor = colors.success;
        textColor = colors.success;
        break;
      case StatusPillType.idle:
        dotColor = colors.textSecondary;
        textColor = colors.textSecondary;
        break;
      case StatusPillType.error:
        dotColor = colors.error;
        textColor = colors.error;
        break;
      case StatusPillType.warning:
        dotColor = colors.warning;
        textColor = colors.warning;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TxSpacing.sm,
        vertical: TxSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: TxRadius.borderRadiusFull,
        border: Border.all(
          color: textColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: TxSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: textColor,
                ),
          ),
        ],
      ),
    );
  }
}
