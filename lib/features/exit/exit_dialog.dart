import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../services/ad_service/ad_service.dart';
import '../../state/history_provider.dart';
import '../../state/tabs_provider.dart';
import '../../widgets/buttons/tx_button.dart';
import '../../widgets/buttons/tx_pressable.dart';

/// Shows the premium Tx Browser Exit Confirmation Modal Bottom Sheet.
Future<bool?> showTxExitDialog(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ExitConfirmationSheet(ref: ref),
  );
}

class _ExitConfirmationSheet extends StatefulWidget {
  const _ExitConfirmationSheet({required this.ref});

  final WidgetRef ref;

  @override
  State<_ExitConfirmationSheet> createState() => _ExitConfirmationSheetState();
}

class _ExitConfirmationSheetState extends State<_ExitConfirmationSheet> {
  bool _clearHistoryOnExit = false;
  bool _isExiting = false;

  Future<void> _performExit() async {
    setState(() => _isExiting = true);

    try {
      if (_clearHistoryOnExit) {
        await widget.ref.read(historyProvider.notifier).clearAll();
      }

      // Persist regular tabs and purge private tabs per security specs
      await widget.ref.read(tabsProvider.notifier).persistTabs();

      // Show interstitial if frequency caps allow, then exit
      final adService = widget.ref.read(adServiceProvider);
      final didShow = adService.maybeShowInterstitial(
        onDismissed: () => SystemNavigator.pop(),
      );
      if (!didShow) {
        await SystemNavigator.pop();
      }
    } catch (_) {
      // Fallback exit
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final tabState = widget.ref.watch(tabsProvider);
    final regularTabsCount = tabState.tabs.where((t) => !t.isPrivate).length;
    final privateTabsCount = tabState.tabs.where((t) => t.isPrivate).length;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.7),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.only(
              left: TxSpacing.xl,
              right: TxSpacing.xl,
              top: TxSpacing.md,
              bottom: MediaQuery.of(context).viewInsets.bottom + TxSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              // ─── DRAG HANDLE ───────────────────────────────────────
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              const SizedBox(height: TxSpacing.lg),

              // ─── BRAND HERO ICON ───────────────────────────────────
              Container(
                width: 64,
                height: 64,
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
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.power,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: TxSpacing.md),

              // ─── HEADLINE & SUBTITLE ───────────────────────────────
              Text(
                'Exit TX Browser?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: TxSpacing.xs),

              Text(
                'Your session will be saved. Private tabs and temp cache can be purged securely.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      height: 1.35,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: TxSpacing.lg),

              // ─── SESSION SUMMARY CARD ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(TxSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: TxRadius.borderRadiusMd,
                  border: Border.all(
                    color: colors.borderSubtle,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Regular Tabs info
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            LucideIcons.layers,
                            size: 16,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: TxSpacing.md),
                        Expanded(
                          child: Text(
                            '$regularTabsCount active open ${regularTabsCount == 1 ? 'tab' : 'tabs'}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                          ),
                        ),
                        Text(
                          'Preserved',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),

                    if (privateTabsCount > 0) ...[
                      const SizedBox(height: TxSpacing.sm),
                      Divider(color: colors.borderSubtle, height: 1),
                      const SizedBox(height: TxSpacing.sm),
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: colors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              LucideIcons.shieldCheck,
                              size: 16,
                              color: colors.warning,
                            ),
                          ),
                          const SizedBox(width: TxSpacing.md),
                          Expanded(
                            child: Text(
                              '$privateTabsCount private ${privateTabsCount == 1 ? 'tab' : 'tabs'}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                            ),
                          ),
                          Text(
                            'Will Purge',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: colors.warning,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: TxSpacing.sm),
                    Divider(color: colors.borderSubtle, height: 1),
                    const SizedBox(height: TxSpacing.xs),

                    // Clear history on exit checkbox
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
                                'Clear browsing history & cache on exit',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
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

              const SizedBox(height: TxSpacing.lg),

              // ─── ACTION BUTTONS ────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: TxButton(
                      label: 'Cancel',
                      variant: TxButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(false),
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
    ),
  );
}
}
