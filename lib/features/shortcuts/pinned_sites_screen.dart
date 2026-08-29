import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/shapes.dart';
import '../../state/shortcuts_provider.dart';
import '../../widgets/buttons/tx_button.dart';
import '../../widgets/brand_icons.dart';
import '../../widgets/responsive/tx_responsive_container.dart';

/// Screen for managing, editing, reordering, and adding pinned quick-access shortcuts.
class PinnedSitesScreen extends ConsumerWidget {
  const PinnedSitesScreen({super.key});

  void _showEditSheet(BuildContext context, WidgetRef ref, ShortcutModel shortcut) {
    final labelCtrl = TextEditingController(text: shortcut.label);
    final urlCtrl = TextEditingController(text: shortcut.url);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: TxRadius.borderRadiusSheet,
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + TxSpacing.lg,
          left: TxSpacing.lg,
          right: TxSpacing.lg,
          top: TxSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit Shortcut',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: TxSpacing.md),
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(
                  borderRadius: TxRadius.borderRadiusSm,
                ),
              ),
            ),
            const SizedBox(height: TxSpacing.md),
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: 'URL',
                border: OutlineInputBorder(
                  borderRadius: TxRadius.borderRadiusSm,
                ),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: TxSpacing.lg),
            TxButton(
              label: 'Save Changes',
              isFullWidth: true,
              onPressed: () {
                if (labelCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
                  ref.read(shortcutsProvider.notifier).updateShortcut(
                        id: shortcut.id,
                        label: labelCtrl.text,
                        url: urlCtrl.text,
                      );
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    final labelCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: TxRadius.borderRadiusSheet,
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + TxSpacing.lg,
          left: TxSpacing.lg,
          right: TxSpacing.lg,
          top: TxSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Pinned Site',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: TxSpacing.md),
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. GitHub',
                border: OutlineInputBorder(
                  borderRadius: TxRadius.borderRadiusSm,
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: TxSpacing.md),
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'https://github.com',
                border: OutlineInputBorder(
                  borderRadius: TxRadius.borderRadiusSm,
                ),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: TxSpacing.lg),
            TxButton(
              label: 'Add Shortcut',
              isFullWidth: true,
              onPressed: () {
                if (labelCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
                  ref.read(shortcutsProvider.notifier).addShortcut(
                        label: labelCtrl.text,
                        url: urlCtrl.text,
                      );
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final shortcuts = ref.watch(shortcutsProvider);

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
        title: const Text('Pinned Sites'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus, size: 20),
            tooltip: 'Add Shortcut',
            onPressed: () => _showAddSheet(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: TxResponsiveContainer(
          maxWidth: 720,
          child: shortcuts.isEmpty
              ? Center(
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
                          LucideIcons.bookmark,
                          size: 32,
                          color: colors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: TxSpacing.md),
                      Text(
                        'No Pinned Sites',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pin your frequently used websites for quick access.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: TxSpacing.lg),
                      TxButton(
                        label: 'Add Shortcut',
                        icon: LucideIcons.plus,
                        onPressed: () => _showAddSheet(context, ref),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(TxSpacing.lg),
                  itemCount: shortcuts.length,
                  // ignore: deprecated_member_use
                  onReorder: (oldIndex, newIndex) {
                    ref
                        .read(shortcutsProvider.notifier)
                        .reorderShortcuts(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final shortcut = shortcuts[index];
                    return Container(
                      key: Key(shortcut.id),
                      margin: const EdgeInsets.only(bottom: TxSpacing.sm),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: TxRadius.borderRadiusSm,
                        border: Border.all(color: colors.border, width: 1),
                      ),
                      child: ListTile(
                        leading: BrandIconBadge(
                          name: shortcut.label,
                          size: 36,
                          borderRadius: 10,
                        ),
                        title: Text(
                          shortcut.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          shortcut.url,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                LucideIcons.filePenLine,
                                size: 18,
                                color: colors.textSecondary,
                              ),
                              onPressed: () =>
                                  _showEditSheet(context, ref, shortcut),
                            ),
                            IconButton(
                              icon: Icon(
                                LucideIcons.trash2,
                                size: 18,
                                color: colors.error,
                              ),
                              onPressed: () {
                                ref
                                    .read(shortcutsProvider.notifier)
                                    .removeShortcut(shortcut.id);
                              },
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: Icon(
                                LucideIcons.gripVertical,
                                size: 20,
                                color: colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    ),
  );
}
}
