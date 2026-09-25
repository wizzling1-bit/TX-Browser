import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../state/acquisition_provider.dart';

/// Flagship product splash screen with staggered micro-animations, rotating glow aura,
/// and luxury typography.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _progressController;

  late Animation<double> _badgeScale;
  late Animation<double> _badgeOpacity;
  late Animation<double> _titleSlide;
  late Animation<double> _titleOpacity;
  late Animation<double> _taglineSlide;
  late Animation<double> _taglineOpacity;
  late Animation<double> _badgePillOpacity;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // 1. Staggered Entrance Controller
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // 2. Slow ambient halo rotation
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();

    // 3. Ambient breathing pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // 4. Sleek capsule progress animation
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    // Staggered intervals
    _badgeScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _badgeOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<double>(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.30, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.30, 0.65, curve: Curves.easeOut),
      ),
    );

    _taglineSlide = Tween<double>(begin: 14.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.45, 0.90, curve: Curves.easeOutCubic),
      ),
    );

    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.45, 0.80, curve: Curves.easeOut),
      ),
    );

    _badgePillOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.60, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();

    // Fluid, ultra-fast launch -> route to target URL or Home
    _timer = Timer(const Duration(milliseconds: 1450), () {
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
    _rotationController.dispose();
    _pulseController.dispose();
    _progressController.dispose();
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
          // ─── 1. Dual Ambient Breathing Glow Orbs ─────────────────────────
          Positioned(
            top: MediaQuery.of(context).size.height * 0.22,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final scale = 0.94 + (_pulseController.value * 0.12);
                return Transform.scale(
                  scale: scale,
                  child: Center(
                    child: Container(
                      width: 340,
                      height: 340,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            colors.primary.withValues(alpha: isDark ? 0.24 : 0.16),
                            colors.secondary.withValues(alpha: isDark ? 0.08 : 0.04),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ─── 2. Hero Centerpiece with Rotating Shimmer Halo ──────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Leaf Badge with Rotating Glow Ring
                AnimatedBuilder(
                  animation: Listenable.merge([_badgeScale, _rotationController]),
                  builder: (context, child) {
                    return Opacity(
                      opacity: _badgeOpacity.value,
                      child: Transform.scale(
                        scale: _badgeScale.value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Rotating chromatic gradient halo ring
                            Transform.rotate(
                              angle: _rotationController.value * 2 * math.pi,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(
                                    colors: [
                                      colors.primary.withValues(alpha: 0.60),
                                      colors.secondary.withValues(alpha: 0.10),
                                      colors.primary.withValues(alpha: 0.40),
                                      colors.secondary.withValues(alpha: 0.80),
                                      colors.primary.withValues(alpha: 0.60),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Background blur mask for the halo
                            Container(
                              width: 108,
                              height: 108,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.bg,
                              ),
                            ),

                            // Flagship Leaf Badge
                            Container(
                              width: 92,
                              height: 92,
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
                                  topLeft: Radius.circular(46),
                                  topRight: Radius.circular(46),
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(46),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withValues(alpha: isDark ? 0.45 : 0.28),
                                    blurRadius: 30,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.38),
                                  width: 1.4,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned(
                                    top: 8,
                                    left: 14,
                                    child: Container(
                                      width: 22,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.28),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                  const Center(
                                    child: Icon(
                                      LucideIcons.leaf,
                                      size: 46,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: TxSpacing.xl),

                // Staggered Title: "TX Browser"
                AnimatedBuilder(
                  animation: _titleSlide,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _titleOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _titleSlide.value),
                        child: Text(
                          'TX Browser',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                                letterSpacing: -0.4,
                                fontSize: 27,
                              ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: TxSpacing.xs),

                // Staggered Tagline
                AnimatedBuilder(
                  animation: _taglineSlide,
                  builder: (context, _) {
                    final deferred = ref.watch(deferredNavigationPayloadProvider);
                    final isDeeplink = deferred != null && deferred.targetUrl.isNotEmpty;

                    return Opacity(
                      opacity: _taglineOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _taglineSlide.value),
                        child: Text(
                          isDeeplink ? 'Opening destination...' : 'Premium. Private. Powerful.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colors.textSecondary,
                                letterSpacing: 0.3,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: TxSpacing.lg),

                // Glassmorphism Security Pill Badge
                AnimatedBuilder(
                  animation: _badgePillOpacity,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _badgePillOpacity.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt.withValues(alpha: 0.70),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colors.borderSubtle,
                            width: 0.9,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.shieldCheck,
                              size: 13,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '100% On-Device Sandbox',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ─── 3. Sleek Progress Indicator at Bottom ───────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 36,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
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
