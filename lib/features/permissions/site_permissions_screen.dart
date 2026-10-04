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
import '../../widgets/tx_snackbar.dart';

/// Provider for global default permission settings.
final defaultPermissionsProvider =
    FutureProvider.autoDispose<Map<String, SitePermissionState>>((ref) async {
  final service = ref.watch(sitePermissionServiceProvider);
  final camera = await service.getDefaultPermission('camera');
  final mic = await service.getDefaultPermission('microphone');
  final loc = await service.getDefaultPermission('location');
  final notif = await service.getDefaultPermission('notification');
  return {
    'camera': camera,
    'microphone': mic,
    'location': loc,
    'notification': notif,
  };
});

/// Comprehensive commercial screen for viewing and managing per-website device permissions
/// and global permission policies.
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

  String _formatPermLabel(String type) {
    switch (type) {
      case 'camera':
        return 'Camera';
      case 'microphone':
        return 'Microphone';
      case 'location':
        return 'Location';
      case 'notification':
        return 'Notifications';
      default:
        return type.isNotEmpty ? (type[0].toUpperCase() + type.substring(1)) : type;
    }
  }

  String _formatStateLabel(SitePermissionState state) {
    switch (state) {
      case SitePermissionState.allow:
        return 'Allowed';
      case SitePermissionState.block:
        return 'Blocked';
      case SitePermissionState.ask:
        return 'Ask every time';
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: TxSpacing.lg, vertical: TxSpacing.xs),
                child: Row(
                  children: [
                    Icon(_getPermIcon(type), color: colors.primary, size: 20),
                    const SizedBox(width: TxSpacing.sm),
                    Expanded(
                      child: Text(
                        '$host — ${_formatPermLabel(type)}',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TxSpacing.sm),
              ListTile(
                leading: Icon(LucideIcons.checkCircle, color: colors.success),
                title: const Text('Allow'),
                subtitle: const Text('Website can access without prompting'),
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
                subtitle: const Text('Always prompt before granting access'),
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
                subtitle: const Text('Requests will be automatically denied'),
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
              const Divider(),
              ListTile(
                leading: Icon(LucideIcons.trash2, color: colors.textTertiary),
                title: Text(
                  'Remove Custom Rule',
                  style: TextStyle(color: colors.error),
                ),
                onTap: () {
                  ref.read(sitePermissionServiceProvider).deletePermission(
                        host: host,
                        permissionType: type,
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

  void _showEditDefaultDialog(
    BuildContext context,
    WidgetRef ref,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: TxSpacing.lg, vertical: TxSpacing.xs),
                child: Row(
                  children: [
                    Icon(_getPermIcon(type), color: colors.primary, size: 20),
                    const SizedBox(width: TxSpacing.sm),
                    Expanded(
                      child: Text(
                        'Default ${_formatPermLabel(type)} Permission',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TxSpacing.sm),
              ListTile(
                leading: Icon(LucideIcons.helpCircle, color: colors.warning),
                title: const Text('Ask every time (Recommended)'),
                subtitle: const Text('Sites must ask before accessing'),
                trailing: currentState == SitePermissionState.ask
                    ? Icon(LucideIcons.check, color: colors.primary)
                    : null,
                onTap: () async {
                  await ref.read(sitePermissionServiceProvider).setDefaultPermission(
                        type,
                        SitePermissionState.ask,
                      );
                  ref.invalidate(defaultPermissionsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.slash, color: colors.error),
                title: const Text('Block by default'),
                subtitle: const Text('Automatically deny requests for all sites'),
                trailing: currentState == SitePermissionState.block
                    ? Icon(LucideIcons.check, color: colors.primary)
                    : null,
                onTap: () async {
                  await ref.read(sitePermissionServiceProvider).setDefaultPermission(
                        type,
                        SitePermissionState.block,
                      );
                  ref.invalidate(defaultPermissionsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.checkCircle, color: colors.success),
                title: const Text('Allow by default'),
                subtitle: const Text('Automatically allow for all sites (Not recommended)'),
                trailing: currentState == SitePermissionState.allow
                    ? Icon(LucideIcons.check, color: colors.primary)
                    : null,
                onTap: () async {
                  await ref.read(sitePermissionServiceProvider).setDefaultPermission(
                        type,
                        SitePermissionState.allow,
                      );
                  ref.invalidate(defaultPermissionsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddExceptionDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final hostCtrl = TextEditingController();
    String selectedType = 'camera';
    SitePermissionState selectedState = SitePermissionState.allow;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + TxSpacing.lg,
              left: TxSpacing.lg,
              right: TxSpacing.lg,
              top: TxSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  'Add Website Exception',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                ),
                const SizedBox(height: TxSpacing.xs),
                Text(
                  'Set a custom device permission rule for a specific domain.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                ),
                const SizedBox(height: TxSpacing.md),
                TextField(
                  controller: hostCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Website Domain',
                    hintText: 'e.g. google.com or meet.jit.si',
                    prefixIcon: const Icon(LucideIcons.globe, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: TxRadius.borderRadiusSm,
                    ),
                  ),
                ),
                const SizedBox(height: TxSpacing.md),
                Text(
                  'Permission Type',
                  style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'camera',
                    'microphone',
                    'location',
                    'notification',
                  ].map((t) {
                    final isSel = selectedType == t;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getPermIcon(t), size: 14),
                          const SizedBox(width: 4),
                          Text(_formatPermLabel(t)),
                        ],
                      ),
                      selected: isSel,
                      onSelected: (val) {
                        if (val) setModalState(() => selectedType = t);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: TxSpacing.md),
                Text(
                  'Action',
                  style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Allow')),
                        selected: selectedState == SitePermissionState.allow,
                        onSelected: (val) {
                          if (val) {
                            setModalState(() => selectedState = SitePermissionState.allow);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Block')),
                        selected: selectedState == SitePermissionState.block,
                        onSelected: (val) {
                          if (val) {
                            setModalState(() => selectedState = SitePermissionState.block);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Ask')),
                        selected: selectedState == SitePermissionState.ask,
                        onSelected: (val) {
                          if (val) {
                            setModalState(() => selectedState = SitePermissionState.ask);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TxSpacing.lg),
                TxButton(
                  label: 'Save Rule',
                  isFullWidth: true,
                  onPressed: () async {
                    final raw = hostCtrl.text.trim();
                    if (raw.isEmpty) {
                      TxSnackbar.show(ctx, 'Please enter a website domain', isError: true);
                      return;
                    }
                    await ref.read(sitePermissionServiceProvider).setPermissionState(
                          host: raw,
                          permissionType: selectedType,
                          state: selectedState,
                        );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      TxSnackbar.show(
                        context,
                        'Rule saved for $raw',
                        icon: LucideIcons.checkCircle,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResetAllConfirm(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset All Permissions?',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'All custom site rules will be cleared and reset to default values.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          TxButton(
            label: 'Reset All',
            variant: TxButtonVariant.destructive,
            onPressed: () async {
              await ref.read(sitePermissionServiceProvider).clearAllPermissions();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                TxSnackbar.show(context, 'All site permissions cleared');
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final permissionsAsync = ref.watch(allSitePermissionsStreamProvider);
    final defaultsAsync = ref.watch(defaultPermissionsProvider);

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
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.plus),
              tooltip: 'Add Website Exception',
              onPressed: () => _showAddExceptionDialog(context, ref),
            ),
            permissionsAsync.maybeWhen(
              data: (perms) => perms.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 20),
                      tooltip: 'Clear All',
                      onPressed: () => _showResetAllConfirm(context, ref),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        body: SafeArea(
          child: TxResponsiveContainer(
            maxWidth: 720,
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(TxSpacing.md),
              children: [
                // ─── INFO BANNER ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(TxSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: TxRadius.borderRadiusMd,
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.shieldCheck, color: colors.primary, size: 24),
                      const SizedBox(width: TxSpacing.md),
                      Expanded(
                        child: Text(
                          'Websites must ask for permission to access hardware features. All choices are stored locally on your device.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                                height: 1.4,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: TxSpacing.lg),

                // ─── SECTION 1: GLOBAL DEFAULTS ──────────────────────
                Text(
                  'Default Permissions',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Applied when visiting any new website.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textTertiary,
                      ),
                ),
                const SizedBox(height: TxSpacing.sm),

                defaultsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (defaults) {
                    final types = ['camera', 'microphone', 'location', 'notification'];
                    return Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: TxRadius.borderRadiusMd,
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: types.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final t = entry.value;
                          final state = defaults[t] ?? SitePermissionState.ask;
                          final isLast = idx == types.length - 1;

                          Color stateColor = colors.warning;
                          if (state == SitePermissionState.allow) {
                            stateColor = colors.success;
                          } else if (state == SitePermissionState.block) {
                            stateColor = colors.error;
                          }

                          return Column(
                            children: [
                              ListTile(
                                leading: Icon(_getPermIcon(t), size: 20, color: colors.primary),
                                title: Text(
                                  _formatPermLabel(t),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                subtitle: Text(
                                  _formatStateLabel(state),
                                  style: TextStyle(color: stateColor, fontSize: 13),
                                ),
                                trailing: const Icon(LucideIcons.chevronRight, size: 16),
                                onTap: () => _showEditDefaultDialog(context, ref, t, state),
                              ),
                              if (!isLast) const Divider(height: 1),
                            ],
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: TxSpacing.xl),

                // ─── SECTION 2: SITE EXCEPTIONS ──────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Site Exceptions',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddExceptionDialog(context, ref),
                      icon: const Icon(LucideIcons.plus, size: 14),
                      label: const Text('Add Rule'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TxSpacing.xs),

                permissionsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Text('Error loading permissions: $err'),
                  ),
                  data: (perms) {
                    if (perms.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TxSpacing.lg,
                          vertical: TxSpacing.xl,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: TxRadius.borderRadiusMd,
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              LucideIcons.shieldCheck,
                              size: 36,
                              color: colors.textTertiary,
                            ),
                            const SizedBox(height: TxSpacing.sm),
                            Text(
                              'No Custom Site Exceptions',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Websites that prompt for Camera, Mic, or Location will appear here. Or tap "Add Rule" to configure a site in advance.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.textSecondary,
                                  ),
                            ),
                            const SizedBox(height: TxSpacing.md),
                            TxButton(
                              label: 'Add Website Rule',
                              variant: TxButtonVariant.secondary,
                              onPressed: () => _showAddExceptionDialog(context, ref),
                            ),
                          ],
                        ),
                      );
                    }

                    // Group permissions by host
                    final map = <String, List<dynamic>>{};
                    for (final p in perms) {
                      map.putIfAbsent(p.host, () => []).add(p);
                    }
                    final hosts = map.keys.toList();

                    return Column(
                      children: hosts.map((host) {
                        final hostPerms = map[host]!;

                        return Container(
                          margin: const EdgeInsets.only(bottom: TxSpacing.md),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: TxRadius.borderRadiusMd,
                            border: Border.all(color: colors.border),
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
                                        ref
                                            .read(sitePermissionServiceProvider)
                                            .resetHostPermissions(host);
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
                                    _formatPermLabel(p.permissionType),
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
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
