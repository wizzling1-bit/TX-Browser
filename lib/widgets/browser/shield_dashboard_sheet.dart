import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../state/shield_provider.dart';
import '../tx_snackbar.dart';

/// Shows the Tx Shield Privacy Dashboard Bottom Sheet.
Future<void> showTxShieldDashboard(BuildContext context, String currentHost) {
  final colors = Theme.of(context).extension<TxColorScheme>()!;

  return showModalBottomSheet(
    context: context,
    backgroundColor: colors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ShieldDashboardSheet(host: currentHost),
  );
}

class ShieldDashboardSheet extends ConsumerWidget {
  const ShieldDashboardSheet({super.key, required this.host});

  final String host;

  String _cleanHost(String raw) {
    var h = raw.toLowerCase().trim();
    if (h.startsWith('http://')) h = h.substring(7);
    if (h.startsWith('https://')) h = h.substring(8);
    if (h.startsWith('www.')) h = h.substring(4);
    final slashIndex = h.indexOf('/');
    if (slashIndex != -1) h = h.substring(0, slashIndex);
    return h.isEmpty ? 'This Page' : h;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final shield = ref.watch(shieldProvider);
    final cleanHost = _cleanHost(host);
    final isSiteProtected = shield.isShieldEnabledForHost(cleanHost);
    final stats = shield.getStatsForHost(cleanHost);

    final isGlobal = cleanHost == 'This Page' || cleanHost.isEmpty;
    final isProtected = isGlobal ? shield.isGlobalEnabled : isSiteProtected;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: TxSpacing.lg, vertical: TxSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: TxSpacing.md),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header Row
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isProtected ? colors.primary : colors.textTertiary)
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      LucideIcons.shieldCheck,
                      size: 24,
                      color: isProtected ? colors.primary : colors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: TxSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tx Shield',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                      ),
                      Text(
                        isGlobal ? 'Global Privacy Protection' : cleanHost,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isProtected,
                  onChanged: (val) {
                    if (isGlobal) {
                      ref.read(shieldProvider.notifier).toggleGlobalShield(val);
                    } else {
                      ref.read(shieldProvider.notifier).toggleShieldForHost(cleanHost, val);
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: TxSpacing.md),

            // Protection Status Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: TxSpacing.md, vertical: 10),
              decoration: BoxDecoration(
                color: isProtected
                    ? colors.primary.withValues(alpha: 0.08)
                    : colors.error.withValues(alpha: 0.08),
                borderRadius: TxRadius.borderRadiusSm,
                border: Border.all(
                  color: (isProtected ? colors.primary : colors.error)
                      .withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isProtected ? LucideIcons.check : LucideIcons.shieldAlert,
                    size: 16,
                    color: isProtected ? colors.primary : colors.error,
                  ),
                  const SizedBox(width: TxSpacing.sm),
                  Expanded(
                    child: Text(
                      isProtected
                          ? (isGlobal
                              ? 'Global shield is active. Trackers & ads are blocked across the web.'
                              : 'Tracker & ad protection is active for this site.')
                          : (isGlobal
                              ? 'Global protection is paused. Ads & trackers may load.'
                              : 'Protection is paused for this site. Ads may load.'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isProtected ? colors.primary : colors.error,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: TxSpacing.md),

            // Live Counters Bento Grid
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Ads Blocked',
                    count: isGlobal ? shield.lifetimeAdsBlocked : stats.adsBlocked,
                    icon: LucideIcons.ban,
                    color: colors.error,
                    colors: colors,
                  ),
                ),
                const SizedBox(width: TxSpacing.sm),
                Expanded(
                  child: _StatCard(
                    title: 'Trackers Blocked',
                    count: isGlobal ? shield.lifetimeTrackersBlocked : stats.trackersBlocked,
                    icon: LucideIcons.radar,
                    color: colors.warning,
                    colors: colors,
                  ),
                ),
              ],
            ),
            const SizedBox(height: TxSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Popups Blocked',
                    count: isGlobal ? shield.lifetimePopupsBlocked : stats.popupsBlocked,
                    icon: LucideIcons.externalLink,
                    color: colors.secondary,
                    colors: colors,
                  ),
                ),
                const SizedBox(width: TxSpacing.sm),
                Expanded(
                  child: _StatCard(
                    title: 'Redirects Blocked',
                    count: isGlobal ? shield.lifetimeRedirectsBlocked : stats.redirectsBlocked,
                    icon: LucideIcons.repeat,
                    color: colors.primary,
                    colors: colors,
                  ),
                ),
                const SizedBox(width: TxSpacing.sm),
                Expanded(
                  child: _StatCard(
                    title: 'Total Blocked',
                    count: isGlobal ? shield.totalLifetimeBlocked : stats.requestsBlocked,
                    icon: LucideIcons.shield,
                    color: colors.textPrimary,
                    colors: colors,
                  ),
                ),
              ],
            ),

            const SizedBox(height: TxSpacing.sm),

            // Estimated Savings Highlights
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: TxRadius.borderRadiusSm,
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.hardDrive, size: 16, color: colors.primary),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shield.estimatedDataSavedFormatted,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            'Data Saved',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: colors.border.withValues(alpha: 0.6),
                  ),
                  Row(
                    children: [
                      Icon(LucideIcons.zap, size: 16, color: colors.warning),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shield.estimatedTimeSavedFormatted,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            'Time Saved',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: TxSpacing.md),

            // Reset Site Protection Button (only for site view)
            if (!isGlobal) ...[
              OutlinedButton.icon(
                icon: const Icon(LucideIcons.rotateCcw, size: 16),
                label: const Text('Reset Site Protection'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: TxRadius.borderRadiusSm),
                  side: BorderSide(color: colors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  ref.read(shieldProvider.notifier).resetSiteProtection(cleanHost);
                  TxSnackbar.show(
                    context,
                    'Protection reset for $cleanHost',
                    icon: LucideIcons.rotateCcw,
                  );
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: TxSpacing.sm),
            ],

            // Privacy Disclaimer Note
            Text(
              'Tx Shield intercepts known tracking endpoints and ad networks locally on-device. No browsing data is ever uploaded.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textTertiary,
                    fontSize: 11,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.colors,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final TxColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TxRadius.borderRadiusSm,
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}
