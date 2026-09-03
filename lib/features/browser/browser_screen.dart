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
import '../../widgets/browser/shield_dashboard_sheet.dart';
import '../../widgets/dialogs/pin_shortcut_dialog.dart';
import '../../widgets/responsive/tx_responsive_container.dart';
import '../../services/ad_service/ad_service.dart';

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
    _currentUrl = widget.initialUrl ?? 'https://www.google.com';
    _omniboxController.text = _currentUrl;
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
      _loadUrl(widget.initialUrl!);
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
    setState(() => _isDesktopMode = !_isDesktopMode);
    _controller?.setSettings(
      settings: InAppWebViewSettings(
        preferredContentMode: _isDesktopMode
            ? UserPreferredContentMode.DESKTOP
            : UserPreferredContentMode.MOBILE,
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
    setState(() {
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

  void _toggleBookmark() {
    if (_currentUrl.isEmpty) return;
    final isBookmarked = ref.read(isBookmarkedProvider(_currentUrl));
    final activeTab = ref.read(tabsProvider).activeTab;
    final title = activeTab?.title ?? _currentUrl;

    if (isBookmarked) {
      ref.read(bookmarksProvider.notifier).removeBookmarkByUrl(_currentUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Bookmark removed'),
        ),
      );
    } else {
      ref.read(bookmarksProvider.notifier).addBookmark(
            title: title,
            url: _currentUrl,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Saved to Bookmarks'),
        ),
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
    for (final res in request.resources) {
      String permType = 'other';
      final resStr = res.toString().toUpperCase();
      if (resStr.contains('CAMERA') || resStr.contains('VIDEO')) {
        permType = 'camera';
      } else if (resStr.contains('MICROPHONE') || resStr.contains('AUDIO')) {
        permType = 'microphone';
      }

      final savedState = await permService.getPermissionState(
        host: host,
        permissionType: permType,
      );

      if (savedState == SitePermissionState.block) {
        return PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.DENY,
        );
      } else if (savedState == SitePermissionState.allow) {
        await permService.requestNativeDevicePermission(permType);
        return PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.GRANT,
        );
      }
    }

    // Default prompt dialog with design system styling
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
            'Website Permission Request',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: Text(
            '$host would like to access device capabilities.',
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

    if (granted == true) {
      return PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.GRANT,
      );
    } else {
      return PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.DENY,
      );
    }
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Opened in new tab'),
                      action: SnackBarAction(
                        label: 'View',
                        onPressed: () => context.push('/tabs'),
                      ),
                    ),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opened in new private tab')),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard')),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Starting image download')),
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
          ref.read(adServiceProvider).maybeShowInterstitial(
            onDismissed: () {
              if (!context.mounted) return;
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          );
        }
      },
      child: Scaffold(
        backgroundColor: colors.bg,
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
                        cacheMode: CacheMode.LOAD_DEFAULT,
                        domStorageEnabled: true,
                        databaseEnabled: true,
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
                        clearCache: false,
                        contentBlockers: ref.read(shieldProvider.notifier).service.generateNativeBlockers(),
                      ),
                      initialUserScripts: UnmodifiableListView([
                        ref.read(shieldProvider.notifier).service.getCosmeticAndYouTubeUserScript(),
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
                      onCreateWindow: (controller, createWindowAction) async {
                        final url = createWindowAction.request.url?.toString();
                        if (url == null || url.isEmpty) return false;

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
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 3),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.symmetric(
                                horizontal: TxSpacing.md,
                                vertical: TxSpacing.sm,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              content: Row(
                                children: [
                                  const Icon(LucideIcons.check, size: 16, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Download started: ${request.suggestedFilename ?? "file"}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              action: SnackBarAction(
                                label: 'View',
                                textColor: colors.primary,
                                onPressed: () => context.push('/downloads'),
                              ),
                            ),
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
                onBack: () => _controller?.goBack(),
                onForward: () => _controller?.goForward(),
                onHome: () {
                  ref.read(adServiceProvider).recordUserAction();
                  ref.read(adServiceProvider).maybeShowInterstitial(
                    onDismissed: () {
                      if (mounted) context.go('/');
                    },
                  );
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
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final currentHost = Uri.tryParse(_currentUrl)?.host ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: TxSpacing.sm),
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: TxSpacing.md),
              _MenuRow(
                icon: LucideIcons.plus,
                label: 'New tab',
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(tabsProvider.notifier).openTab();
                  context.go('/');
                },
              ),
              _MenuRow(
                icon: LucideIcons.shieldCheck,
                label: 'New private tab',
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(tabsProvider.notifier).openTab(isPrivate: true);
                  context.go('/');
                },
              ),
              Divider(color: colors.border.withValues(alpha: 0.5), indent: 56, height: 1),
              _MenuRow(
                icon: isBookmarked ? LucideIcons.star : LucideIcons.bookmark,
                label: isBookmarked ? 'Bookmarked' : 'Add to bookmarks',
                trailing: isBookmarked
                    ? Icon(LucideIcons.check, size: 18, color: colors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleBookmark();
                },
              ),
              _MenuRow(
                icon: LucideIcons.search,
                label: 'Find in page',
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _isFindInPageOpen = true);
                },
              ),
              if (currentHost.isNotEmpty)
                _MenuRow(
                  icon: LucideIcons.shieldAlert,
                  label: 'Tx Shield & Privacy',
                  onTap: () {
                    Navigator.pop(ctx);
                    showTxShieldDashboard(context, currentHost);
                  },
                ),
              _MenuRow(
                icon: LucideIcons.share2,
                label: 'Share page',
                onTap: () {
                  Navigator.pop(ctx);
                  if (_currentUrl.isNotEmpty) {
                    SharePlus.instance.share(
                      ShareParams(
                        uri: Uri.tryParse(_currentUrl),
                      ),
                    );
                  }
                },
              ),
              _MenuRow(
                icon: LucideIcons.smartphone,
                label: 'Pin to Home screen',
                onTap: () {
                  Navigator.pop(ctx);
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
              ),
              Divider(color: colors.border.withValues(alpha: 0.5), indent: 56, height: 1),
              _MenuRow(
                icon: LucideIcons.bookmarkCheck,
                label: 'Bookmarks',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/bookmarks');
                },
              ),
              _MenuRow(
                icon: LucideIcons.history,
                label: 'History',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/history');
                },
              ),
              _MenuRow(
                icon: LucideIcons.download,
                label: 'Downloads',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/downloads');
                },
              ),
              _MenuRow(
                icon: LucideIcons.bookmark,
                label: 'Pinned sites',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/pinned-sites');
                },
              ),
              _MenuRow(
                icon: LucideIcons.monitor,
                label: _isDesktopMode ? 'Mobile site' : 'Desktop site',
                trailing: _isDesktopMode
                    ? Icon(LucideIcons.check, size: 18, color: colors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleDesktopMode();
                },
              ),
              Divider(color: colors.border.withValues(alpha: 0.5), indent: 56, height: 1),
              _MenuRow(
                icon: LucideIcons.settings,
                label: 'Settings',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/settings');
                },
              ),
              const SizedBox(height: TxSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return ListTile(
      leading: Icon(icon, size: 22, color: colors.textPrimary),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: TxSpacing.lg),
      minTileHeight: 50,
    );
  }
}
