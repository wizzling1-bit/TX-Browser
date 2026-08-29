import 'package:flutter/material.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/url_utils.dart';
import '../glass_surface.dart';
import '../buttons/tx_pressable.dart';

/// Address bar / omnibox widget.
///
/// Features:
/// - Always-mounted [TextField] for instant native Android keyboard response.
/// - Unfocused: shows clean domain / page title with SSL lock icon and reload/stop action.
/// - Focused: selects all text for instant replacement, provides back/dismiss button,
///   one-tap clear (X) button, and dedicated search/go action.
/// - Real-time autocomplete query dispatching via [onQueryChanged].
class Omnibox extends StatefulWidget {
  const Omnibox({
    super.key,
    required this.url,
    required this.isLoading,
    required this.onSubmitted,
    required this.onReload,
    required this.onStop,
    this.onQueryChanged,
    this.onFocusChanged,
    this.controller,
  });

  final String url;
  final bool isLoading;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onReload;
  final VoidCallback onStop;
  final ValueChanged<String>? onQueryChanged;
  final ValueChanged<bool>? onFocusChanged;
  final TextEditingController? controller;

  @override
  State<Omnibox> createState() => _OmniboxState();
}

class _OmniboxState extends State<Omnibox> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController(text: widget.url);
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(Omnibox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update controller text from url if NOT focused by user
    if (!_isFocused && widget.url != oldWidget.url) {
      _controller.text = widget.url;
    }
  }

  void _onTextChanged() {
    if (_isFocused) {
      widget.onQueryChanged?.call(_controller.text);
    }
  }

  void _onFocusChange() {
    final hasFocus = _focusNode.hasFocus;
    setState(() {
      _isFocused = hasFocus;
      if (hasFocus) {
        // When focusing, populate with current full URL and select all text
        _controller.text = widget.url;
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
        widget.onQueryChanged?.call(_controller.text);
      }
    });
    widget.onFocusChanged?.call(hasFocus);
  }

  void _onSubmitted(String value) {
    final query = value.trim();
    if (query.isNotEmpty) {
      _focusNode.unfocus();
      widget.onSubmitted(query);
    }
  }

  void _showSecurityDetails(BuildContext context, bool isSecure) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final domain = UrlUtils.extractDomain(widget.url);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TxSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: TxSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (isSecure ? colors.success : colors.warning)
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSecure ? LucideIcons.lock : LucideIcons.shieldAlert,
                      size: 20,
                      color: isSecure ? colors.success : colors.warning,
                    ),
                  ),
                  const SizedBox(width: TxSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSecure ? 'Secure Connection' : 'Not Secure',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          domain.isNotEmpty ? domain : 'Local page',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TxSpacing.md),
              Text(
                isSecure
                    ? 'Your connection to this site is encrypted with HTTPS. Information you share (passwords, messages) is private.'
                    : 'This site does not use HTTPS encryption. Sensitive data may not be private.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
              ),
              const SizedBox(height: TxSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final isSecure = widget.url.isNotEmpty && UrlUtils.isSecure(widget.url);
    final domain = widget.url.isNotEmpty ? UrlUtils.extractDomain(widget.url) : '';
    final hasText = _controller.text.trim().isNotEmpty;

    return AnimatedContainer(
      duration: TxMotion.standardDuration,
      curve: TxMotion.standardCurve,
      height: _isFocused ? 48 : 44,
      child: GlassSurface(
        borderRadius: TxRadius.borderRadiusLg,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            // Leading Icon: Back / Cancel when focused, SSL Lock when idle
            if (_isFocused)
              TxPressable(
                onTap: () {
                  _focusNode.unfocus();
                  _controller.text = widget.url;
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    LucideIcons.chevronLeft,
                    size: 22,
                    color: colors.textPrimary,
                  ),
                ),
              )
            else
              TxPressable(
                onTap: widget.url.isNotEmpty
                    ? () => _showSecurityDetails(context, isSecure)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    isSecure ? LucideIcons.lock : LucideIcons.globe,
                    size: 18,
                    color: isSecure ? colors.success : colors.textSecondary,
                  ),
                ),
              ),

            const SizedBox(width: 4),

            // Omnibox Text Input (Always mounted for instant touch & keyboard focus)
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onSubmitted: _onSubmitted,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _isFocused
                              ? colors.textPrimary
                              : Colors.transparent, // Hide raw text when unfocused to show clean domain
                          fontWeight: FontWeight.w500,
                          fontSize: 14.5,
                        ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Search or enter web address',
                      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary.withValues(alpha: 0.7),
                            fontSize: 14.5,
                          ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    textInputAction: TextInputAction.go,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                  ),

                  // Clean Domain Display when idle & not focused
                  if (!_isFocused)
                    IgnorePointer(
                      child: Center(
                        child: Text(
                          domain.isEmpty ? 'Search or enter web address' : domain,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: domain.isEmpty
                                    ? colors.textSecondary.withValues(alpha: 0.7)
                                    : colors.textPrimary,
                                fontWeight: domain.isNotEmpty
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                fontSize: 14.5,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 4),

            // Trailing Actions:
            // When Focused: Clear (X) button + Submit/Search arrow button
            if (_isFocused) ...[
              if (hasText)
                TxPressable(
                  onTap: () {
                    _controller.clear();
                    widget.onQueryChanged?.call('');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      LucideIcons.x,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              if (hasText)
                TxPressable(
                  onTap: () => _onSubmitted(_controller.text),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.arrowRight,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
            ] else if (widget.isLoading)
              TxPressable(
                onTap: widget.onStop,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    LucideIcons.x,
                    size: 18,
                    color: colors.textPrimary,
                  ),
                ),
              )
            else if (widget.url.isNotEmpty)
              TxPressable(
                onTap: widget.onReload,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    LucideIcons.rotateCw,
                    size: 18,
                    color: colors.textPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
