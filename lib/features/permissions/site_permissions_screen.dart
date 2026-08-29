import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../services/permission_service/site_permission_service.dart';
import '../../state/site_permissions_provider.dart';
import '../../widgets/buttons/tx_button.dart';
import '../../widgets/responsive/tx_responsive_container.dart';

/// Screen for viewing and managing per-website device permissions.
class SitePermissionsScreen extends ConsumerWidget {
  const SitePermissionsScreen({super.key});

  IconData _getPermIcon(String type) {
    switch (type) {
      case 'camera':
        return LucideIcons.camera;
      case 'microphone':
        return LucideIcons.mic;
      case 'location':
        return LucideIcons.mapPin;
      case 'notification':
        return LucideIcons.bell;
      default:
        return LucideIcons.shield;
    }
  }

  void _showEditPermissionDialog(
    BuildContext context,
    WidgetRef ref,
    String host,
    String type,
    SitePermissionState currentState,
  ) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TxSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: TxSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                '$host - ${type.toUpperCase()}',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
              ),
              const SizedBox(height: TxSpacing.sm),
              ListTile(
                leading: Icon(LucideIcons.checkCircle, color: colors.success),
                title: const Text('Allow'),
                trailing: currentState == SitePermissionState.allow
                    ? Icon(LucideIcons.check, color: colors.primary)
                    : null,
                onTap: () {
                  ref.read(sitePermissionServiceProvider).setPermissionState(
                        host: host,
                        permissionType: type,
                        state: SitePermissionState.allow,
                      );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.helpCircle, color: colors.warning),
                title: const Text('Ask every time'),
                trailing: currentState == SitePermissionState.ask
                    ? Icon(LucideIcons.check, color: colors.primary)
                    : null,
                onTap: () {
                  ref.read(sitePermissionServiceProvider).setPermissionState(
                        host: host,
                        permissionType: type,
                        state: SitePermissionState.ask,
                      );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.slash, color: colors.error),
                title: const Text('Block'),
                trailing: currentState == SitePermissionState.block
                    ? Icon(LucideIcons.check, color: colors.primary)
                    : null,
                onTap: () {
                  ref.read(sitePermissionServiceProvider).setPermissionState(
                        host: host,
                        permissionType: type,
                        state: SitePermissionState.block,
                      );
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final permissionsAsync = ref.watch(allSitePermissionsStreamProvider);

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
          title: const Text('Website Permissions'),
        ),
        body: SafeArea(
          child: TxResponsiveContainer(
            maxWidth: 720,
            child: permissionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading permissions: $err')),
              data: (perms) {
                if (perms.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: colors.surfaceAlt,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.shieldCheck,
                            size: 32,
                            color: colors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: TxSpacing.md),
                        Text(
                          'No Site-Specific Permissions',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sites that request Camera, Mic, or Location will appear here.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Group by host
                final map = <String, List<dynamic>>{};
                for (final p in perms) {
                  map.putIfAbsent(p.host, () => []).add(p);
                }

                final hosts = map.keys.toList();

                return ListView.builder(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(TxSpacing.lg),
                  itemCount: hosts.length,
                  itemBuilder: (context, index) {
                    final host = hosts[index];
                    final hostPerms = map[host]!;

                    return Container(
                      margin: const EdgeInsets.only(bottom: TxSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: TxRadius.borderRadiusMd,
                        border: Border.all(color: colors.border, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: TxSpacing.md,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.globe, size: 18, color: colors.primary),
                                const SizedBox(width: TxSpacing.sm),
                                Expanded(
                                  child: Text(
                                    host,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: colors.textPrimary,
                                        ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(LucideIcons.trash2, size: 16),
                                  color: colors.textTertiary,
                                  tooltip: 'Reset host permissions',
                                  onPressed: () {
                                    ref.read(sitePermissionServiceProvider).resetHostPermissions(host);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ...hostPerms.map((p) {
                            final state = p.state == 'allow'
                                ? SitePermissionState.allow
                                : (p.state == 'block'
                                    ? SitePermissionState.block
                                    : SitePermissionState.ask);

                            Color stateColor;
                            String stateLabel;
                            if (state == SitePermissionState.allow) {
                              stateColor = colors.success;
                              stateLabel = 'Allowed';
                            } else if (state == SitePermissionState.block) {
                              stateColor = colors.error;
                              stateLabel = 'Blocked';
                            } else {
                              stateColor = colors.warning;
                              stateLabel = 'Ask';
                            }

                            return ListTile(
                              leading: Icon(_getPermIcon(p.permissionType), size: 18),
                              title: Text(
                                p.permissionType[0].toUpperCase() + p.permissionType.substring(1),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: stateColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      stateLabel,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: stateColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(LucideIcons.chevronRight, size: 16),
                                ],
                              ),
                              onTap: () => _showEditPermissionDialog(
                                context,
                                ref,
                                host,
                                p.permissionType,
                                state,
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
