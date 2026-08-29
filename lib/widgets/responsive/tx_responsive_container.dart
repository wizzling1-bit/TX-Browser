import 'package:flutter/material.dart';

/// Ergonomic adaptive container for large screens (tablets, foldables, desktop/web).
///
/// Centers its child and applies a maximum width constraint (default: 720dp)
/// to prevent content from stretching awkwardly across ultra-wide viewports.
class TxResponsiveContainer extends StatelessWidget {
  const TxResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    }

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}
