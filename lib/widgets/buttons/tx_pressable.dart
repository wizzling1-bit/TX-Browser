import 'package:flutter/material.dart';
import '../../core/theme/motion.dart';

/// A wrapper widget that scales slightly (0.96) on press
/// to provide tactile, responsive micro-interaction feedback.
class TxPressable extends StatefulWidget {
  const TxPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.96,
    this.borderRadius,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;
  final BorderRadius? borderRadius;
  final HitTestBehavior behavior;

  @override
  State<TxPressable> createState() => _TxPressableState();
}

class _TxPressableState extends State<TxPressable> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = TxMotion.duration(context, TxMotion.microDuration);
    final curve = TxMotion.curve(context, TxMotion.microCurve);

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleDown : 1.0,
        duration: duration,
        curve: curve,
        child: widget.child,
      ),
    );
  }
}
