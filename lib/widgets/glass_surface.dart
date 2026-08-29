import 'dart:ui';
import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/shapes.dart';

/// Frosted-glass container widget.
///
/// Used for the address bar and bottom navigation bar.
/// Not overused elsewhere — glass is a floating-chrome signal,
/// not a default surface treatment (DESIGN_SYSTEM.md §4).

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.sigma = 12,
    this.opacity,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double sigma;
  final double? opacity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final radius = borderRadius ?? TxRadius.borderRadiusLg;

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: colors.glassSurface,
            borderRadius: radius,
            border: Border.all(
              color: colors.glassBorder,
              width: 1,
            ),
            boxShadow: TxElevation.elevation2,
          ),
          child: child,
        ),
      ),
    );
  }
}
