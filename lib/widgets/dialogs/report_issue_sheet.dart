import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/tx_icons.dart';
import '../../state/shield_provider.dart';
import '../tx_snackbar.dart';

enum IssueCategory {
  brokenWebsite('BROKEN_WEBSITE', 'Broken Site', 'Layout or buttons broken'),
  adBlocker('AD_BLOCKER_ISSUE', 'TX Shield Issue', 'Site blocked or broken by blocker'),
  performance('PERFORMANCE', 'Slow / Lag', 'Page sluggish or heavy'),
  crashBug('CRASH_BUG', 'App Bug', 'Freeze, glitch, or unexpected reload'),
  featureRequest('FEATURE_REQUEST', 'Idea / Request', 'Feature you would like to see'),
  other('OTHER', 'General', 'Other questions or comments');

  const IssueCategory(this.apiKey, this.label, this.description);
  final String apiKey;
  final String label;
  final String description;
}

/// Minimal, elegant user feedback and "broken website" reporting sheet.
class ReportIssueSheet extends ConsumerStatefulWidget {
  const ReportIssueSheet({
    super.key,
    this.currentUrl,
    String? prefilledUrl,
  }) : _prefilled = prefilledUrl ?? currentUrl;

  final String? currentUrl;
  final String? _prefilled;

  /// Convenience helper to open the sheet from any context.
  static Future<void> show(BuildContext context, {String? currentUrl, String? prefilledUrl}) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReportIssueSheet(
        currentUrl: currentUrl,
        prefilledUrl: prefilledUrl,
      ),
    );
  }

  @override
  ConsumerState<ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends ConsumerState<ReportIssueSheet> {
  late final TextEditingController _urlController;
  late final TextEditingController _descController;
  IssueCategory _selectedCategory = IssueCategory.brokenWebsite;
  bool _includeDiagnostics = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget._prefilled ?? '');
    _descController = TextEditingController();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final description = _descController.text.trim();
    if (description.isEmpty) {
      TxSnackbar.show(
        context,
        'Please enter a short description',
        isError: true,
        icon: LucideIcons.alertCircle,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    String? deviceModel;
    String? androidVersion;
    String? appVersion;
    bool shieldActive = true;

    try {
      if (_includeDiagnostics) {
        final pkg = await PackageInfo.fromPlatform();
        appVersion = pkg.version;
        deviceModel = Platform.isAndroid ? 'Android Device' : Platform.operatingSystem;
        androidVersion = Platform.operatingSystemVersion;
        shieldActive = ref.read(shieldProvider).isGlobalEnabled;
      }

      final payload = {
        'category': _selectedCategory.apiKey,
        'targetUrl': _urlController.text.trim().isNotEmpty ? _urlController.text.trim() : null,
        'description': description,
        'deviceModel': deviceModel,
        'androidVersion': androidVersion,
        'appVersion': appVersion,
        'shieldEnabled': shieldActive,
      };

      // 1. Dispatched to TX Browser cloud API
      bool apiSuccess = false;
      try {
        final uri = Uri.parse('https://txbrowser.com/api/v1/feedback');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 4));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          apiSuccess = true;
        }
      } catch (_) {}

      // 2. Direct Supabase Cloud Serverless Fallback
      if (!apiSuccess) {
        try {
          const anonKey =
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpZHJicmt5dmNhamFiZHl5Y21xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMjAzNjEsImV4cCI6MjEwNTg5NjM2MX0.0VyAmmu65b5aiduXDbG4eDAAYYXJGky5S5ooHJ9A0sQ';
          final supabaseUri = Uri.parse(
              'https://vidrbrkyvcajabdyycmq.supabase.co/rest/v1/user_feedbacks');
          await http.post(
            supabaseUri,
            headers: {
              'apikey': anonKey,
              'Authorization': 'Bearer $anonKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'id': 'fb_${DateTime.now().millisecondsSinceEpoch}',
              'category': _selectedCategory.apiKey,
              'target_url': _urlController.text.trim().isNotEmpty
                  ? _urlController.text.trim()
                  : null,
              'description': description,
              'device_model': deviceModel,
              'android_version': androidVersion,
              'app_version': appVersion,
              'shield_enabled': shieldActive,
              'status': 'NEW',
            }),
          ).timeout(const Duration(seconds: 5));
        } catch (_) {}
      }
    } catch (_) {
      // Safe graceful delivery fallback
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).pop();

    TxSnackbar.show(
      context,
      'Report submitted. Thank you for helping improve TX Browser!',
      icon: LucideIcons.check,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: colors.borderSubtle)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.primary.withValues(alpha: 0.24)),
                  ),
                  child: Icon(LucideIcons.messageSquare, size: 18, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report an Issue',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Help us fix broken sites & improve browsing',
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(LucideIcons.x, size: 20, color: colors.textTertiary),
                  splashRadius: 18,
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Category Selection Pills
            Text(
              'ISSUE TYPE',
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: IssueCategory.values.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat);
                    }
                  },
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? colors.primary : colors.textSecondary,
                  ),
                  selectedColor: colors.primary.withValues(alpha: 0.15),
                  backgroundColor: colors.surface,
                  side: BorderSide(
                    color: isSelected ? colors.primary : colors.borderSubtle,
                    width: isSelected ? 1.4 : 1.0,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Target URL (if present)
            if (_urlController.text.isNotEmpty) ...[
              Text(
                'WEBSITE URL',
                style: TextStyle(
                  color: colors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.globe, size: 14, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _urlController.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Description input
            Text(
              'WHAT WENT WRONG?',
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: TextField(
                controller: _descController,
                maxLines: 3,
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Videos won\'t play, buttons unclickable, or page displays blank…',
                  hintStyle: TextStyle(color: colors.textTertiary, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Include Diagnostics Toggle
            InkWell(
              onTap: () {
                setState(() => _includeDiagnostics = !_includeDiagnostics);
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _includeDiagnostics,
                        onChanged: (val) {
                          setState(() => _includeDiagnostics = val ?? true);
                        },
                        activeColor: colors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Attach device info & Shield state for faster diagnosis',
                        style: TextStyle(color: colors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.send, size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Submit Report',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
