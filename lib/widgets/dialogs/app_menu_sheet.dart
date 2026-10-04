import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../features/exit/exit_dialog.dart';
import '../../state/downloads_provider.dart';
import '../../state/rewarded_perks_provider.dart';
import '../../state/tabs_provider.dart';
import '../browser/shield_dashboard_sheet.dart';
import '../buttons/tx_pressable.dart';
import 'report_issue_sheet.dart';

/// Opens the modern, ergonomic TX Browser App Menu Bottom Sheet.
Future<void> showTxAppMenuSheet({
  required BuildContext context,
  required WidgetRef ref,
  bool isHomeScreen = true,
  String currentUrl = '',
  bool isBookmarked = false,
  bool isDesktopMode = false,
  VoidCallback? onUnlockAdFreePass,
  VoidCallback? onToggleBookmark,
  VoidCallback? onToggleDesktopMode,
  VoidCallback? onFindInPage,
  VoidCallback? onShare,
  VoidCallback? onPinToHome,
}) {
  final colors = Theme.of(context).extension<TxColorScheme>()!;

  return showModalBottomSheet(
    context: context,
    backgroundColor: colors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => TxAppMenuSheet(
      isHomeScreen: isHomeScreen,
      currentUrl: currentUrl,
      isBookmarked: isBookmarked,
      isDesktopMode: isDesktopMode,
      onUnlockAdFreePass: onUnlockAdFreePass,
      onToggleBookmark: onToggleBookmark,
      onToggleDesktopMode: onToggleDesktopMode,
      onFindInPage: onFindInPage,
      onShare: onShare,
      onPinToHome: onPinToHome,
    ),
  );
}

/// The modern bottom sheet menu providing structured, ergonomic access to browser features.
class TxAppMenuSheet extends ConsumerWidget {
  const TxAppMenuSheet({
    super.key,
    required this.isHomeScreen,
    this.currentUrl = '',
    this.isBookmarked = false,
    this.isDesktopMode = false,
    this.onUnlockAdFreePass,
    this.onToggleBookmark,
    this.onToggleDesktopMode,
    this.onFindInPage,
    this.onShare,
    this.onPinToHome,
  });

  final bool isHomeScreen;
  final String currentUrl;
  final bool isBookmarked;
  final bool isDesktopMode;
  final VoidCallback? onUnlockAdFreePass;
  final VoidCallback? onToggleBookmark;
  final VoidCallback? onToggleDesktopMode;
  final VoidCallback? onFindInPage;
  final VoidCallback? onShare;
  final VoidCallback? onPinToHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final perks = ref.watch(rewardedPerksProvider);
    final downloads = ref.watch(downloadsProvider);
    final currentHost = Uri.tryParse(currentUrl)?.host ?? '';

    return SafeArea(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TxSpacing.lg,
            vertical: TxSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 4, bottom: TxSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 2. 10-Min Ad-Free Pass Premium Perk Card
              _AdFreePassHeaderCard(
                perks: perks,
                onTap: () {
                  Navigator.pop(context);
                  onUnlockAdFreePass?.call();
                },
              ),

              const SizedBox(height: TxSpacing.md),

              // 3. Quick Actions Section (Structured Tile Grid)
              if (isHomeScreen)
                _buildHomeScreenGrid(context, ref, colors, downloads.length)
              else
                _buildBrowserScreenGrid(context, ref, colors),

              const SizedBox(height: TxSpacing.md),

              // 4. TX Shield & Privacy Featured Card
              _TxShieldFeatureCard(
                colors: colors,
                host: currentHost,
                onTap: () {
                  Navigator.pop(context);
                  showTxShieldDashboard(context, currentHost);
                },
              ),

              // 5. Browser-Specific Secondary Actions (if in browser screen)
              if (!isHomeScreen) ...[
                const SizedBox(height: TxSpacing.md),
                _buildBrowserSecondaryList(context, colors),
              ],

              // 5. Feedback & Broken Site Reporting (Home Screen)
              if (isHomeScreen) ...[
                const SizedBox(height: TxSpacing.md),
                Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: _ListRowItem(
                    icon: LucideIcons.messageSquare,
                    label: 'Report Issue / Send Feedback',
                    colors: colors,
                    onTap: () {
                      Navigator.pop(context);
                      ReportIssueSheet.show(context);
                    },
                  ),
                ),
              ],

              // 6. Footer Destructive Action (Exit TX Browser on Home Screen)
              if (isHomeScreen) ...[
                const SizedBox(height: TxSpacing.md),
                _ExitActionTile(
                  colors: colors,
                  onTap: () {
                    Navigator.pop(context);
                    showTxExitDialog(context, ref);
                  },
                ),
              ],

              const SizedBox(height: TxSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  /// 3x2 Grid for Home Screen (New Tab, Private Tab, Bookmarks, History, Downloads, Settings)
  Widget _buildHomeScreenGrid(
    BuildContext context,
    WidgetRef ref,
    TxColorScheme colors,
    int downloadsCount,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MenuActionTile(
                icon: LucideIcons.plus,
                label: 'New tab',
                onTap: () {
                  Navigator.pop(context);
                  ref.read(tabsProvider.notifier).openTab();
                },
              ),
            ),
            const SizedBox(width: TxSpacing.sm),
            Expanded(
              child: _MenuActionTile(
                icon: LucideIcons.shieldCheck,
                label: 'Private tab',
                isPrivateAccent: true,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(tabsProvider.notifier).openTab(isPrivate: true);
                  context.go('/');
                },
              ),
            ),
            const SizedBox(width: TxSpacing.sm),
            Expanded(
              child: _MenuActionTile(
                icon: LucideIcons.bookmark,
                label: 'Bookmarks',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/bookmarks');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: TxSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _MenuActionTile(
                icon: LucideIcons.history,
                label: 'History',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/history');
                },
              ),
            ),
            const SizedBox(width: TxSpacing.sm),
            Expanded(
              child: _MenuActionTile(
                icon: LucideIcons.download,
                label: 'Downloads',
                badgeText: downloadsCount > 0 ? '$downloadsCount' : null,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/downloads');
                },
              ),
            ),
            const SizedBox(width: TxSpacing.sm),
            Expanded(
              child: _MenuActionTile(
                icon: LucideIcons.settings,
                label: 'Settings',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/settings');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 3x2 Grid for Browser Screen
  Widget _buildBrowserScreenGrid(
    BuildContext context,
    WidgetRef ref,
    TxColorScheme colors,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MenuActionTile(
                icon: LucideIcons.plus,
                label: 'New tab',
                onTap: () {
                  Navigator.pop(context);
                  ref.read(tabsProvider.notifier).openTab();
                  context.go('/');
                },
              ),
            ),
            const SizedBox(width: TxSpacing.sm),
            Expanded(
              child: _MenuActionTile(
                icon: LucideIcons.shieldCheck,
                label: 'Private tab',
                isPrivateAccent: true,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(tabsProvider.notifier).openTab(isPrivate: true);
                  context.go('/');
                },
              ),
            ),
            const SizedBox(width: TxSpacing.sm),
            Expanded(
              child: _MenuActionTile(
                icon: isBookmarked ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
                label: isBookmarked ? 'Bookmarked' : 'Bookmark',
                isActive: isBookmarked,
                onTap: () {
                  Navigator.pop(context);
                  onToggleBookmark?.call();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: TxSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _MenuActionTile(
                icon: LucideIcons.share2,
                label: 'Share',
                onTap: () {
                  Navigator.pop(context);
                  onShare?.call();
                },
              ),
            ),
            const SizedBox(width: TxSpacing.sm),
            Expanded(
              child: _MenuActionTile(
                icon: LucideIcons.search,
                label: 'Find in page',
                onTap: () {
                  Navigator.pop(context);
                  onFindInPage?.call();
                },
              ),
            ),
            const SizedBox(width: TxSpacing.sm),
            Expanded(
              child: _MenuActionTile(
                icon: LucideIcons.monitor,
                label: isDesktopMode ? 'Mobile site' : 'Desktop site',
                isActive: isDesktopMode,
                onTap: () {
                  Navigator.pop(context);
                  onToggleDesktopMode?.call();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Secondary row items for Browser Screen
  Widget _buildBrowserSecondaryList(BuildContext context, TxColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        children: [
          _ListRowItem(
            icon: LucideIcons.bookmark,
            label: 'Pinned Sites',
            colors: colors,
            onTap: () {
              Navigator.pop(context);
              context.push('/pinned-sites');
            },
          ),
          Divider(color: colors.borderSubtle, height: 1, indent: 48),
          _ListRowItem(
            icon: LucideIcons.smartphone,
            label: 'Pin to Home screen',
            colors: colors,
            onTap: () {
              Navigator.pop(context);
              onPinToHome?.call();
            },
          ),
          Divider(color: colors.borderSubtle, height: 1, indent: 48),
          _ListRowItem(
            icon: LucideIcons.history,
            label: 'History',
            colors: colors,
            onTap: () {
              Navigator.pop(context);
              context.push('/history');
            },
          ),
          Divider(color: colors.borderSubtle, height: 1, indent: 48),
          _ListRowItem(
            icon: LucideIcons.download,
            label: 'Downloads',
            colors: colors,
            onTap: () {
              Navigator.pop(context);
              context.push('/downloads');
            },
          ),
          Divider(color: colors.borderSubtle, height: 1, indent: 48),
          _ListRowItem(
            icon: LucideIcons.messageSquare,
            label: 'Report Broken Site / Feedback',
            colors: colors,
            onTap: () {
              Navigator.pop(context);
              ReportIssueSheet.show(context, currentUrl: currentUrl);
            },
          ),
          Divider(color: colors.borderSubtle, height: 1, indent: 48),
          _ListRowItem(
            icon: LucideIcons.settings,
            label: 'Settings',
            colors: colors,
            onTap: () {
              Navigator.pop(context);
              context.push('/settings');
            },
          ),
        ],
      ),
    );
  }
}

/// 10-Minute Ad-Free Pass Header Card
class _AdFreePassHeaderCard extends StatelessWidget {
  const _AdFreePassHeaderCard({
    required this.perks,
    required this.onTap,
  });

  final RewardedPerksState perks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final isActive = perks.isAdFreeActive;

    return TxPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? colors.primary.withValues(alpha: 0.12)
              : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? colors.primary.withValues(alpha: 0.4)
                : const Color(0xFFE5A93C).withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isActive
                    ? colors.primary.withValues(alpha: 0.2)
                    : const Color(0xFFE5A93C).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isActive ? LucideIcons.shieldCheck : LucideIcons.star,
                size: 20,
                color: isActive ? colors.primary : const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: TxSpacing.md),
            // Text info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '10-Min Ad-Free Pass',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isActive
                        ? 'Active • ${perks.formatDuration(perks.remainingAdFreeTime)} remaining'
                        : 'Watch a short ad for zero interruptions',
                    style: TextStyle(
                      color: isActive ? colors.primary : colors.textSecondary,
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Trailing action badge / unlock button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? colors.primary.withValues(alpha: 0.18)
                    : colors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isActive) ...[
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Unlock',
                      style: TextStyle(
                        color: colors.isDark ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 14,
                      color: colors.isDark ? Colors.black : Colors.white,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Action Tile in the 3-column Grid
class _MenuActionTile extends StatelessWidget {
  const _MenuActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeText,
    this.isActive = false,
    this.isPrivateAccent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badgeText;
  final bool isActive;
  final bool isPrivateAccent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    final effectiveColor = isPrivateAccent
        ? const Color(0xFF8B5CF6) // Modern sleek purple for incognito
        : (isActive ? colors.primary : colors.textPrimary);

    final effectiveBg = isPrivateAccent
        ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
        : (isActive
            ? colors.primary.withValues(alpha: 0.1)
            : colors.surfaceAlt.withValues(alpha: 0.7));

    final effectiveBorder = isPrivateAccent
        ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
        : (isActive
            ? colors.primary.withValues(alpha: 0.4)
            : colors.borderSubtle);

    return TxPressable(
      onTap: onTap,
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: effectiveBorder, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: effectiveColor,
                ),
                if (badgeText != null)
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeText!,
                        style: TextStyle(
                          color: colors.isDark ? Colors.black : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isPrivateAccent
                    ? colors.textPrimary
                    : (isActive ? colors.primary : colors.textPrimary),
                fontSize: 12,
                fontWeight: isPrivateAccent || isActive
                    ? FontWeight.w600
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Featured Card for TX Shield & Privacy
class _TxShieldFeatureCard extends StatelessWidget {
  const _TxShieldFeatureCard({
    required this.colors,
    required this.host,
    required this.onTap,
  });

  final TxColorScheme colors;
  final String host;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TxPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surfaceAlt.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.shieldCheck,
                size: 20,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: TxSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TX Shield & Privacy',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    host.isNotEmpty
                        ? 'Active for $host'
                        : 'Tracker & Ad Blocker • Site Controls',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      color: colors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    'Protected',
                    style: TextStyle(
                      color: colors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Refined Exit Action Tile
class _ExitActionTile extends StatelessWidget {
  const _ExitActionTile({
    required this.colors,
    required this.onTap,
  });

  final TxColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TxPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.error.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                LucideIcons.power,
                size: 18,
                color: colors.error,
              ),
            ),
            const SizedBox(width: TxSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Exit TX Browser',
                    style: TextStyle(
                      color: colors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Safely close tabs and purge private session',
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: colors.error.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

/// List row item for secondary browser actions
class _ListRowItem extends StatelessWidget {
  const _ListRowItem({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final TxColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
