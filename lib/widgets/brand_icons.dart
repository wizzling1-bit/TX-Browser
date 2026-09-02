import 'package:flutter/material.dart';
import '../core/theme/colors.dart';

/// Pixel-perfect vector brand icons for shortcuts and recent sites.
/// Zero network dependency — crisp, instant rendering in both light and dark mode.
class BrandIconBadge extends StatelessWidget {
  const BrandIconBadge({
    super.key,
    required this.name,
    this.size = 48,
    this.borderRadius = 14,
  });

  final String name;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>();
    final isDark = colors?.isDark ?? false;
    final key = name.toLowerCase().trim();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getBgColor(key, isDark),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: _getBorderColor(key, isDark),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: _buildIconContent(key, isDark, colors?.primary ?? const Color(0xFF4A6B48)),
      ),
    );
  }

  Color _getBgColor(String key, bool isDark) {
    if (isDark) {
      switch (key) {
        case 'figma':
          return const Color(0xFF2C2D30);
        case 'unsplash':
          return const Color(0xFF111111);
        default:
          return const Color(0xFF1B221C);
      }
    }

    switch (key) {
      case 'x':
      case 'twitter':
        return const Color(0xFF000000);
      case 'figma':
        return const Color(0xFF2C2D30);
      case 'unsplash':
        return const Color(0xFF111111);
      default:
        return const Color(0xFFFFFFFF);
    }
  }

  Color _getBorderColor(String key, bool isDark) {
    if (isDark) {
      return const Color(0xFF263228);
    }

    switch (key) {
      case 'x':
      case 'twitter':
      case 'figma':
      case 'unsplash':
        return Colors.transparent;
      default:
        return const Color(0xFFE2E8D5);
    }
  }

  Widget _buildIconContent(String key, bool isDark, Color primaryColor) {
    final iconSize = size * 0.52;

    switch (key) {
      case 'google':
        return _GoogleLogo(size: iconSize);
      case 'youtube':
        return _YouTubeLogo(size: iconSize);
      case 'x':
      case 'twitter':
        return _XLogo(size: iconSize);
      case 'wikipedia':
        return _WikipediaLogo(size: iconSize, isDark: isDark);
      case 'reddit':
        return _RedditLogo(size: iconSize);
      case 'github':
        return _GitHubLogo(size: iconSize, isDark: isDark);
      case 'dribbble':
        return _DribbbleLogo(size: iconSize);
      case 'bhojpuri sex':
      case 'bhojpurisex':
      case 'bhojpuri':
      case '18+':
        return _Adult18Logo(size: iconSize);
      case 'figma':
        return _FigmaLogo(size: iconSize);
      case 'unsplash':
        return _UnsplashLogo(size: iconSize);
      case 'flutter':
      case 'flutter documentation':
        return _FlutterLogo(size: iconSize);
      default:
        return Text(
          key.isNotEmpty ? key[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: size * 0.44,
            fontWeight: FontWeight.w700,
            color: primaryColor,
          ),
        );
    }
  }
}

class _Adult18Logo extends StatelessWidget {
  const _Adult18Logo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.1,
      height: size * 0.9,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3366), Color(0xFFFF5E3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: const Text(
        '18+',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vector Brand Icon Implementations
// ---------------------------------------------------------------------------

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GooglePainter(),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final stroke = size.width * 0.22;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: center, radius: radius - stroke / 2);

    // Blue
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.4, 1.4, false, paint);

    // Green
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 1.0, 1.4, false, paint);

    // Yellow
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.4, 1.4, false, paint);

    // Red
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.8, 1.5, false, paint);

    // Center bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 1, center.dy - stroke / 2, radius + 1, stroke),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _YouTubeLogo extends StatelessWidget {
  const _YouTubeLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.1,
      height: size * 0.78,
      decoration: BoxDecoration(
        color: const Color(0xFFFF0000),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.35, size * 0.35),
          painter: _PlayTrianglePainter(),
        ),
      ),
    );
  }
}

class _PlayTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _XLogo extends StatelessWidget {
  const _XLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      '𝕏',
      style: TextStyle(
        fontSize: size * 0.95,
        color: Colors.white,
        fontWeight: FontWeight.w700,
        height: 1.0,
      ),
    );
  }
}

class _WikipediaLogo extends StatelessWidget {
  const _WikipediaLogo({required this.size, required this.isDark});
  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      'W',
      style: TextStyle(
        fontFamily: 'serif',
        fontSize: size * 0.95,
        color: isDark ? Colors.white : const Color(0xFF000000),
        fontWeight: FontWeight.w800,
        height: 1.0,
      ),
    );
  }
}

class _RedditLogo extends StatelessWidget {
  const _RedditLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFFF4500),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.face,
          size: size * 0.72,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _GitHubLogo extends StatelessWidget {
  const _GitHubLogo({required this.size, required this.isDark});
  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.code,
      size: size * 0.9,
      color: isDark ? Colors.white : const Color(0xFF24292F),
    );
  }
}

class _DribbbleLogo extends StatelessWidget {
  const _DribbbleLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFEA4C89),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.sports_basketball,
          size: size * 0.75,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _FigmaLogo extends StatelessWidget {
  const _FigmaLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 0.75,
      height: size * 0.9,
      child: Column(
        children: [
          Row(
            children: [
              _figmaDot(const Color(0xFFF24E1E)),
              _figmaDot(const Color(0xFFFF7262)),
            ],
          ),
          Row(
            children: [
              _figmaDot(const Color(0xFFA259FF)),
              _figmaDot(const Color(0xFF1ABCFE)),
            ],
          ),
          Row(
            children: [
              _figmaDot(const Color(0xFF0ACF83)),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _figmaDot(Color color) {
    return Container(
      width: size * 0.35,
      height: size * 0.3,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _UnsplashLogo extends StatelessWidget {
  const _UnsplashLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size * 0.35,
          height: size * 0.28,
          color: Colors.white,
        ),
        const SizedBox(height: 2),
        Container(
          width: size * 0.75,
          height: size * 0.42,
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.white, width: 2.5),
              right: BorderSide(color: Colors.white, width: 2.5),
              bottom: BorderSide(color: Colors.white, width: 2.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _FlutterLogo extends StatelessWidget {
  const _FlutterLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return FlutterLogo(size: size * 0.85);
  }
}
