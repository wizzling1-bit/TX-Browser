import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../buttons/tx_pressable.dart';

/// Clean domain helper
String _extractDomain(String url) {
  if (url.isEmpty) return 'Blank Tab';
  try {
    final uri = Uri.parse(url);
    var host = uri.host;
    if (host.startsWith('www.')) host = host.substring(4);
    return host.isNotEmpty ? host : url;
  } catch (_) {
    return url;
  }
}

/// Helper to resolve high-res favicon URL
String? _resolveFavicon(String? directFavicon, String url) {
  if (directFavicon != null && directFavicon.isNotEmpty) {
    return directFavicon;
  }
  final domain = _extractDomain(url);
  if (domain.isNotEmpty && domain != 'Blank Tab' && domain != 'New Tab' && domain.contains('.')) {
    return 'https://www.google.com/s2/favicons?domain=$domain&sz=128';
  }
  return null;
}

class _DomainTheme {
  const _DomainTheme({
    required this.gradientColors,
    required this.accentColor,
    required this.icon,
    required this.tag,
  });

  final List<Color> gradientColors;
  final Color accentColor;
  final IconData icon;
  final String tag;
}

_DomainTheme _resolveDomainTheme(String url, String title, bool isPrivate, TxColorScheme colors) {
  if (isPrivate) {
    return _DomainTheme(
      gradientColors: const [Color(0xFF232B25), Color(0xFF131814)],
      accentColor: colors.privateAccent,
      icon: LucideIcons.shieldCheck,
      tag: 'PRIVATE',
    );
  }

  final lowerUrl = url.toLowerCase();
  final lowerTitle = title.toLowerCase();

  if (lowerUrl.isEmpty || lowerUrl.contains('blank') || lowerTitle.contains('new tab')) {
    return const _DomainTheme(
      gradientColors: [Color(0xFF4B7B4B), Color(0xFF284728)],
      accentColor: Color(0xFF9DC08B),
      icon: LucideIcons.leaf,
      tag: 'TX START',
    );
  }

  if (lowerUrl.contains('youtube') || lowerUrl.contains('youtu.be')) {
    return const _DomainTheme(
      gradientColors: [Color(0xFFD9232A), Color(0xFF8B0D12)],
      accentColor: Colors.white,
      icon: LucideIcons.play,
      tag: 'VIDEO',
    );
  }

  if (lowerUrl.contains('google')) {
    return const _DomainTheme(
      gradientColors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
      accentColor: Color(0xFF60A5FA),
      icon: LucideIcons.search,
      tag: 'SEARCH',
    );
  }

  if (lowerUrl.contains('github')) {
    return const _DomainTheme(
      gradientColors: [Color(0xFF24292E), Color(0xFF0D1117)],
      accentColor: Colors.white,
      icon: LucideIcons.code,
      tag: 'DEV',
    );
  }

  if (lowerUrl.contains('reddit')) {
    return const _DomainTheme(
      gradientColors: [Color(0xFFFF4500), Color(0xFF9A2900)],
      accentColor: Colors.white,
      icon: LucideIcons.messageSquare,
      tag: 'COMMUNITY',
    );
  }

  if (lowerUrl.contains('instagram') || lowerUrl.contains('facebook') || lowerUrl.contains('meta')) {
    return const _DomainTheme(
      gradientColors: [Color(0xFFC13584), Color(0xFF5851DB)],
      accentColor: Colors.white,
      icon: LucideIcons.camera,
      tag: 'SOCIAL',
    );
  }

  if (lowerUrl.contains('filmy') ||
      lowerUrl.contains('movie') ||
      lowerUrl.contains('cinema') ||
      lowerUrl.contains('video') ||
      lowerUrl.contains('stream')) {
    return const _DomainTheme(
      gradientColors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
      accentColor: Color(0xFFDDD6FE),
      icon: LucideIcons.film,
      tag: 'STREAM',
    );
  }

  if (lowerUrl.contains('twitter') || lowerUrl.contains('x.com')) {
    return const _DomainTheme(
      gradientColors: [Color(0xFF1E293B), Color(0xFF0F172A)],
      accentColor: Colors.white,
      icon: LucideIcons.send,
      tag: 'SOCIAL',
    );
  }

  if (lowerUrl.contains('wikipedia')) {
    return const _DomainTheme(
      gradientColors: [Color(0xFF475569), Color(0xFF1E293B)],
      accentColor: Colors.white,
      icon: LucideIcons.bookOpen,
      tag: 'WIKI',
    );
  }

  // Curated deterministic palette from hash
  final hash = url.hashCode.abs();
  final palettes = [
    [const Color(0xFF0D9488), const Color(0xFF115E59)], // Teal
    [const Color(0xFF2563EB), const Color(0xFF1E40AF)], // Sapphire
    [const Color(0xFF7C3AED), const Color(0xFF5B21B6)], // Amethyst
    [const Color(0xFFEA580C), const Color(0xFF9A3412)], // Amber
    [const Color(0xFF059669), const Color(0xFF064E3B)], // Emerald
    [const Color(0xFF475569), const Color(0xFF0F172A)], // Slate
    [const Color(0xFFDB2777), const Color(0xFF9D174D)], // Rose
  ];
  final palette = palettes[hash % palettes.length];

  return _DomainTheme(
    gradientColors: palette,
    accentColor: Colors.white,
    icon: LucideIcons.globe,
    tag: 'WEB',
  );
}

/// Renders an ultra-premium webpage preview for tab cards.
class TabWebPagePreview extends StatelessWidget {
  const TabWebPagePreview({
    super.key,
    required this.title,
    required this.url,
    required this.isPrivate,
    required this.colors,
    this.previewBytes,
    this.faviconUrl,
  });

  final String title;
  final String url;
  final bool isPrivate;
  final TxColorScheme colors;
  final Uint8List? previewBytes;
  final String? faviconUrl;

  @override
  Widget build(BuildContext context) {
    if (previewBytes != null && previewBytes!.isNotEmpty) {
      return Image.memory(
        previewBytes!,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildSimulatedPreview(context),
      );
    }
    return _buildSimulatedPreview(context);
  }

  Widget _buildSimulatedPreview(BuildContext context) {
    final domain = _extractDomain(url);
    final theme = _resolveDomainTheme(url, title, isPrivate, colors);
    final effectiveFavicon = _resolveFavicon(faviconUrl, url);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradientColors,
        ),
      ),
      child: Stack(
        children: [
          // 1. Ambient Background Pattern & Radial Glow
          Positioned(
            top: -20,
            right: -20,
            width: 120,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.accentColor.withValues(alpha: 0.15),
              ),
            ),
          ),

          // 2. Simulated Web Page Layout
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),

                // Center Floating Logo / Favicon Card
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: (effectiveFavicon != null)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                effectiveFavicon,
                                width: 28,
                                height: 28,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  theme.icon,
                                  size: 26,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Icon(
                              theme.icon,
                              size: 26,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Simulated Mini Address / Domain Pill
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPrivate ? LucideIcons.shieldCheck : LucideIcons.lock,
                          size: 9,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 90),
                          child: Text(
                            domain,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                // 3. Simulated Content Skeleton Lines
                Container(
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 26),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Spatial Grid Tab Card for TX Browser Tab Manager.
///
/// Features:
/// - Ultra-premium web page preview (live screenshot or dynamic glassmorphic domain showcase)
/// - Distinct active emerald aura and "ACTIVE" badge
/// - Private/incognito dark glass treatment
/// - Favicon and domain pills
/// - 1-tap close button with spring press
/// - Long press context menu trigger
class TabCard extends StatelessWidget {
  const TabCard({
    super.key,
    required this.title,
    required this.isActive,
    this.url = '',
    this.faviconUrl,
    this.previewBytes,
    this.isPrivate = false,
    this.thumbnailColor,
    this.onTap,
    this.onClose,
    this.onLongPress,
  });

  final String title;
  final bool isActive;
  final String url;
  final String? faviconUrl;
  final Uint8List? previewBytes;
  final bool isPrivate;
  final Color? thumbnailColor;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final domain = _extractDomain(url);
    final displayTitle = title.trim().isNotEmpty ? title : 'New Tab';

    return TxPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleDown: 0.96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: TxRadius.borderRadiusLg,
          border: Border.all(
            color: isActive
                ? (isPrivate ? colors.privateAccent : colors.primary)
                : colors.border.withValues(alpha: 0.55),
            width: isActive ? 2.0 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: (isPrivate ? colors.privateAccent : colors.primary)
                        .withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                    spreadRadius: 1,
                  ),
                ]
              : TxElevation.elevation1,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TxRadius.lg - 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── 1. TOP PREVIEW CANVAS ───────────────────────────
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    // Dynamic Web Page Preview / Screenshot
                    Positioned.fill(
                      child: TabWebPagePreview(
                        title: displayTitle,
                        url: url,
                        isPrivate: isPrivate,
                        colors: colors,
                        previewBytes: previewBytes,
                        faviconUrl: faviconUrl,
                      ),
                    ),

                    // Top Glass Scrim for Controls Contrast
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 38,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Active Tab Indicator Badge
                    if (isActive)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: isPrivate
                                ? colors.privateAccent
                                : colors.primary,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.check,
                                size: 10,
                                color: Colors.white,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (isPrivate)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colors.privateAccent.withValues(alpha: 0.6),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.shieldCheck,
                                size: 10,
                                color: colors.privateAccent,
                              ),
                              const SizedBox(width: 3),
                              const Text(
                                'Private',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Close Button
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Semantics(
                        label: 'Close tab',
                        button: true,
                        child: TxPressable(
                          onTap: onClose,
                          scaleDown: 0.85,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              LucideIcons.x,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── 2. BOTTOM DETAILS AREA ──────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayTitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      domain,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spatial List View Tile for Tab Manager list mode.
class TabListTile extends StatelessWidget {
  const TabListTile({
    super.key,
    required this.title,
    required this.isActive,
    this.url = '',
    this.faviconUrl,
    this.previewBytes,
    this.isPrivate = false,
    this.onTap,
    this.onClose,
    this.onLongPress,
  });

  final String title;
  final bool isActive;
  final String url;
  final String? faviconUrl;
  final Uint8List? previewBytes;
  final bool isPrivate;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final domain = _extractDomain(url);
    final displayTitle = title.trim().isNotEmpty ? title : 'New Tab';
    final theme = _resolveDomainTheme(url, title, isPrivate, colors);
    final effectiveFavicon = _resolveFavicon(faviconUrl, url);

    return TxPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleDown: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? (isPrivate ? colors.privateAccent : colors.primary)
                : colors.border.withValues(alpha: 0.5),
            width: isActive ? 1.8 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: (isPrivate ? colors.privateAccent : colors.primary)
                        .withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : TxElevation.elevation1,
        ),
        child: Row(
          children: [
            // Preview / Favicon Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: theme.gradientColors,
                  ),
                ),
                child: (previewBytes != null && previewBytes!.isNotEmpty)
                    ? Image.memory(
                        previewBytes!,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(theme.icon, size: 20, color: Colors.white),
                        ),
                      )
                    : Center(
                        child: (effectiveFavicon != null)
                            ? Image.network(
                                effectiveFavicon,
                                width: 22,
                                height: 22,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  theme.icon,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                theme.icon,
                                size: 20,
                                color: Colors.white,
                              ),
                      ),
              ),
            ),

            const SizedBox(width: TxSpacing.md),

            // Title & Domain
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (isPrivate) ...[
                        Icon(
                          LucideIcons.shieldCheck,
                          size: 13,
                          color: colors.privateAccent,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          displayTitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    domain,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Active Badge
            if (isActive) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPrivate ? colors.privateAccent : colors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: TxSpacing.sm),
            ],

            // Close Button
            TxPressable(
              onTap: onClose,
              scaleDown: 0.85,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.bg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.x,
                  size: 16,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
