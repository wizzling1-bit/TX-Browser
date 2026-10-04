import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/tx_icons.dart';
import '../../state/acquisition_provider.dart';
import '../../state/initialization_provider.dart';

/// Production-ready, minimal premium splash screen for TX Browser.
///
/// Design tenets:
/// - 70-80% clean negative space, 15-20% branding, 5-10% loading/status.
/// - Authentic TX Browser brand identity with official logo asset.
/// - Deep charcoal/near-black in dark mode (#121212), warm off-white in light mode (#F2F5E8).
/// - Restrained micro-transitions (250-500ms), zero bouncing, zero visual clutter.
/// - Reduced-motion compliant, WCAG AA contrast conscious.
/// - Never blocks startup: waits only for actual bootstrap, with safety timeout fallback.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // ─── Micro-Motion Animation Controllers ─────────────────────────────
  late AnimationController _entranceController;
  late AnimationController _pulseController;
  late AnimationController _exitController;

  // ─── Micro-Transitions ──────────────────────────────────────────────
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _glowOpacity;
  late Animation<double> _titleOpacity;
  late Animation<double> _taglineOpacity;
  late Animation<double> _loaderOpacity;
  late Animation<double> _screenExitOpacity;
  late Animation<double> _pulseGlowScale;
  late Animation<double> _pulseGlowOpacity;

  // ─── Lifecycle & State Guards ───────────────────────────────────────
  Timer? _minDisplayTimer;
  Timer? _safetyTimeoutTimer;
  bool _minDisplayElapsed = false;
  bool _isExiting = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _setupAnimationTimeline();

    // Start entrance animation immediately, then begin gentle ambient breathing
    _entranceController.forward().then((_) {
      if (mounted) {
        _pulseController.repeat(reverse: true);
      }
    });

    // Golden-ratio minimum display time (1900ms):
    // Allows background tasks (DB queries, tab restoration, native services, shield rules)
    // to warm up completely so that the user lands on a lag-free 60/120fps browser surface.
    _minDisplayTimer = Timer(const Duration(milliseconds: 1900), () {
      if (mounted) {
        _minDisplayElapsed = true;
        _evaluateNavigationReadiness();
      }
    });

    // Safety timeout: Under no condition (slow disk/storage lock) keep user stuck
    _safetyTimeoutTimer = Timer(const Duration(milliseconds: 4000), () {
      if (mounted && !_hasNavigated) {
        _triggerExitAndNavigate();
      }
    });
  }

  void _setupAnimationTimeline() {
    // 1. Logo soft fade and scale (94% -> 100%)
    _logoScale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.48, curve: Curves.easeOutCubic),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.38, curve: Curves.easeOut),
      ),
    );

    // 2. Subtle radial green glow behind logo
    _glowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.12, 0.60, curve: Curves.easeOut),
      ),
    );

    // 3. Brand name fade in
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.70, curve: Curves.easeOut),
      ),
    );

    // 4. Tagline fade in
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 0.85, curve: Curves.easeOut),
      ),
    );

    // 5. Minimal loading indicator & status text
    _loaderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
    );

    // Exit transition (fade out to seamless Home screen)
    _screenExitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Gentle breathing pulse animations for the ambient aura
    _pulseGlowScale = Tween<double>(begin: 0.95, end: 1.06).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    _pulseGlowOpacity = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _evaluateNavigationReadiness() {
    if (!mounted || _isExiting || _hasNavigated) return;

    final isInitialized = ref.read(appInitializedProvider);
    if (isInitialized && _minDisplayElapsed) {
      _triggerExitAndNavigate();
    }
  }

  void _triggerExitAndNavigate() {
    if (!mounted || _isExiting || _hasNavigated) return;
    _isExiting = true;

    // Check reduced motion
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) {
      _executeNavigation();
      return;
    }

    _exitController.forward().then((_) {
      _executeNavigation();
    });
  }

  void _executeNavigation() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;

    try {
      final location = GoRouterState.of(context).uri.toString();
      if (location != '/splash') return;

      final deferred = ref.read(deferredNavigationPayloadProvider);
      if (deferred != null && deferred.targetUrl.isNotEmpty) {
        context.go('/browser?url=${Uri.encodeComponent(deferred.targetUrl)}', extra: deferred.targetUrl);
      } else {
        context.go('/');
      }
    } catch (_) {
      // In isolated tests without GoRouter in context, fallback safely
      Navigator.maybeOf(context)?.pushReplacementNamed('/');
    }
  }

  @override
  void dispose() {
    _minDisplayTimer?.cancel();
    _safetyTimeoutTimer?.cancel();
    _entranceController.dispose();
    _pulseController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final isDark = colors.isDark;
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final isAppReady = ref.watch(appInitializedProvider);

    // Listen to Riverpod initialization completion to smoothly trigger navigation
    ref.listen<bool>(appInitializedProvider, (previous, next) {
      if (next == true) {
        _evaluateNavigationReadiness();
      }
    });

    return Scaffold(
      backgroundColor: colors.bg,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _entranceController,
          _pulseController,
          _exitController,
        ]),
        builder: (context, _) {
          final exitOpacity = disableAnimations ? 1.0 : _screenExitOpacity.value;
          final logoScaleVal = disableAnimations ? 1.0 : _logoScale.value;
          final logoOpacityVal = disableAnimations ? 1.0 : _logoOpacity.value;
          final glowOpacityVal = disableAnimations ? 1.0 : _glowOpacity.value;
          final pulseScaleVal = disableAnimations ? 1.0 : _pulseGlowScale.value;
          final pulseOpacityVal = disableAnimations ? 1.0 : _pulseGlowOpacity.value;
          final titleOpacityVal = disableAnimations ? 1.0 : _titleOpacity.value;
          final taglineOpacityVal = disableAnimations ? 1.0 : _taglineOpacity.value;
          final loaderOpacityVal = disableAnimations ? 1.0 : _loaderOpacity.value;

          return Opacity(
            opacity: exitOpacity.clamp(0.0, 1.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Layer 1: Barely perceptible ambient gradient depth ─────────
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SubtleAmbientDepthPainter(
                      accentColor: colors.primary,
                      isDark: isDark,
                    ),
                  ),
                ),

                // ── Layer 2: Main Layout (Centered Brand + Bottom Status) ──────
                SafeArea(
                  child: Column(
                    children: [
                      // Top negative space (balances centered visual weight)
                      const Spacer(flex: 3),

                      // Center Hero Branding
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. TX Browser Logo with Soft Ambient Glow & Subtle Breathing
                          Transform.scale(
                            scale: logoScaleVal,
                            child: Opacity(
                              opacity: logoOpacityVal,
                              child: _BrandLogoHero(
                                colors: colors,
                                isDark: isDark,
                                glowOpacity: glowOpacityVal,
                                pulseScale: pulseScaleVal,
                                pulseOpacity: pulseOpacityVal,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 2. Brand Name: "TX" in green accent, "Browser" in neutral
                          Opacity(
                            opacity: titleOpacityVal,
                            child: Semantics(
                              header: true,
                              label: 'TX Browser',
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'TX ',
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Browser',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                style: const TextStyle(
                                  fontSize: 30,
                                  letterSpacing: -0.6,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // 3. Short Tagline: "Premium. Private. Powerful."
                          Opacity(
                            opacity: taglineOpacityVal,
                            child: Text(
                              'Premium. Private. Powerful.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.6,
                                color: colors.textTertiary,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Bottom negative space
                      const Spacer(flex: 4),

                      // 4 & 5. Minimal Loading Indicator & Status Text
                      Opacity(
                        opacity: loaderOpacityVal,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colors.primary,
                                  ),
                                  backgroundColor: colors.primary.withValues(
                                    alpha: isDark ? 0.12 : 0.16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: Text(
                                  isAppReady ? 'Ready to browse' : 'Getting things ready…',
                                  key: ValueKey<bool>(isAppReady),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isAppReady ? FontWeight.w600 : FontWeight.w400,
                                    letterSpacing: 0.2,
                                    color: isAppReady
                                        ? colors.primary
                                        : colors.textTertiary.withValues(
                                            alpha: 0.85,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Brand Logo Hero: Subtle Container & Radial Green Glow
// ═════════════════════════════════════════════════════════════════════════════

class _BrandLogoHero extends StatelessWidget {
  const _BrandLogoHero({
    required this.colors,
    required this.isDark,
    required this.glowOpacity,
    this.pulseScale = 1.0,
    this.pulseOpacity = 1.0,
  });

  final TxColorScheme colors;
  final bool isDark;
  final double glowOpacity;
  final double pulseScale;
  final double pulseOpacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft radial green glow behind logo container with breathing pulse
          Transform.scale(
            scale: pulseScale,
            child: Opacity(
              opacity: (glowOpacity * pulseOpacity).clamp(0.0, 1.0),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(
                        alpha: isDark ? 0.32 : 0.18,
                      ),
                      blurRadius: 38,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Subtle premium logo container
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B201A) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? colors.primary.withValues(alpha: 0.22)
                    : colors.border.withValues(alpha: 0.70),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.35)
                      : colors.primary.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'assets/icons/tx_logo.png',
                width: 44,
                height: 44,
                color: isDark ? Colors.white : colors.primary,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    LucideIcons.leaf,
                    size: 40,
                    color: isDark ? Colors.white : colors.primary,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Barely visible subtle ambient radial gradient depth
// ═════════════════════════════════════════════════════════════════════════════

class _SubtleAmbientDepthPainter extends CustomPainter {
  final Color accentColor;
  final bool isDark;

  const _SubtleAmbientDepthPainter({
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.42);
    final radius = size.width * 0.65;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withValues(alpha: isDark ? 0.06 : 0.04),
          accentColor.withValues(alpha: isDark ? 0.02 : 0.01),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _SubtleAmbientDepthPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor || oldDelegate.isDark != isDark;
}
