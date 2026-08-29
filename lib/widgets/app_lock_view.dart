import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../core/theme/colors.dart';
import '../core/theme/spacing.dart';
import '../core/theme/shapes.dart';
import 'buttons/tx_pressable.dart';

/// Full-screen or modal PIN keypad for authentication.
class AppLockView extends StatefulWidget {
  const AppLockView({
    super.key,
    required this.title,
    this.subtitle,
    required this.onPinComplete,
    this.onBiometricTap,
    this.showBiometrics = false,
    this.isLockedOut = false,
    this.lockoutSeconds = 0,
    this.isVerification = false,
  });

  final String title;
  final String? subtitle;
  final ValueChanged<String> onPinComplete;
  final VoidCallback? onBiometricTap;
  final bool showBiometrics;
  final bool isLockedOut;
  final int lockoutSeconds;
  final bool isVerification;

  @override
  State<AppLockView> createState() => _AppLockViewState();
}

class _AppLockViewState extends State<AppLockView>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  Timer? _countdownTimer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.lockoutSeconds;
    if (_secondsLeft > 0) {
      _startCountdown();
    }

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        setState(() => _secondsLeft = 0);
        timer.cancel();
      }
    });
  }

  void _handleNumberPress(String number) {
    if (_secondsLeft > 0 || _pin.length >= 4) return;
    HapticFeedback.lightImpact();

    setState(() {
      _pin += number;
    });

    if (_pin.length == 4) {
      widget.onPinComplete(_pin);
      // Clear pin after a brief delay for UI feedback
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() => _pin = '');
        }
      });
    }
  }

  void _handleBackspace() {
    if (_pin.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  /// Trigger shake animation on invalid PIN attempt
  void triggerError() {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0);
    setState(() => _pin = '');
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TxSpacing.xl,
                      vertical: TxSpacing.md,
                    ),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),

                        // Brand Security Icon
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              LucideIcons.shieldCheck,
                              size: 32,
                              color: colors.primary,
                            ),
                          ),
                        ),

                        const SizedBox(height: TxSpacing.lg),

                        // Title
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: TxSpacing.xs),

                        // Subtitle or lockout timer
                        if (_secondsLeft > 0)
                          Text(
                            'Too many failed attempts. Try again in $_secondsLeft seconds.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                            textAlign: TextAlign.center,
                          )
                        else if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colors.textSecondary,
                                ),
                            textAlign: TextAlign.center,
                          ),

                        const SizedBox(height: TxSpacing.xl),

                        // 4-Digit PIN Dots with Error Shake
                        AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(_shakeAnimation.value, 0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(4, (index) {
                                  final isFilled = index < _pin.length;
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 10),
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isFilled ? colors.primary : Colors.transparent,
                                      border: Border.all(
                                        color: isFilled ? colors.primary : colors.border,
                                        width: 2,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            );
                          },
                        ),

                        const Spacer(flex: 3),

                        // Keypad (3x4 Grid)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Column(
                            children: [
                              _buildRow(['1', '2', '3'], colors),
                              const SizedBox(height: 16),
                              _buildRow(['4', '5', '6'], colors),
                              const SizedBox(height: 16),
                              _buildRow(['7', '8', '9'], colors),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Left action: Biometric or empty
                                  if (widget.showBiometrics && widget.onBiometricTap != null)
                                    _KeypadButton(
                                      onTap: widget.onBiometricTap!,
                                      colors: colors,
                                      child: Icon(
                                        LucideIcons.fingerprint,
                                        size: 28,
                                        color: colors.primary,
                                      ),
                                    )
                                  else
                                    const SizedBox(width: 72, height: 72),

                                  // Center: 0
                                  _KeypadButton(
                                    onTap: () => _handleNumberPress('0'),
                                    colors: colors,
                                    child: Text(
                                      '0',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ),

                                  // Right action: Backspace
                                  _KeypadButton(
                                    onTap: _handleBackspace,
                                    colors: colors,
                                    child: Icon(
                                      LucideIcons.delete,
                                      size: 24,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const Spacer(flex: 2),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRow(List<String> numbers, TxColorScheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) {
        return _KeypadButton(
          onTap: () => _handleNumberPress(n),
          colors: colors,
          child: Text(
            n,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    required this.child,
    required this.onTap,
    required this.colors,
  });

  final Widget child;
  final VoidCallback onTap;
  final TxColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return TxPressable(
      onTap: onTap,
      scaleDown: 0.88,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: colors.border.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: TxElevation.elevation1,
        ),
        child: Center(child: child),
      ),
    );
  }
}
