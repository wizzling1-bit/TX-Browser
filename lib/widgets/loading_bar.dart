import 'package:flutter/material.dart';

import '../core/theme/colors.dart';

/// Thin top progress bar for page loading.
///
/// 2dp height, full-width, brand primary color.
/// Animates via width interpolation (not indeterminate shimmer)
/// since real progress is available from the WebView.
///
/// See DESIGN_SYSTEM.md §5.10.

class LoadingBar extends StatelessWidget {
  const LoadingBar({
    super.key,
    required this.progress,
    this.isVisible = true,
  });

  /// Progress value from 0 to 100.
  final int progress;

  /// Whether the bar should be visible.
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return RepaintBoundary(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isVisible && progress > 0 && progress < 100 ? 1.0 : 0.0,
        child: SizedBox(
          height: 2,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Track
                  Container(
                    height: 2,
                    width: constraints.maxWidth,
                    color: colors.primary.withValues(alpha: 0.15),
                  ),
                  // Fill
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    height: 2,
                    width: constraints.maxWidth * (progress / 100).clamp(0.0, 1.0),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
