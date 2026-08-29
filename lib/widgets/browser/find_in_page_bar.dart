import 'package:flutter/material.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../buttons/tx_button.dart';

/// Production Find in Page Bar for InAppWebView.
///
/// Features:
/// - Real-time keyword search
/// - Match counter (e.g. "2 / 18")
/// - Next / Previous match navigation
/// - Clear input and dismiss actions
class FindInPageBar extends StatefulWidget {
  const FindInPageBar({
    super.key,
    required this.onSearch,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
    this.currentMatchIndex = 0,
    this.totalMatches = 0,
  });

  final ValueChanged<String> onSearch;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;
  final int currentMatchIndex;
  final int totalMatches;

  @override
  State<FindInPageBar> createState() => _FindInPageBarState();
}

class _FindInPageBarState extends State<FindInPageBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: TxSpacing.md, vertical: TxSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: TxSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TxRadius.borderRadiusMd,
        border: Border.all(color: colors.border, width: 1),
        boxShadow: TxElevation.elevation2,
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 18, color: colors.primary),
          const SizedBox(width: TxSpacing.sm),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: (text) => widget.onSearch(text),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => widget.onNext(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
              decoration: InputDecoration(
                hintText: 'Find in page...',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textTertiary,
                    ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty) ...[
            // Match Count Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.totalMatches > 0
                    ? '${widget.currentMatchIndex + 1} / ${widget.totalMatches}'
                    : '0 / 0',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: widget.totalMatches > 0
                          ? colors.primary
                          : colors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(width: 4),
            // Previous match
            TxIconButton(
              icon: LucideIcons.chevronUp,
              size: 18,
              semanticLabel: 'Previous Match',
              isEnabled: widget.totalMatches > 0,
              onPressed: widget.onPrevious,
            ),
            // Next match
            TxIconButton(
              icon: LucideIcons.chevronDown,
              size: 18,
              semanticLabel: 'Next Match',
              isEnabled: widget.totalMatches > 0,
              onPressed: widget.onNext,
            ),
            // Clear input
            TxIconButton(
              icon: LucideIcons.x,
              size: 16,
              semanticLabel: 'Clear Search',
              onPressed: () {
                _controller.clear();
                widget.onSearch('');
              },
            ),
          ],
          // Close Find Bar
          TxIconButton(
            icon: LucideIcons.check,
            size: 18,
            semanticLabel: 'Close Find in Page',
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }
}
