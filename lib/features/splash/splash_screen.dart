import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../state/acquisition_provider.dart';

/// Premium product splash screen with brand tokens, subtle glow, and fast entrance.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutBack,
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.06).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
      ),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _entranceController.forward();

    // Fast, non-blocking splash duration -> navigate to target website or Home
    _timer = Timer(const Duration(milliseconds: 1350), () {
      if (mounted) {
        final deferred = ref.read(deferredNavigationPayloadProvider);
        if (deferred != null && deferred.targetUrl.isNotEmpty) {
          context.go('/browser', extra: deferred.targetUrl);
        } else {
          context.go('/');
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final isDark = colors.isDark;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background ambient gradient orb
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 360,
                    height: 360,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          colors.primary.withValues(alpha: isDark ? 0.22 : 0.14),
                          colors.primary.withValues(alpha: isDark ? 0.08 : 0.03),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Central Brand Hero
          Center(
            child: AnimatedBuilder(
              animation: _entranceController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Luxury Leaf Brandmark Icon Badge
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colors.primary,
                                colors.secondary,
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(48),
                              topRight: Radius.circular(48),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(48),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: isDark ? 0.45 : 0.28),
                                blurRadius: 32,
                                spreadRadius: 2,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                top: 8,
                                left: 14,
                                child: Container(
                                  width: 24,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const Center(
                                child: Icon(
                                  LucideIcons.leaf,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: TxSpacing.xxl),

                        // Title
                        Text(
                          'TX Browser',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                                letterSpacing: -0.5,
                                fontSize: 26,
                              ),
                        ),

                        const SizedBox(height: TxSpacing.xs),

                        // Tagline
                        Text(
                          ref.watch(deferredNavigationPayloadProvider) != null
                              ? 'Opening requested site...'
                              : 'Premium. Private. Powerful.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colors.textSecondary,
                                letterSpacing: 0.4,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom sleek progress indicator
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 40,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  backgroundColor: colors.primary.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
