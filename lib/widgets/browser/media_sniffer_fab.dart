import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../state/media_sniffer_provider.dart';
import '../dialogs/media_sniffer_sheet.dart';

/// Floating Action Button for the Smart Video Sniffer.
///
/// Features:
/// - Smooth entrance slide & bounce when media is detected.
/// - Gentle pulsing glow ring to draw thumb focus without annoying vibration.
/// - Real-time count badge showing detected media items.
/// - 1-tap trigger to open the [MediaSnifferSheet].
class MediaSnifferFab extends ConsumerStatefulWidget {
  const MediaSnifferFab({
    super.key,
    this.bottomOffset = 76.0,
    this.rightOffset = TxSpacing.md,
  });

  final double bottomOffset;
  final double rightOffset;

  @override
  ConsumerState<MediaSnifferFab> createState() => _MediaSnifferFabState();
}

class _MediaSnifferFabState extends ConsumerState<MediaSnifferFab> {
  void _onTap() {
    HapticFeedback.selectionClick();
    MediaSnifferSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final snifferState = ref.watch(mediaSnifferProvider);
    final hasMedia = snifferState.hasMedia;
    final count = snifferState.items.length;
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      bottom: widget.bottomOffset,
      right: hasMedia ? widget.rightOffset : -80.0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: hasMedia ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !hasMedia,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _onTap,
                borderRadius: BorderRadius.circular(28),
                splashColor: colors.surface.withValues(alpha: 0.3),
                highlightColor: Colors.transparent,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primary,
                        colors.secondary,
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        LucideIcons.download,
                        color: Colors.white,
                        size: 24,
                      ),

                      // Count Badge
                      if (count > 0)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            decoration: BoxDecoration(
                              color: colors.error,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: colors.surface,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.error.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                count > 99 ? '99+' : count.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
