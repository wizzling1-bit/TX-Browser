import 'package:flutter/material.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../services/suggestion_service/suggestion_model.dart';
import '../ads/tx_native_ad_card.dart';
import '../buttons/tx_pressable.dart';

/// Autocomplete suggestions dropdown panel for Tx Browser search bar.
class SearchSuggestionsPanel extends StatelessWidget {
  const SearchSuggestionsPanel({
    super.key,
    required this.suggestions,
    required this.isLoading,
    required this.onSelect,
    required this.onInsert,
  });

  final List<SearchSuggestion> suggestions;
  final bool isLoading;
  final ValueChanged<SearchSuggestion> onSelect;
  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty && !isLoading) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TxRadius.borderRadiusLg,
        border: Border.all(
          color: colors.border.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: TxElevation.elevation2,
      ),
      child: ClipRRect(
        borderRadius: TxRadius.borderRadiusLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              LinearProgressIndicator(
                minHeight: 2,
                color: colors.primary,
                backgroundColor: colors.primary.withValues(alpha: 0.1),
              ),
            for (var i = 0; i < suggestions.length; i++) ...[
              _SuggestionRow(
                suggestion: suggestions[i],
                onTap: () => onSelect(suggestions[i]),
                onInsert: () => onInsert(
                  suggestions[i].type == SuggestionType.urlMatch
                      ? suggestions[i].url
                      : suggestions[i].title,
                ),
                colors: colors,
              ),
              if (i < suggestions.length - 1)
                Divider(
                  height: 1,
                  thickness: 0.8,
                  indent: 52,
                  endIndent: TxSpacing.md,
                  color: colors.borderSubtle,
                ),
            ],
            if (suggestions.isNotEmpty) ...[
              Divider(
                height: 1,
                thickness: 0.8,
                color: colors.borderSubtle,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: TxNativeAdCard(
                  variant: TxAdSizeVariant.standardBanner,
                  margin: EdgeInsets.zero,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.suggestion,
    required this.onTap,
    required this.onInsert,
    required this.colors,
  });

  final SearchSuggestion suggestion;
  final VoidCallback onTap;
  final VoidCallback onInsert;
  final TxColorScheme colors;

  IconData _getIcon() {
    switch (suggestion.type) {
      case SuggestionType.urlMatch:
        return LucideIcons.globe;
      case SuggestionType.history:
        return LucideIcons.history;
      case SuggestionType.pinned:
        return LucideIcons.bookmark;
      case SuggestionType.searchEngine:
      case SuggestionType.remoteSuggestion:
        return LucideIcons.search;
    }
  }

  Color _getIconBg() {
    switch (suggestion.type) {
      case SuggestionType.urlMatch:
        return colors.primary.withValues(alpha: 0.15);
      case SuggestionType.pinned:
        return colors.secondary.withValues(alpha: 0.2);
      case SuggestionType.history:
      case SuggestionType.searchEngine:
      case SuggestionType.remoteSuggestion:
        return colors.surfaceAlt;
    }
  }

  Color _getIconColor() {
    switch (suggestion.type) {
      case SuggestionType.urlMatch:
        return colors.primary;
      case SuggestionType.pinned:
        return colors.primary;
      case SuggestionType.history:
      case SuggestionType.searchEngine:
      case SuggestionType.remoteSuggestion:
        return colors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFavicon =
        suggestion.faviconUrl != null && suggestion.faviconUrl!.isNotEmpty;

    return TxPressable(
      onTap: onTap,
      scaleDown: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TxSpacing.md,
          vertical: 10,
        ),
        child: Row(
          children: [
            // Leading Badge / Favicon
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _getIconBg(),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: hasFavicon
                    ? Image.network(
                        suggestion.faviconUrl!,
                        width: 18,
                        height: 18,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          _getIcon(),
                          size: 16,
                          color: _getIconColor(),
                        ),
                      )
                    : Icon(
                        _getIcon(),
                        size: 16,
                        color: _getIconColor(),
                      ),
              ),
            ),

            const SizedBox(width: TxSpacing.md),

            // Title and Subtitle / Domain
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    suggestion.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (suggestion.domain != null || suggestion.subtitle != null) ...[
                    const SizedBox(height: 1.5),
                    Text(
                      suggestion.domain ?? suggestion.subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11.5,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Trailing Insert arrow button
            TxPressable(
              onTap: onInsert,
              scaleDown: 0.85,
              child: Container(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  LucideIcons.arrowUpLeft,
                  size: 16,
                  color: colors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
