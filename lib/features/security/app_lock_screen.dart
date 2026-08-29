import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/shapes.dart';
import '../../state/app_lock_provider.dart';
import '../../widgets/app_lock_view.dart';
import '../../widgets/buttons/tx_button.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/responsive/tx_responsive_container.dart';

/// App Lock settings and PIN setup/change manager.
class AppLockSettingsScreen extends ConsumerStatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  ConsumerState<AppLockSettingsScreen> createState() =>
      _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends ConsumerState<AppLockSettingsScreen> {
  void _startPinSetupFlow(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _PinSetupFlowScreen(),
      ),
    );
  }

  void _showTimeoutSelector(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final currentPolicy = ref.read(appLockProvider).timeoutPolicy;

    final options = [
      {'label': 'Immediately upon exit', 'value': 'immediately'},
      {'label': 'After 1 minute', 'value': '1_min'},
      {'label': 'After 5 minutes', 'value': '5_min'},
      {'label': 'After 15 minutes', 'value': '15_min'},
      {'label': 'Never auto-lock', 'value': 'never'},
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
                'Auto-Lock Timeout',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: TxSpacing.sm),
              ...options.map((opt) {
                final isSelected = opt['value'] == currentPolicy;
                return ListTile(
                  title: Text(opt['label']!),
                  trailing: isSelected
                      ? Icon(LucideIcons.check, color: colors.primary)
                      : null,
                  onTap: () {
                    ref
                        .read(appLockProvider.notifier)
                        .setTimeoutPolicy(opt['value']!);
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final lockState = ref.watch(appLockProvider);

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
        title: const Text('App Lock & Security'),
      ),
      body: SafeArea(
        child: TxResponsiveContainer(
          maxWidth: 680,
          child: ListView(
            physics: const ClampingScrollPhysics(),
            children: [
            // Status Hero Card
            Padding(
              padding: const EdgeInsets.all(TxSpacing.lg),
              child: Container(
                padding: const EdgeInsets.all(TxSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: TxRadius.borderRadiusMd,
                  border: Border.all(
                    color: lockState.isEnabled
                        ? colors.primary.withValues(alpha: 0.3)
                        : colors.border,
                    width: 1,
                  ),
                  boxShadow: TxElevation.elevation1,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: (lockState.isEnabled
                                ? colors.primary
                                : colors.textTertiary)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          lockState.isEnabled
                              ? LucideIcons.lock
                              : LucideIcons.unlock,
                          size: 24,
                          color: lockState.isEnabled
                              ? colors.primary
                              : colors.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: TxSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lockState.isEnabled
                                ? 'App Lock Active'
                                : 'App Lock Disabled',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lockState.isEnabled
                                ? 'PIN / Biometrics required to open browser'
                                : 'Protect your tabs and history with a PIN',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Controls
            SettingsSection(
              title: 'PROTECTION',
              children: [
                SettingsRow(
                  icon: LucideIcons.keyRound,
                  title: lockState.isEnabled ? 'Change PIN' : 'Set Up PIN',
                  subtitle: lockState.isEnabled
                      ? '4-digit security code'
                      : 'Create a 4-digit code to enable App Lock',
                  onTap: () => _startPinSetupFlow(context),
                ),
                if (lockState.isEnabled) ...[
                  SettingsRow(
                    icon: LucideIcons.fingerprint,
                    title: 'Biometric Unlock',
                    subtitle: 'Use Fingerprint / Face recognition',
                    trailing: Switch(
                      value: lockState.biometricsEnabled,
                      onChanged: (v) {
                        ref
                            .read(appLockProvider.notifier)
                            .setBiometricsEnabled(v);
                      },
                    ),
                  ),
                  SettingsRow(
                    icon: LucideIcons.timer,
                    title: 'Auto-Lock Timeout',
                    value: _formatPolicyLabel(lockState.timeoutPolicy),
                    onTap: () => _showTimeoutSelector(context),
                  ),
                  SettingsRow(
                    icon: LucideIcons.shieldOff,
                    title: 'Turn Off App Lock',
                    isDestructive: true,
                    onTap: () {
                      _showDisableConfirmation(context);
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  ),
);
}

  void _showDisableConfirmation(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable App Lock?'),
        content: const Text(
          'Your PIN and biometric preferences will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(appLockProvider.notifier).disableLock();
              Navigator.pop(ctx);
            },
            child: Text(
              'Disable',
              style: TextStyle(color: colors.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPolicyLabel(String policy) {
    switch (policy) {
      case 'immediately':
        return 'Immediately';
      case '1_min':
        return '1 minute';
      case '5_min':
        return '5 minutes';
      case '15_min':
        return '15 minutes';
      case 'never':
        return 'Never';
      default:
        return 'Immediately';
    }
  }
}

/// PIN Setup & Confirmation Flow Screen.
class _PinSetupFlowScreen extends ConsumerStatefulWidget {
  const _PinSetupFlowScreen();

  @override
  ConsumerState<_PinSetupFlowScreen> createState() =>
      _PinSetupFlowScreenState();
}

class _PinSetupFlowScreenState extends ConsumerState<_PinSetupFlowScreen> {
  String? _firstPin;
  bool _isConfirming = false;
  final _keypadKey = GlobalKey<State<AppLockView>>();

  void _handlePin(String pin) {
    if (!_isConfirming) {
      setState(() {
        _firstPin = pin;
        _isConfirming = true;
      });
    } else {
      if (pin == _firstPin) {
        ref.read(appLockProvider.notifier).setPin(pin);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App Lock configured successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PINs did not match. Please try again.')),
        );
        setState(() {
          _firstPin = null;
          _isConfirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLockView(
      key: _keypadKey,
      title: _isConfirming ? 'Confirm your PIN' : 'Create a 4-digit PIN',
      subtitle: _isConfirming
          ? 'Re-enter your 4-digit PIN to verify'
          : 'This PIN will be used to unlock TX Browser',
      onPinComplete: _handlePin,
    );
  }
}
