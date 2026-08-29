import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../state/history_provider.dart';
import '../../state/tabs_provider.dart';
import '../../widgets/buttons/tx_button.dart';
import '../../widgets/buttons/tx_pressable.dart';
import '../../widgets/responsive/tx_responsive_container.dart';

/// Full-screen Exit Page for Tx Browser.
class ExitScreen extends ConsumerStatefulWidget {
  const ExitScreen({super.key});

  @override
  ConsumerState<ExitScreen> createState() => _ExitScreenState();
}

class _ExitScreenState extends ConsumerState<ExitScreen> {
  bool _clearHistoryOnExit = false;
  bool _isExiting = false;

  Future<void> _performExit() async {
    setState(() => _isExiting = true);

    try {
      if (_clearHistoryOnExit) {
        await ref.read(historyProvider.notifier).clearAll();
      }

      await ref.read(tabsProvider.notifier).persistTabs();
      await SystemNavigator.pop();
    } catch (_) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final tabState = ref.watch(tabsProvider);
    final regularTabsCount = tabState.tabs.where((t) => !t.isPrivate).length;
    final privateTabsCount = tabState.tabs.where((t) => t.isPrivate).length;

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
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Center(
            child: TxResponsiveContainer(
              maxWidth: 480,
              padding: const EdgeInsets.symmetric(
                horizontal: TxSpacing.xl,
                vertical: TxSpacing.lg,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Spacer(),

                            // Brand Hero Emblem
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    colors.primary,
                                    colors.secondary,
                                  ],
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(44),
                                  topRight: Radius.circular(44),
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(44),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withValues(alpha: 0.35),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  LucideIcons.power,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            const SizedBox(height: TxSpacing.xl),

                            Text(
                              'Ready to Exit?',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: colors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                            ),

                            const SizedBox(height: TxSpacing.xs),

                            Text(
                              'TX Browser keeps your tabs saved for next time.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.textSecondary,
                                  ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: TxSpacing.xl),

                            // Session Summary Box
                            Container(
                              padding: const EdgeInsets.all(TxSpacing.lg),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: TxRadius.borderRadiusMd,
                                border: Border.all(color: colors.border, width: 1),
                                boxShadow: TxElevation.elevation1,
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(LucideIcons.layers, size: 20, color: colors.primary),
                                      const SizedBox(width: TxSpacing.md),
                                      Expanded(
                                        child: Text(
                                          '$regularTabsCount Saved ${regularTabsCount == 1 ? 'Tab' : 'Tabs'}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Ready on return',
                                        style: TextStyle(fontSize: 12, color: colors.primary),
                                      ),
                                    ],
                                  ),

                                  if (privateTabsCount > 0) ...[
                                    const SizedBox(height: TxSpacing.md),
                                    Divider(color: colors.borderSubtle, height: 1),
                                    const SizedBox(height: TxSpacing.md),
                                    Row(
                                      children: [
                                        Icon(LucideIcons.shieldCheck, size: 20, color: colors.warning),
                                        const SizedBox(width: TxSpacing.md),
                                        Expanded(
                                          child: Text(
                                            '$privateTabsCount Private ${privateTabsCount == 1 ? 'Tab' : 'Tabs'}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Will be wiped',
                                          style: TextStyle(fontSize: 12, color: colors.warning),
                                        ),
                                      ],
                                    ),
                                  ],

                                  const SizedBox(height: TxSpacing.md),
                                  Divider(color: colors.borderSubtle, height: 1),
                                  const SizedBox(height: TxSpacing.xs),

                                  TxPressable(
                                    onTap: () {
                                      setState(() {
                                        _clearHistoryOnExit = !_clearHistoryOnExit;
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: _clearHistoryOnExit,
                                            activeColor: colors.primary,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            onChanged: (val) {
                                              setState(() {
                                                _clearHistoryOnExit = val ?? false;
                                              });
                                            },
                                          ),
                                          Expanded(
                                            child: Text(
                                              'Clear session browsing history on exit',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: colors.textPrimary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),
                            const SizedBox(height: TxSpacing.md),

                            // Bottom Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: TxButton(
                                    label: 'Stay',
                                    variant: TxButtonVariant.secondary,
                                    onPressed: () {
                                      if (context.canPop()) {
                                        context.pop();
                                      } else {
                                        context.go('/');
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: TxSpacing.md),
                                Expanded(
                                  child: TxButton(
                                    label: _isExiting ? 'Exiting...' : 'Exit App',
                                    icon: LucideIcons.logOut,
                                    variant: TxButtonVariant.primary,
                                    onPressed: _isExiting ? null : _performExit,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
