import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/search_engines.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/shapes.dart';
import '../../state/app_lock_provider.dart';
import '../../state/history_provider.dart';
import '../../state/proxy_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/shield_provider.dart';
import '../../state/rewarded_perks_provider.dart';
import '../../state/notification_provider.dart';
import '../../services/notification_service/notification_models.dart';
import '../../widgets/buttons/tx_button.dart';
import '../../widgets/buttons/tx_pressable.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/responsive/tx_responsive_container.dart';
import '../../widgets/dialogs/cache_cleaned_dialog.dart';
import '../../services/ad_service/ad_service.dart';

/// Redesigned commercial Settings Screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final settings = ref.watch(settingsProvider);
    final lockState = ref.watch(appLockProvider);
    final proxyState = ref.watch(proxyProvider);
    final shieldState = ref.watch(shieldProvider);
    final perks = ref.watch(rewardedPerksProvider);
    final notifState = ref.watch(notificationSettingsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      child: Scaffold(
        appBar: AppBar(
        leading: TxIconButton(
          icon: LucideIcons.chevronLeft,
          semanticLabel: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: TxResponsiveContainer(
          maxWidth: 720,
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: TxSpacing.xxl),
            children: [
            // ─── GENERAL ─────────────────────────────────────────
            SettingsSection(
              title: 'General',
              children: [
                SettingsRow(
                  icon: LucideIcons.search,
                  title: 'Default Search Engine',
                  value: settings.searchEngine.name,
                  onTap: () => _showSearchEnginePicker(context, ref, settings),
                ),
                SettingsRow(
                  icon: LucideIcons.bookmarkCheck,
                  title: 'Bookmarks & Folders',
                  subtitle: 'View, organize, and search saved sites',
                  onTap: () => context.push('/bookmarks'),
                ),
                SettingsRow(
                  icon: LucideIcons.bookmark,
                  title: 'Pinned Quick Access Sites',
                  subtitle: 'Add, edit, or reorder shortcuts',
                  onTap: () => context.push('/pinned-sites'),
                ),
                SettingsRow(
                  icon: LucideIcons.monitor,
                  title: 'Request Desktop Site by Default',
                  trailing: Switch(
                    value: settings.desktopSiteDefault,
                    onChanged: (v) {
                      ref
                          .read(settingsProvider.notifier)
                          .setDesktopSiteDefault(v);
                    },
                  ),
                ),
              ],
            ),

            // ─── PUSH NOTIFICATIONS ──────────────────────────────
            SettingsSection(
              title: 'Notifications',
              children: [
                SettingsRow(
                  icon: LucideIcons.bell,
                  title: 'Push Notifications',
                  subtitle: notifState.notificationsEnabled ? 'Enabled' : 'Disabled',
                  trailing: Switch(
                    value: notifState.notificationsEnabled,
                    onChanged: (v) {
                      ref
                          .read(notificationSettingsProvider.notifier)
                          .setNotificationsEnabled(v);
                    },
                  ),
                ),
                if (notifState.notificationsEnabled) ...[
                  SettingsRow(
                    icon: LucideIcons.rotateCw,
                    title: 'Browser Updates',
                    subtitle: 'New features and version releases',
                    trailing: Switch(
                      value: notifState.updatesEnabled,
                      onChanged: (v) {
                        ref
                            .read(notificationSettingsProvider.notifier)
                            .setTopicEnabled(ApprovedTopics.updates, v);
                      },
                    ),
                  ),
                  SettingsRow(
                    icon: LucideIcons.shieldAlert,
                    title: 'Security Advisories',
                    subtitle: 'Important safe browsing advisories',
                    trailing: Switch(
                      value: notifState.securityEnabled,
                      onChanged: (v) {
                        ref
                            .read(notificationSettingsProvider.notifier)
                            .setTopicEnabled(ApprovedTopics.security, v);
                      },
                    ),
                  ),
                  SettingsRow(
                    icon: LucideIcons.sparkles,
                    title: 'Promotions & Perks',
                    subtitle: 'Partner offers and perks',
                    trailing: Switch(
                      value: notifState.promotionsEnabled,
                      onChanged: (v) {
                        ref
                            .read(notificationSettingsProvider.notifier)
                            .setTopicEnabled(ApprovedTopics.promotions, v);
                      },
                    ),
                  ),
                ],
              ],
            ),

            // ─── PRIVACY & DATA ──────────────────────────────────
            SettingsSection(
              title: 'Privacy & Data',
              children: [
                SettingsRow(
                  icon: LucideIcons.shieldAlert,
                  title: 'Website Permissions',
                  subtitle: 'Camera, microphone, and location per site',
                  onTap: () => context.push('/site-permissions'),
                ),
                SettingsRow(
                  icon: LucideIcons.history,
                  title: 'Browsing History',
                  subtitle: 'Manage or search visited sites',
                  onTap: () => context.push('/history'),
                ),
                SettingsRow(
                  icon: LucideIcons.timerReset,
                  title: 'Auto-Clear History',
                  value: _formatAutoClearPolicy(settings.autoClearPolicy),
                  onTap: () => _showAutoClearSelector(context, ref, settings),
                ),
                SettingsRow(
                  icon: LucideIcons.trash2,
                  title: 'Clear Browsing Data',
                  subtitle: 'History, cookies, and cached storage',
                  isDestructive: true,
                  onTap: () => _showClearDataSheet(context, ref),
                ),
              ],
            ),

            // ─── SECURITY ────────────────────────────────────────
            SettingsSection(
              title: 'Security & Protection',
              children: [
                SettingsRow(
                  icon: LucideIcons.shieldCheck,
                  title: 'Tx Shield Content Blocker',
                  subtitle: 'Block known ad networks and trackers',
                  trailing: Switch(
                    value: shieldState.isGlobalEnabled,
                    onChanged: (v) {
                      ref.read(shieldProvider.notifier).toggleGlobalShield(v);
                    },
                  ),
                ),
                SettingsRow(
                  icon: LucideIcons.lock,
                  title: 'App Lock & Biometrics',
                  value: lockState.isEnabled ? 'Active' : 'Disabled',
                  statusColor: lockState.isEnabled ? colors.success : colors.textTertiary,
                  onTap: () => context.push('/app-lock'),
                ),
                SettingsRow(
                  icon: LucideIcons.globe,
                  title: 'Native Proxy Controller',
                  value: proxyState.isEnabled ? 'Enabled' : 'Direct',
                  statusColor: proxyState.isEnabled ? colors.primary : colors.textTertiary,
                  onTap: () => context.push('/proxy'),
                ),
              ],
            ),

            // ─── APPEARANCE ──────────────────────────────────────
            SettingsSection(
              title: 'Appearance',
              children: [
                _ThemeRow(
                  currentMode: settings.themeMode,
                  onChanged: (mode) {
                    ref.read(settingsProvider.notifier).setThemeMode(mode);
                  },
                ),
              ],
            ),

            // ─── DOWNLOADS ───────────────────────────────────────
            SettingsSection(
              title: 'Downloads',
              children: [
                SettingsRow(
                  icon: LucideIcons.download,
                  title: 'Download Manager',
                  subtitle: 'View and manage downloaded files',
                  onTap: () => context.push('/downloads'),
                ),
              ],
            ),

            // ─── ABOUT ───────────────────────────────────────────
            SettingsSection(
              title: 'About & Support',
              children: [
                SettingsRow(
                  icon: LucideIcons.star,
                  title: '10-Min Ad-Free Pass',
                  subtitle: perks.isAdFreeActive
                      ? 'Ad-free browsing active'
                      : 'Watch a short video to hide all ads for 10 min',
                  value: perks.isAdFreeActive
                      ? perks.formatDuration(perks.remainingAdFreeTime)
                      : 'Unlock',
                  statusColor: perks.isAdFreeActive ? colors.success : colors.primary,
                  onTap: () {
                    if (perks.isAdFreeActive) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Ad-Free Pass is active! ${perks.formatDuration(perks.remainingAdFreeTime)} remaining.',
                          ),
                        ),
                      );
                      return;
                    }
                    final didShow = ref.read(adServiceProvider).showRewardedAd(
                      onUserEarnedReward: (reward) {
                        ref.read(rewardedPerksProvider.notifier).activateAdFreePass();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🎉 10-Minute Ad-Free Pass Activated! All ads are now hidden.'),
                          ),
                        );
                      },
                      onDismissed: () {},
                    );
                    if (!didShow) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ad is loading, please try again in a moment.'),
                        ),
                      );
                    }
                  },
                ),
                const _VersionRow(),
                const SettingsRow(
                  icon: LucideIcons.hardDrive,
                  title: 'Architecture',
                  value: 'Zero-Cloud Local SQLite',
                ),
                SettingsRow(
                  icon: LucideIcons.fileText,
                  title: 'Open Source Licenses',
                  onTap: () => showLicensePage(context: context),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
);
}

  void _showSearchEnginePicker(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: TxRadius.borderRadiusSheet,
      ),
      builder: (ctx) {
        final colors = Theme.of(ctx).extension<TxColorScheme>()!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: TxSpacing.md),
              Text(
                'Default Search Engine',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: TxSpacing.md),
              ...SearchEngine.values.map((engine) {
                final isSelected = engine == settings.searchEngine;
                return ListTile(
                  title: Text(
                    engine.name,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(LucideIcons.check, color: colors.primary)
                      : null,
                  onTap: () {
                    ref
                        .read(settingsProvider.notifier)
                        .setSearchEngine(engine);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: TxSpacing.md),
            ],
          ),
        );
      },
    );
  }

  void _showAutoClearSelector(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    final options = [
      {'label': 'Never', 'value': 'never'},
      {'label': 'When closing browser', 'value': 'on_app_exit'},
      {'label': 'After 15 minutes of inactivity', 'value': 'after_15m'},
      {'label': 'After 1 hour of inactivity', 'value': 'after_1h'},
      {'label': 'After 1 day of inactivity', 'value': 'after_1d'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: TxRadius.borderRadiusSheet,
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TxSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Auto-Clear History Policy',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: TxSpacing.sm),
              ...options.map((opt) {
                final isSelected = opt['value'] == settings.autoClearPolicy;
                return ListTile(
                  title: Text(opt['label']!),
                  trailing: isSelected
                      ? Icon(LucideIcons.check, color: colors.primary)
                      : null,
                  onTap: () {
                    ref
                        .read(settingsProvider.notifier)
                        .setAutoClearPolicy(opt['value']!);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearDataSheet(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: TxRadius.borderRadiusSheet,
      ),
      builder: (ctx) => _ClearDataSheet(colors: colors, ref: ref),
    );
  }

  String _formatAutoClearPolicy(String policy) {
    switch (policy) {
      case 'on_app_exit':
        return 'On Exit';
      case 'after_15m':
        return '15 min';
      case 'after_1h':
        return '1 hour';
      case 'after_1d':
        return '1 day';
      case 'never':
      default:
        return 'Never';
    }
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.currentMode,
    required this.onChanged,
  });

  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return Padding(
      padding: const EdgeInsets.all(TxSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sunMedium, size: 20, color: colors.primary),
              const SizedBox(width: TxSpacing.md),
              Text(
                'Theme Mode',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
          const SizedBox(height: TxSpacing.sm),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: TxRadius.borderRadiusFull,
            ),
            child: Row(
              children: [
                _ThemeOption(
                  label: 'Light',
                  isSelected: currentMode == ThemeMode.light,
                  onTap: () => onChanged(ThemeMode.light),
                  colors: colors,
                ),
                _ThemeOption(
                  label: 'Dark',
                  isSelected: currentMode == ThemeMode.dark,
                  onTap: () => onChanged(ThemeMode.dark),
                  colors: colors,
                ),
                _ThemeOption(
                  label: 'System',
                  isSelected: currentMode == ThemeMode.system,
                  onTap: () => onChanged(ThemeMode.system),
                  colors: colors,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colors,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final TxColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TxPressable(
        onTap: onTap,
        scaleDown: 0.96,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : Colors.transparent,
            borderRadius: TxRadius.borderRadiusFull,
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected ? Colors.white : colors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClearDataSheet extends StatefulWidget {
  const _ClearDataSheet({required this.colors, required this.ref});

  final TxColorScheme colors;
  final WidgetRef ref;

  @override
  State<_ClearDataSheet> createState() => _ClearDataSheetState();
}

class _ClearDataSheetState extends State<_ClearDataSheet> {
  bool _history = true;
  bool _cookies = true;
  bool _cache = true;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(TxSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Clear Browsing Data',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: TxSpacing.xs),
            Text(
              'Select data categories to purge from your device.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: widget.colors.textSecondary,
                  ),
            ),
            const SizedBox(height: TxSpacing.md),
            CheckboxListTile(
              value: _history,
              onChanged: (v) => setState(() => _history = v ?? false),
              title: const Text('Browsing History'),
              activeColor: widget.colors.primary,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              value: _cookies,
              onChanged: (v) => setState(() => _cookies = v ?? false),
              title: const Text('Cookies & Site Data'),
              activeColor: widget.colors.primary,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              value: _cache,
              onChanged: (v) => setState(() => _cache = v ?? false),
              title: const Text('Cached Images & Files'),
              activeColor: widget.colors.primary,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: TxSpacing.md),
            TxButton(
              label: 'Clear Selected Data',
              variant: TxButtonVariant.destructive,
              isFullWidth: true,
              onPressed: () async {
                if (_history) {
                  widget.ref.read(historyProvider.notifier).clearAll();
                }
                if (_cookies) {
                  try {
                    await CookieManager.instance().deleteAllCookies();
                  } catch (_) {}
                }
                if (_cache) {
                  try {
                    await InAppWebViewController.clearAllCache();
                  } catch (_) {}
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  CacheCleanedDialog.show(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.hasData
            ? '${snapshot.data!.version}+${snapshot.data!.buildNumber}'
            : '1.0.0+1';
        return SettingsRow(
          icon: LucideIcons.info,
          title: 'Version',
          value: '$version (Production)',
        );
      },
    );
  }
}
