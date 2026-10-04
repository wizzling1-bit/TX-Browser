import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/shapes.dart';
import '../../core/utils/url_utils.dart';
import '../../services/search_service/search_service.dart';
import '../../services/permission_service/site_permission_service.dart';
import '../../state/tabs_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/history_provider.dart';
import '../../state/downloads_provider.dart';
import '../../state/bookmarks_provider.dart';
import '../../state/shield_provider.dart';
import '../../state/site_permissions_provider.dart';
import '../../state/shortcuts_provider.dart';
import '../../widgets/omnibox/omnibox.dart';
import '../../widgets/loading_bar.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/buttons/tx_button.dart';
import '../../state/suggestions_provider.dart';
import '../../widgets/search/search_suggestions_panel.dart';
import '../../widgets/browser/find_in_page_bar.dart';
import '../../widgets/dialogs/pin_shortcut_dialog.dart';
import '../../widgets/dialogs/download_complete_sheet.dart';
import '../../widgets/responsive/tx_responsive_container.dart';
import '../../services/ad_service/ad_service.dart';
import '../../state/rewarded_perks_provider.dart';
import '../../widgets/dialogs/app_menu_sheet.dart';
import '../../widgets/dialogs/report_issue_sheet.dart';
import '../../services/threat_service/threat_service.dart';
import '../../widgets/tx_snackbar.dart';
import '../../state/media_sniffer_provider.dart';
import '../../services/media_sniffer_service/media_sniffer_service.dart';
import '../../widgets/browser/media_sniffer_fab.dart';

/// Browser screen — where web pages are viewed and navigated.
///
/// Full-bleed WebView with floating glass address bar (top), Tx Shield integration,
/// Find in Page, Website Permissions, and Desktop Site mode.
class BrowserScreen extends ConsumerStatefulWidget {
  const BrowserScreen({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  InAppWebViewController? _controller;
  String _currentUrl = '';
  final ValueNotifier<int> _progressNotifier = ValueNotifier<int>(0);
  bool _isLoading = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _hasError = false;
  String _errorMessage = '';

  // Phishing / Scam / Malware threat interception
  ThreatRecord? _activeThreatWarning;

  bool _isDesktopMode = false;
  bool _isOmniboxFocused = false;
  final TextEditingController _omniboxController = TextEditingController();

  // Find in page state
  bool _isFindInPageOpen = false;
  int _findCurrentMatchIndex = 0;
  int _findTotalMatches = 0;
  FindInteractionController? _findInteractionController;

  // Never-stuck timeout guard (25 seconds)
  Timer? _loadingTimeoutTimer;

  @override
  void initState() {
    super.initState();
    final defaultDesktop = ref.read(settingsProvider).desktopSiteDefault;
    final tabDesktop = ref.read(tabsProvider).activeTab?.desktopSite ?? false;
    _isDesktopMode = defaultDesktop || tabDesktop;
    final activeTabUrl = ref.read(tabsProvider).activeTab?.url;
    _currentUrl = widget.initialUrl ?? (activeTabUrl != null && activeTabUrl.isNotEmpty ? activeTabUrl : 'https://www.google.com');
    _omniboxController.text = _currentUrl;

    // Check if initial URL is a threat
    final threatCheck = ref.read(threatServiceProvider).checkUrl(_currentUrl);
    if (threatCheck.isThreat && threatCheck.threat != null) {
      _activeThreatWarning = threatCheck.threat;
    }

    _findInteractionController = FindInteractionController(
      onFindResultReceived: (controller, activeMatchOrdinal, numberOfMatches, isDoneCounting) {
        setState(() {
          _findCurrentMatchIndex = activeMatchOrdinal;
          _findTotalMatches = numberOfMatches;
        });
      },
    );
  }

  @override
  void didUpdateWidget(BrowserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUrl != null &&
        widget.initialUrl != oldWidget.initialUrl &&
        widget.initialUrl != _currentUrl) {
      final threatCheck = ref.read(threatServiceProvider).checkUrl(widget.initialUrl!);
      if (threatCheck.isThreat && threatCheck.threat != null) {
        setState(() {
          _activeThreatWarning = threatCheck.threat;
          _currentUrl = widget.initialUrl!;
          _omniboxController.text = widget.initialUrl!;
        });
      } else {
        setState(() {
          _activeThreatWarning = null;
        });
        _loadUrl(widget.initialUrl!);
      }
    }
  }

  @override
  void dispose() {
    _loadingTimeoutTimer?.cancel();
    _progressNotifier.dispose();
    _omniboxController.dispose();
    super.dispose();
  }

  void _recordHistory({String? title, String? url, String? favicon}) {
    final targetUrl = url ?? _currentUrl;
    if (targetUrl.isEmpty || targetUrl == 'about:blank' || targetUrl.startsWith('data:')) return;

    final activeTab = ref.read(tabsProvider).activeTab;
    if (activeTab != null && activeTab.isPrivate) return; // Strict SECURITY.md rule

    final effectiveTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : (activeTab?.title.isNotEmpty == true && activeTab!.title != 'New Tab'
            ? activeTab.title
            : targetUrl);

    try {
      ref.read(historyProvider.notifier).recordVisit(
            url: targetUrl,
            title: effectiveTitle,
            faviconUrl: favicon,
          );
      ref.read(adServiceProvider).recordUserAction();
      ref.read(shortcutsProvider.notifier).autoPinVisitedSite(
            url: targetUrl,
            title: effectiveTitle,
            faviconUrl: favicon,
          );
    } catch (_) {}
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;

    // Register JavaScript handler for DOM media detection
    controller.addJavaScriptHandler(
      handlerName: 'onMediaDetected',
      callback: (args) {
        if (!mounted || args.isEmpty) return;
        final data = args[0] as Map<dynamic, dynamic>?;
        if (data != null) {
          final url = data['url']?.toString();
          if (url != null && url.isNotEmpty) {
            ref.read(mediaSnifferProvider.notifier).addMediaFromUrl(
                  url,
                  contentType: data['mimeType']?.toString(),
                  pageTitle: data['title']?.toString() ?? _currentUrl,
                  posterUrl: data['poster']?.toString(),
                  videoWidth: data['videoWidth'] is int ? data['videoWidth'] as int : null,
                  videoHeight: data['videoHeight'] is int ? data['videoHeight'] as int : null,
                );
          }
        }
      },
    );

    if (_currentUrl.isNotEmpty) {
      _controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(_currentUrl)),
      );
    }
  }

  void _startLoadingTimeout() {
    _loadingTimeoutTimer?.cancel();
    _loadingTimeoutTimer = Timer(const Duration(seconds: 25), () {
      if (_isLoading && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _onLoadStart(InAppWebViewController controller, WebUri? url) {
    _startLoadingTimeout();
    ref.read(mediaSnifferProvider.notifier).clear();
    setState(() {
      _isLoading = true;
      _hasError = false;
      if (url != null) _currentUrl = url.toString();
    });

    if (url != null && url.host.isNotEmpty) {
      ref.read(shieldProvider.notifier).resetStatsForHost(url.host);
      _recordHistory(url: url.toString());
    }
  }

  void _onLoadStop(InAppWebViewController controller, WebUri? url) async {
    _loadingTimeoutTimer?.cancel();

    String? pageTitle;
    bool canBack = false;
    bool canFwd = false;
    String? favicon;

    try {
      pageTitle = await controller.getTitle().catchError((_) => null);
    } catch (_) {}

    try {
      canBack = await controller.canGoBack().catchError((_) => false);
      canFwd = await controller.canGoForward().catchError((_) => false);
    } catch (_) {}

    try {
      final favicons = await controller.getFavicons().catchError((_) => <Favicon>[]);
      favicon = favicons.firstOrNull?.url.toString();
    } catch (_) {}

    if (!mounted) return;

    final title = (pageTitle != null && pageTitle.isNotEmpty) ? pageTitle : '';

    setState(() {
      _isLoading = false;
      _canGoBack = canBack;
      _canGoForward = canFwd;
      if (url != null) {
        _currentUrl = url.toString();
        if (!_isOmniboxFocused) {
          _omniboxController.text = _currentUrl;
        }
      }
    });

    _recordHistory(title: title, url: _currentUrl, favicon: favicon);

    // Update active tab metadata immutably
    final activeTab = ref.read(tabsProvider).activeTab;
    if (activeTab != null) {
      ref.read(tabsProvider.notifier).updateTab(activeTab.id, (tab) {
        return tab.copyWith(
          url: _currentUrl,
          title: title.isNotEmpty ? title : _currentUrl,
          faviconUrl: favicon ?? tab.faviconUrl,
          canGoBack: canBack,
          canGoForward: canFwd,
          isLoading: false,
        );
      });

      // Capture high-fidelity preview thumbnail for Tab Manager
      Future.delayed(const Duration(milliseconds: 350), () async {
        if (!mounted) return;
        try {
          final screenshot = await controller.takeScreenshot(
            screenshotConfiguration: ScreenshotConfiguration(
              compressFormat: CompressFormat.JPEG,
              quality: 75,
            ),
          );
          if (screenshot != null && screenshot.isNotEmpty) {
            ref.read(tabsProvider.notifier).updateTabThumbnail(activeTab.id, screenshot);
          }
        } catch (_) {}
      });

      // Trigger DOM media scan for late-mounted SPA video players
      try {
        controller.evaluateJavascript(
          source: 'if (typeof scanAllMedia === "function") { scanAllMedia(); }',
        );
      } catch (_) {}
    }
  }

  void _onProgressChanged(InAppWebViewController controller, int progress) {
    _progressNotifier.value = progress;
    if (progress >= 100 && _isLoading) {
      setState(() => _isLoading = false);
    }
  }

  void _onUpdateVisitedHistory(
    InAppWebViewController controller,
    WebUri? url,
    bool? isReload,
  ) async {
    bool canBack = false;
    bool canFwd = false;
    try {
      canBack = await controller.canGoBack().catchError((_) => false);
      canFwd = await controller.canGoForward().catchError((_) => false);
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _canGoBack = canBack;
      _canGoForward = canFwd;
      if (url != null) {
        _currentUrl = url.toString();
        if (!_isOmniboxFocused) {
          _omniboxController.text = _currentUrl;
        }
      }
    });

    if (url != null) {
      _recordHistory(url: url.toString());
    }
  }

  void _onTitleChanged(InAppWebViewController controller, String? title) {
    if (title != null && title.isNotEmpty) {
      final activeTab = ref.read(tabsProvider).activeTab;
      if (activeTab != null) {
        ref.read(tabsProvider.notifier).updateTab(activeTab.id, (tab) {
          return tab.copyWith(title: title);
        });
        _recordHistory(title: title);
      }
    }
  }

  void _onReceivedError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) {
    _loadingTimeoutTimer?.cancel();
    if (request.isForMainFrame ?? true) {
      setState(() {
        _hasError = true;
        _errorMessage = error.description;
        _isLoading = false;
      });
    }
  }

  void _onReceivedHttpError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceResponse errorResponse,
  ) {
    if (request.isForMainFrame ?? true) {
      final code = errorResponse.statusCode ?? 0;
      if (code >= 500) {
        final reason = errorResponse.reasonPhrase;
        setState(() {
          _hasError = true;
          _errorMessage = 'Server error ($code: ${reason != null && reason.isNotEmpty ? reason : "Internal Server Error"})';
          _isLoading = false;
        });
      }
    }
  }

  void _toggleDesktopMode() {
    final nextMode = !_isDesktopMode;
    setState(() => _isDesktopMode = nextMode);
    _controller?.setSettings(
      settings: InAppWebViewSettings(
        preferredContentMode: nextMode
            ? UserPreferredContentMode.DESKTOP
            : UserPreferredContentMode.RECOMMENDED,
        userAgent: nextMode
            ? 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
            : '',
      ),
    );
    _controller?.reload();
  }

  Future<NavigationActionPolicy> _shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction navigationAction,
  ) async {
    final uri = navigationAction.request.url;
    if (uri == null) return NavigationActionPolicy.ALLOW;

    final destUrl = uri.toString();

    // Check if destination is a phishing, scam, or malware threat
    final threatCheck = ref.read(threatServiceProvider).checkUrl(destUrl);
    if (threatCheck.isThreat && threatCheck.threat != null) {
      setState(() {
        _activeThreatWarning = threatCheck.threat;
        _currentUrl = destUrl;
        _omniboxController.text = destUrl;
      });
      return NavigationActionPolicy.CANCEL;
    }

    final pageHost = Uri.tryParse(_currentUrl)?.host;
    final blockerService = ref.read(shieldProvider.notifier).service;

    // Check if destination is an ad / tracker / popunder redirect
    final decision = blockerService.evaluatePopupOrNavigation(
      destinationUrl: destUrl,
      pageHost: pageHost,
    );

    if (decision.isBlocked) {
      if (pageHost != null && decision.reason != null) {
        ref.read(shieldProvider.notifier).recordBlockEvent(
              pageHost: pageHost,
              reason: decision.reason!,
            );
      }
      return NavigationActionPolicy.CANCEL;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https' && scheme != 'about') {
      if (scheme == 'tel' || scheme == 'mailto' || scheme == 'sms') {
        try {
          await launchUrl(uri.uriValue, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  void _loadUrl(String input) {
    final query = input.trim();
    if (query.isEmpty) return;
    final searchEngine = ref.read(settingsProvider).searchEngine;
    const searchService = SearchService();
    final resolvedUrl = searchService.resolve(query, engine: searchEngine);

    final threatCheck = ref.read(threatServiceProvider).checkUrl(resolvedUrl);
    if (threatCheck.isThreat && threatCheck.threat != null) {
      setState(() {
        _activeThreatWarning = threatCheck.threat;
        _currentUrl = resolvedUrl;
        _omniboxController.text = resolvedUrl;
        _hasError = false;
        _isOmniboxFocused = false;
      });
      ref.read(suggestionsProvider.notifier).clear();
      FocusScope.of(context).unfocus();
      return;
    }

    setState(() {
      _activeThreatWarning = null;
      _currentUrl = resolvedUrl;
      _omniboxController.text = resolvedUrl;
      _hasError = false;
      _isOmniboxFocused = false;
    });
    ref.read(suggestionsProvider.notifier).clear();
    FocusScope.of(context).unfocus();
    _controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri(resolvedUrl)),
    );
  }

  void _bypassThreatAndProceed() {
    if (_activeThreatWarning == null) return;
    final domain = _activeThreatWarning!.domain;
    ref.read(threatServiceProvider).bypassDomainWarning(domain);
    setState(() {
      _activeThreatWarning = null;
    });
    _controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri(_currentUrl)),
    );
  }

  void _backToSafety() {
    setState(() {
      _activeThreatWarning = null;
    });
    if (context.canPop()) {
      context.pop();
    } else {
      _loadUrl('https://www.google.com');
    }
  }

  void _toggleBookmark() {
    if (_currentUrl.isEmpty) return;
    final isBookmarked = ref.read(isBookmarkedProvider(_currentUrl));
    final activeTab = ref.read(tabsProvider).activeTab;
    final title = activeTab?.title ?? _currentUrl;

    if (isBookmarked) {
      ref.read(bookmarksProvider.notifier).removeBookmarkByUrl(_currentUrl);
      TxSnackbar.show(
        context,
        'Bookmark removed',
        icon: LucideIcons.bookmark,
      );
    } else {
      ref.read(bookmarksProvider.notifier).addBookmark(
            title: title,
            url: _currentUrl,
          );
      TxSnackbar.show(
        context,
        'Saved to Bookmarks',
        icon: LucideIcons.bookmarkCheck,
      );
    }
  }

  Future<PermissionResponse?> _onPermissionRequest(
    InAppWebViewController controller,
    PermissionRequest request,
  ) async {
    final host = request.origin.host.isNotEmpty
        ? request.origin.host
        : (Uri.tryParse(_currentUrl)?.host ?? '');
    if (host.isEmpty) {
      return PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.DENY,
      );
    }

    final permService = ref.read(sitePermissionServiceProvider);

    // Map requested resources
    final types = <String>{};
    for (final res in request.resources) {
      final resStr = res.toString().toUpperCase();
      if (resStr.contains('CAMERA') || resStr.contains('VIDEO')) {
        types.add('camera');
      } else if (resStr.contains('MICROPHONE') || resStr.contains('AUDIO')) {
        types.add('microphone');
      } else {
        types.add('other');
      }
    }

    // Check if any is explicitly blocked
    bool anyBlocked = false;
    bool allAllowed = true;
    for (final t in types) {
      final state = await permService.getPermissionState(host: host, permissionType: t);
      if (state == SitePermissionState.block) {
        anyBlocked = true;
      }
      if (state != SitePermissionState.allow) {
        allAllowed = false;
      }
    }

    if (anyBlocked) {
      return PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.DENY,
      );
    }

    if (allAllowed && types.isNotEmpty) {
      for (final t in types) {
        await permService.requestNativeDevicePermission(t);
      }
      return PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.GRANT,
      );
    }

    // Prompt user
    if (!mounted) return null;
    final typeLabel = types.map((e) => e[0].toUpperCase() + e.substring(1)).join(' & ');
    final granted = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).extension<TxColorScheme>()!;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.border),
          ),
          title: Text(
            'Website Permission Request',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: Text(
            '$host wants to access your $typeLabel.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
              child: const Text('Block'),
            ),
            TxButton(
              label: 'Allow',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );

    final targetState = (granted == true) ? SitePermissionState.allow : SitePermissionState.block;
    for (final t in types) {
      await permService.setPermissionState(
        host: host,
        permissionType: t,
        state: targetState,
      );
      if (granted == true) {
        await permService.requestNativeDevicePermission(t);
      }
    }

    return PermissionResponse(
      resources: request.resources,
      action: (granted == true)
          ? PermissionResponseAction.GRANT
          : PermissionResponseAction.DENY,
    );
  }

  Future<GeolocationPermissionShowPromptResponse?> _onGeolocationPermissionsShowPrompt(
    InAppWebViewController controller,
    String origin,
  ) async {
    final host = Uri.tryParse(origin)?.host.isNotEmpty == true
        ? Uri.tryParse(origin)!.host
        : origin;

    final permService = ref.read(sitePermissionServiceProvider);
    final savedState = await permService.getPermissionState(
      host: host,
      permissionType: 'location',
    );

    if (savedState == SitePermissionState.block) {
      return GeolocationPermissionShowPromptResponse(
        origin: origin,
        allow: false,
        retain: true,
      );
    } else if (savedState == SitePermissionState.allow) {
      await permService.requestNativeDevicePermission('location');
      return GeolocationPermissionShowPromptResponse(
        origin: origin,
        allow: true,
        retain: true,
      );
    }

    if (!mounted) return null;
    final granted = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).extension<TxColorScheme>()!;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.border),
          ),
          title: Text(
            'Location Access Request',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: Text(
            '$host wants to access your location.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
              child: const Text('Block'),
            ),
            TxButton(
              label: 'Allow',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );

    final isAllowed = granted == true;
    await permService.setPermissionState(
      host: host,
      permissionType: 'location',
      state: isAllowed ? SitePermissionState.allow : SitePermissionState.block,
    );

    if (isAllowed) {
      await permService.requestNativeDevicePermission('location');
    }

    return GeolocationPermissionShowPromptResponse(
      origin: origin,
      allow: isAllowed,
      retain: true,
    );
  }

  void _showLinkContextMenu(
    BuildContext context,
    InAppWebViewHitTestResult hitTestResult,
  ) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final extra = hitTestResult.extra;
    final targetUrl = extra != null ? extra.toString() : '';
    if (targetUrl.isEmpty) return;

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: TxRadius.borderRadiusSheet,
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TxSpacing.lg,
            vertical: TxSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Preview
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      LucideIcons.globe,
                      size: 18,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: TxSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          UrlUtils.extractDomain(targetUrl),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          targetUrl,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TxSpacing.md),
              Divider(color: colors.borderSubtle, height: 1),
              const SizedBox(height: TxSpacing.xs),

              // Actions
              ListTile(
                leading: Icon(LucideIcons.externalLink, color: colors.textPrimary),
                title: const Text('Open'),
                dense: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _loadUrl(targetUrl);
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.plusSquare, color: colors.primary),
                title: const Text('Open in New Tab'),
                dense: true,
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(tabsProvider.notifier).openTab(url: targetUrl);
                  TxSnackbar.show(
                    context,
                    'Opened in new tab',
                    icon: LucideIcons.plusSquare,
                    actionLabel: 'View',
                    onAction: () => context.push('/tabs'),
                  );
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.shieldCheck, color: colors.privateAccent),
                title: const Text('Open in Private Tab'),
                dense: true,
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(tabsProvider.notifier).openTab(url: targetUrl, isPrivate: true);
                  TxSnackbar.show(
                    context,
                    'Opened in new private tab',
                    icon: LucideIcons.shieldCheck,
                  );
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.clipboardCopy, color: colors.textPrimary),
                title: const Text('Copy Link Address'),
                dense: true,
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: targetUrl));
                  TxSnackbar.show(
                    context,
                    'Link copied to clipboard',
                    icon: LucideIcons.clipboardCopy,
                  );
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.share2, color: colors.textPrimary),
                title: const Text('Share Link'),
                dense: true,
                onTap: () {
                  Navigator.pop(ctx);
                  SharePlus.instance.share(
                    ShareParams(
                      uri: Uri.tryParse(targetUrl),
                    ),
                  );
                },
              ),
              if (hitTestResult.type == InAppWebViewHitTestResultType.IMAGE_TYPE ||
                  hitTestResult.type == InAppWebViewHitTestResultType.SRC_IMAGE_ANCHOR_TYPE)
                ListTile(
                  leading: Icon(LucideIcons.download, color: colors.primary),
                  title: const Text('Download Image'),
                  dense: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(downloadsProvider.notifier).startDownload(targetUrl);
                    TxSnackbar.show(
                      context,
                      'Starting image download',
                      icon: LucideIcons.download,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    // Use select to avoid rebuilding the entire screen when other tab metadata changes
    final tabCount = ref.watch(tabsProvider.select((s) => s.count));
    final suggestionsState = ref.watch(suggestionsProvider);
    final isBookmarked = ref.watch(isBookmarkedProvider(_currentUrl));
    final isPrivateTab = ref.watch(tabsProvider.select((s) => s.activeTab?.isPrivate ?? false));

    // Present Download Complete Bottom Sheet when any background download finishes
    ref.listen<DownloadModel?>(downloadCompletedEventProvider, (prev, next) {
      if (next != null && mounted) {
        DownloadCompleteSheet.show(context, next);
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isFindInPageOpen) {
          setState(() => _isFindInPageOpen = false);
          _findInteractionController?.clearMatches();
          return;
        }
        if (_isOmniboxFocused) {
          setState(() => _isOmniboxFocused = false);
          ref.read(suggestionsProvider.notifier).clear();
          FocusScope.of(context).unfocus();
          return;
        }
        final canBack = (await _controller?.canGoBack()) ?? false;
        if (canBack) {
          await _controller?.goBack();
        } else {
          if (!context.mounted) return;
          ref.read(adServiceProvider).recordUserAction();
          bool navigated = false;
          void navigateBack() {
            if (!navigated && context.mounted) {
              navigated = true;
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            }
          }

          final didShow = ref.read(adServiceProvider).maybeShowInterstitial(
            onDismissed: navigateBack,
          );
          if (!didShow) {
            navigateBack();
          }
        }
      },
      child: Scaffold(
        backgroundColor: isPrivateTab ? const Color(0xFF0D0C15) : colors.bg,
        body: Column(
          children: [
            // ─── 1. TOP BROWSER ADDRESS BAR & PROGRESS ───────────────
            SafeArea(
              bottom: false,
              child: TxResponsiveContainer(
                maxWidth: 720,
                padding: const EdgeInsets.symmetric(
                  horizontal: TxSpacing.md,
                  vertical: 4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Omnibox(
                      url: _currentUrl,
                      isLoading: _isLoading,
                      controller: _omniboxController,
                      isPrivate: isPrivateTab,
                      onSubmitted: (val) {
                        setState(() => _isOmniboxFocused = false);
                        ref.read(suggestionsProvider.notifier).clear();
                        _loadUrl(val);
                      },
                      onReload: () => _controller?.reload(),
                      onStop: () => _controller?.stopLoading(),
                      onFocusChanged: (focused) {
                        setState(() => _isOmniboxFocused = focused);
                        if (focused && _omniboxController.text.isNotEmpty) {
                          ref
                              .read(suggestionsProvider.notifier)
                              .onQueryChanged(_omniboxController.text);
                        } else if (!focused) {
                          ref.read(suggestionsProvider.notifier).clear();
                        }
                      },
                      onQueryChanged: (query) {
                        ref
                            .read(suggestionsProvider.notifier)
                            .onQueryChanged(query);
                      },
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: _progressNotifier,
                      builder: (context, progress, _) => LoadingBar(
                        progress: progress,
                        isVisible: _isLoading,
                        color: isPrivateTab ? colors.privateAccent : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Find in Page Bar
            if (_isFindInPageOpen)
              FindInPageBar(
                currentMatchIndex: _findCurrentMatchIndex,
                totalMatches: _findTotalMatches,
                onSearch: (query) {
                  if (query.trim().isEmpty) {
                    _findInteractionController?.clearMatches();
                    setState(() {
                      _findTotalMatches = 0;
                      _findCurrentMatchIndex = 0;
                    });
                  } else {
                    _findInteractionController?.findAll(find: query);
                  }
                },
                onNext: () => _findInteractionController?.findNext(forward: true),
                onPrevious: () => _findInteractionController?.findNext(forward: false),
                onClose: () {
                  setState(() => _isFindInPageOpen = false);
                  _findInteractionController?.clearMatches();
                },
              ),

            // ─── 2. MIDDLE VIEWPORT: FULL WEBVIEW CONTENT ────────────
            Expanded(
              child: Stack(
                children: [
                  RepaintBoundary(
                    child: InAppWebView(
                      initialSettings: InAppWebViewSettings(
                        isInspectable: kDebugMode,
                        javaScriptEnabled: true,
                        javaScriptCanOpenWindowsAutomatically: false,
                        useShouldOverrideUrlLoading: true,
                        mediaPlaybackRequiresUserGesture: false,
                        allowFileAccessFromFileURLs: false,
                        allowUniversalAccessFromFileURLs: false,
                        mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
                        supportMultipleWindows: false,
                        incognito: isPrivateTab,
                        cacheMode: isPrivateTab
                            ? CacheMode.LOAD_NO_CACHE
                            : CacheMode.LOAD_DEFAULT,
                        domStorageEnabled: !isPrivateTab,
                        databaseEnabled: !isPrivateTab,
                        useShouldInterceptRequest: true,
                        hardwareAcceleration: true,
                        allowsBackForwardNavigationGestures: true,
                        transparentBackground: false,
                        verticalScrollBarEnabled: true,
                        horizontalScrollBarEnabled: false,
                        overScrollMode: OverScrollMode.IF_CONTENT_SCROLLS,
                        useWideViewPort: true,
                        loadWithOverviewMode: true,
                        offscreenPreRaster: true,
                        safeBrowsingEnabled: true,
                        clearCache: isPrivateTab,
                        clearSessionCache: isPrivateTab,
                        preferredContentMode: _isDesktopMode
                            ? UserPreferredContentMode.DESKTOP
                            : UserPreferredContentMode.RECOMMENDED,
                        userAgent: _isDesktopMode
                            ? 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
                            : '',
                        contentBlockers: ref.read(shieldProvider.notifier).service.generateNativeBlockers(),
                      ),
                      initialUserScripts: UnmodifiableListView([
                        ref.read(shieldProvider.notifier).service.getCosmeticAndYouTubeUserScript(),
                        MediaSnifferService.instance.getMediaSnifferUserScript(),
                      ]),
                      findInteractionController: _findInteractionController,
                      onWebViewCreated: _onWebViewCreated,
                      onLoadStart: _onLoadStart,
                      onLoadStop: _onLoadStop,
                      onProgressChanged: _onProgressChanged,
                      onUpdateVisitedHistory: _onUpdateVisitedHistory,
                      onTitleChanged: _onTitleChanged,
                      onReceivedError: _onReceivedError,
                      onReceivedHttpError: _onReceivedHttpError,
                      onPermissionRequest: _onPermissionRequest,
                      onGeolocationPermissionsShowPrompt: _onGeolocationPermissionsShowPrompt,
                      onCreateWindow: (controller, createWindowAction) async {
                        final url = createWindowAction.request.url?.toString();
                        if (url == null || url.isEmpty) return false;

                        // Security threat interception for popups / new window attempts
                        final threatCheck = ref.read(threatServiceProvider).checkUrl(url);
                        if (threatCheck.isThreat && threatCheck.threat != null) {
                          setState(() {
                            _activeThreatWarning = threatCheck.threat;
                            _currentUrl = url;
                            _omniboxController.text = url;
                          });
                          return false;
                        }

                        final pageHost = Uri.tryParse(_currentUrl)?.host;
                        final blockerService = ref.read(shieldProvider.notifier).service;

                        // Evaluate popup / new window target against ad & popunder rules
                        final decision = blockerService.evaluatePopupOrNavigation(
                          destinationUrl: url,
                          pageHost: pageHost,
                        );

                        if (decision.isBlocked) {
                          if (pageHost != null && decision.reason != null) {
                            ref.read(shieldProvider.notifier).recordBlockEvent(
                                  pageHost: pageHost,
                                  reason: decision.reason!,
                                );
                          }
                          return false;
                        }

                        // Legitimate user-intended new tab (do not hijack the current tab)
                        ref.read(tabsProvider.notifier).openTab(url: url);
                        return true;
                      },
                      onLongPressHitTestResult: (controller, hitTestResult) {
                        _showLinkContextMenu(context, hitTestResult);
                      },
                      shouldInterceptRequest: (controller, request) async {
                        final reqUrl = request.url.toString();

                        // Smart Video Sniffer Interception
                        if (MediaSnifferService.instance.isMediaUrl(reqUrl)) {
                          final contentType = request.headers?['Accept'] ?? request.headers?['Content-Type'];
                          final activeTitle = ref.read(tabsProvider).activeTab?.title;
                          final cleanTitle = (activeTitle != null &&
                                  activeTitle.isNotEmpty &&
                                  activeTitle != 'New Tab' &&
                                  !activeTitle.startsWith('http'))
                              ? activeTitle
                              : null;
                          ref.read(mediaSnifferProvider.notifier).addMediaFromUrl(
                                reqUrl,
                                contentType: contentType,
                                pageTitle: cleanTitle,
                              );
                        }

                        final pageHost = Uri.tryParse(_currentUrl)?.host ??
                            (request.headers?['Referer'] != null
                                ? Uri.tryParse(request.headers!['Referer']!)?.host
                                : null);
                        final blockerService = ref.read(shieldProvider.notifier).service;
                        final decision = blockerService.evaluateRequest(
                          requestUrl: reqUrl,
                          pageHost: pageHost,
                        );

                        if (decision.isBlocked) {
                          if (pageHost != null && decision.reason != null) {
                            ref.read(shieldProvider.notifier).recordBlockEvent(
                                  pageHost: pageHost,
                                  reason: decision.reason!,
                                );
                          }
                          // Intercept and block resource immediately with empty payload
                          return WebResourceResponse(
                            contentType: 'text/plain',
                            data: Uint8List(0),
                            statusCode: 200,
                            reasonPhrase: 'Blocked by Tx Shield',
                          );
                        }
                        return null;
                      },
                      shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
                      onDownloadStartRequest: (controller, request) async {
                        final urlStr = request.url.toString();
                        String? cookiesStr;
                        try {
                          final cookies = await CookieManager.instance().getCookies(
                            url: WebUri(urlStr),
                          );
                          if (cookies.isNotEmpty) {
                            cookiesStr = cookies.map((c) => '${c.name}=${c.value}').join('; ');
                          }
                        } catch (_) {}

                        ref.read(downloadsProvider.notifier).startDownload(
                              urlStr,
                              customFileName: request.suggestedFilename,
                              mimeType: request.mimeType,
                              userAgent: request.userAgent,
                              cookies: cookiesStr,
                            );

                        if (context.mounted) {
                          TxSnackbar.show(
                            context,
                            'Download started: ${request.suggestedFilename ?? "file"}',
                            icon: LucideIcons.download,
                            actionLabel: 'View',
                            onAction: () => context.push('/downloads'),
                          );
                        }
                      },
                    ),
                  ),

                  // Backdrop overlay when omnibox is focused
                  if (_isOmniboxFocused)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _isOmniboxFocused = false);
                          ref.read(suggestionsProvider.notifier).clear();
                          FocusScope.of(context).unfocus();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                      ),
                    ),

                  // Autocomplete Suggestions Overlay in Browser
                  if (_isOmniboxFocused &&
                      _omniboxController.text.trim().isNotEmpty &&
                      suggestionsState.suggestions.isNotEmpty)
                    Positioned(
                      top: 0,
                      left: TxSpacing.md,
                      right: TxSpacing.md,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: SearchSuggestionsPanel(
                            suggestions: suggestionsState.suggestions,
                            isLoading: suggestionsState.isLoading,
                            onSelect: (suggestion) {
                              _loadUrl(suggestion.url);
                            },
                            onInsert: (text) {
                              _omniboxController.text = text;
                              _omniboxController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(offset: text.length),
                              );
                              ref
                                  .read(suggestionsProvider.notifier)
                                  .onQueryChanged(text);
                            },
                          ),
                        ),
                      ),
                    ),

                  // Error page overlay
                  if (_hasError)
                    Positioned.fill(
                      child: Container(
                        color: colors.bg,
                        padding: const EdgeInsets.all(TxSpacing.xl),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: colors.error.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    LucideIcons.globe,
                                    size: 36,
                                    color: colors.error,
                                  ),
                                ),
                                const SizedBox(height: TxSpacing.lg),
                                Text(
                                  'Unable to reach site',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: TxSpacing.sm),
                                Text(
                                  _errorMessage.isNotEmpty
                                      ? _errorMessage
                                      : 'Check your internet connection or URL and try again.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: TxSpacing.xl),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() => _hasError = false);
                                        if (context.canPop()) {
                                          context.pop();
                                        } else {
                                          context.go('/');
                                        }
                                      },
                                      icon: const Icon(LucideIcons.arrowLeft, size: 16),
                                      label: const Text('Go Back'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: colors.textPrimary,
                                        side: BorderSide(color: colors.border),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: TxRadius.borderRadiusSm,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: TxSpacing.md),
                                    TxButton(
                                      label: 'Try Again',
                                      icon: LucideIcons.rotateCw,
                                      onPressed: () {
                                        setState(() => _hasError = false);
                                        _loadUrl(_currentUrl);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Security Threat Warning Overlay (Phishing / Scam / Malware)
                  if (_activeThreatWarning != null)
                    Positioned.fill(
                      child: _buildThreatWarningOverlay(context, colors),
                    ),

                  // Smart Media Sniffer Floating Action Button
                  if (!_isOmniboxFocused && _activeThreatWarning == null)
                    const MediaSnifferFab(
                      bottomOffset: TxSpacing.lg,
                      rightOffset: TxSpacing.md,
                    ),
                ],
              ),
            ),

            // ─── 3. BOTTOM BROWSER NAVIGATION BAR ────────────────────
            SafeArea(
              top: false,
              child: BottomNavBar(
                canGoBack: _canGoBack,
                canGoForward: _canGoForward,
                tabCount: tabCount,
                isVisible: true,
                isPrivate: isPrivateTab,
                onBack: () => _controller?.goBack(),
                onForward: () => _controller?.goForward(),
                onHome: () {
                  ref.read(adServiceProvider).recordUserAction();
                  bool navigated = false;
                  void navigateHome() {
                    if (!navigated && mounted) {
                      navigated = true;
                      context.go('/');
                    }
                  }

                  final didShow = ref.read(adServiceProvider).maybeShowInterstitial(
                    onDismissed: navigateHome,
                  );
                  if (!didShow) {
                    navigateHome();
                  } else {
                    // Safety guard: if ad presentation stalls or callback drops, navigate home unconditionally
                    Future.delayed(const Duration(seconds: 3), () {
                      if (!navigated && mounted) {
                        navigateHome();
                      }
                    });
                  }
                },
                onTabManager: _openTabManager,
                onMenu: () => _showMenuSheet(context, isBookmarked),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTabManager() async {
    try {
      final activeTab = ref.read(tabsProvider).activeTab;
      if (activeTab != null && _controller != null) {
        final screenshot = await _controller!.takeScreenshot(
          screenshotConfiguration: ScreenshotConfiguration(
            compressFormat: CompressFormat.JPEG,
            quality: 75,
          ),
        );
        if (screenshot != null && screenshot.isNotEmpty) {
          ref.read(tabsProvider.notifier).updateTabThumbnail(activeTab.id, screenshot);
        }
      }
    } catch (_) {}
    if (!mounted) return;
    context.push('/tabs');
  }

  void _showMenuSheet(BuildContext context, bool isBookmarked) {
    showTxAppMenuSheet(
      context: context,
      ref: ref,
      isHomeScreen: false,
      currentUrl: _currentUrl,
      isBookmarked: isBookmarked,
      isDesktopMode: _isDesktopMode,
      onUnlockAdFreePass: () {
        final perks = ref.read(rewardedPerksProvider);
        if (perks.isAdFreeActive) {
          TxSnackbar.show(
            context,
            'Ad-Free Pass is active! ${perks.formatDuration(perks.remainingAdFreeTime)} remaining.',
            icon: LucideIcons.shieldCheck,
          );
          return;
        }
        ref.read(adServiceProvider).showRewardedAd(
          onUserEarnedReward: (reward) {
            ref.read(rewardedPerksProvider.notifier).activateAdFreePass();
            TxSnackbar.show(
              context,
              '10-Minute Ad-Free Pass Activated!',
              icon: LucideIcons.sparkles,
            );
          },
          onDismissed: () {},
        );
      },
      onToggleBookmark: _toggleBookmark,
      onToggleDesktopMode: _toggleDesktopMode,
      onFindInPage: () {
        setState(() => _isFindInPageOpen = true);
      },
      onShare: () {
        if (_currentUrl.isNotEmpty) {
          SharePlus.instance.share(
            ShareParams(
              uri: Uri.tryParse(_currentUrl),
            ),
          );
        }
      },
      onPinToHome: () {
        if (_currentUrl.isNotEmpty) {
          showPinShortcutDialog(
            context: context,
            ref: ref,
            title: ref.read(tabsProvider).activeTab?.title ??
                Uri.tryParse(_currentUrl)?.host ??
                'Web Site',
            url: _currentUrl,
          );
        }
      },
    );
  }

  Widget _buildThreatWarningOverlay(BuildContext context, TxColorScheme colors) {
    final threat = _activeThreatWarning;
    if (threat == null) return const SizedBox.shrink();

    return Container(
      color: colors.bg,
      padding: const EdgeInsets.symmetric(horizontal: TxSpacing.xl, vertical: TxSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Threat Icon Badge
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.error.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      LucideIcons.shieldAlert,
                      size: 38,
                      color: colors.error,
                    ),
                  ),
                ),
                const SizedBox(height: TxSpacing.lg),

                // Category Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.alertCircle, size: 13, color: colors.error),
                      const SizedBox(width: 6),
                      Text(
                        threat.category.displayName.toUpperCase(),
                        style: TextStyle(
                          color: colors.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: TxSpacing.md),

                // Headline
                Text(
                  'Security Threat Blocked',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: TxSpacing.xs),

                // Targeted Domain
                Container(
                  margin: const EdgeInsets.symmetric(vertical: TxSpacing.sm),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    threat.domain,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: TxSpacing.sm),

                // Threat Explanation
                Text(
                  threat.reason,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: TxSpacing.xs),
                Text(
                  'TX Browser Shield intercepted this site before it could access your cookies, crypto wallet, or credentials.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: TxSpacing.xl),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TxButton(
                        label: 'Back to Safety',
                        icon: LucideIcons.shieldCheck,
                        onPressed: _backToSafety,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TxSpacing.md),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => ReportIssueSheet(prefilledUrl: _currentUrl),
                        );
                      },
                      icon: Icon(LucideIcons.helpCircle, size: 14, color: colors.textSecondary),
                      label: Text(
                        'Report False Alarm',
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: _bypassThreatAndProceed,
                      child: Text(
                        'Proceed Anyway (Unsafe)',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.error.withValues(alpha: 0.8),
                          decoration: TextDecoration.underline,
                        ),
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
