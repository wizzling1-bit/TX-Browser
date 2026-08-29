import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/shapes.dart';
import '../../services/proxy_service/proxy_service.dart';
import '../../state/proxy_provider.dart';
import '../../widgets/buttons/tx_button.dart';
import '../../widgets/proxy_status_card.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/responsive/tx_responsive_container.dart';

/// Screen for configuring and controlling native HTTP/SOCKS proxy.
class ProxyScreen extends ConsumerStatefulWidget {
  const ProxyScreen({super.key});

  @override
  ConsumerState<ProxyScreen> createState() => _ProxyScreenState();
}

class _ProxyScreenState extends ConsumerState<ProxyScreen> {
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _userCtrl;
  late TextEditingController _passCtrl;
  late ProxyProtocol _selectedProtocol;
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    final proxy = ref.read(proxyProvider);
    _hostCtrl = TextEditingController(text: proxy.host);
    _portCtrl = TextEditingController(text: proxy.port.toString());
    _userCtrl = TextEditingController(text: proxy.username);
    _passCtrl = TextEditingController(text: proxy.password);
    _selectedProtocol = proxy.protocol;
    _isEnabled = proxy.isEnabled;
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _onSave() async {
    final port = int.tryParse(_portCtrl.text) ?? 8080;
    await ref.read(proxyProvider.notifier).saveConfig(
          enabled: _isEnabled,
          host: _hostCtrl.text.trim(),
          port: port,
          protocol: _selectedProtocol,
          username: _userCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEnabled ? 'Proxy configuration enabled & applied' : 'Proxy disabled'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final proxyState = ref.watch(proxyProvider);

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
        title: const Text('Proxy Configuration'),
      ),
      body: SafeArea(
        child: TxResponsiveContainer(
          maxWidth: 680,
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(TxSpacing.lg),
            children: [
              // Status Card
              ProxyStatusCard(
                isEnabled: proxyState.isEnabled,
                host: proxyState.host,
                port: proxyState.port,
                protocol: proxyState.protocol,
                isTesting: proxyState.isTesting,
                latencyMs: proxyState.latencyMs,
                lastTestSuccess: proxyState.lastTestSuccess,
                onTestConnection: () {
                  ref.read(proxyProvider.notifier).testCurrentConnection();
                },
              ),

              const SizedBox(height: TxSpacing.lg),

              // Master Toggle
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: TxSpacing.md,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: TxRadius.borderRadiusMd,
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.power, size: 20, color: colors.primary),
                        const SizedBox(width: TxSpacing.md),
                        Text(
                          'Enable Proxy',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isEnabled,
                      onChanged: (v) => setState(() => _isEnabled = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: TxSpacing.lg),

              // Configuration Form Card
              Container(
                padding: const EdgeInsets.all(TxSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: TxRadius.borderRadiusMd,
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server Settings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: TxSpacing.md),

                    // Protocol Selector
                    Text(
                      'Protocol',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: TxSpacing.xs),
                    Wrap(
                      spacing: TxSpacing.sm,
                      children: ProxyProtocol.values.map((p) {
                        final isSelected = p == _selectedProtocol;
                        return ChoiceChip(
                          label: Text(p.name.toUpperCase()),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedProtocol = p);
                          },
                          selectedColor: colors.primary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: isSelected ? colors.primary : colors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: TxSpacing.md),

                    // Host & Port Row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _hostCtrl,
                            decoration: InputDecoration(
                              labelText: 'Host / IP Address',
                              hintText: '192.168.1.1',
                              border: OutlineInputBorder(
                                borderRadius: TxRadius.borderRadiusSm,
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: TxSpacing.md),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _portCtrl,
                            decoration: InputDecoration(
                              labelText: 'Port',
                              hintText: '8080',
                              border: OutlineInputBorder(
                                borderRadius: TxRadius.borderRadiusSm,
                              ),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: TxSpacing.md),

                    // Username & Password
                    TextField(
                      controller: _userCtrl,
                      decoration: InputDecoration(
                        labelText: 'Username (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: TxRadius.borderRadiusSm,
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: TxSpacing.md),
                    TextField(
                      controller: _passCtrl,
                      decoration: InputDecoration(
                        labelText: 'Password (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: TxRadius.borderRadiusSm,
                        ),
                        isDense: true,
                      ),
                      obscureText: true,
                    ),

                    const SizedBox(height: TxSpacing.lg),

                    PremiumButton(
                      label: 'Save & Apply',
                      icon: LucideIcons.check,
                      isFullWidth: true,
                      onPressed: _onSave,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: TxSpacing.lg),

              // Traffic Isolation Explanation Card
              Container(
                padding: const EdgeInsets.all(TxSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: TxRadius.borderRadiusMd,
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.info,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: TxSpacing.md),
                    Expanded(
                      child: Text(
                        'Tx Browser routes WebView HTTP/SOCKS requests directly through this proxy at the native engine level. Local device network traffic outside the browser remains unaffected.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                              height: 1.4,
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: TxSpacing.xl),
            ],
          ),
        ),
      ),
    ),
  );
}
}
