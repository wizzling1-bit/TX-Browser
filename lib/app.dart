import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/theme_data.dart';
import 'state/database_provider.dart';
import 'state/acquisition_provider.dart';
import 'state/app_lock_provider.dart';
import 'state/downloads_provider.dart';
import 'state/history_provider.dart';
import 'state/proxy_provider.dart';
import 'state/settings_provider.dart';
import 'state/shortcuts_provider.dart';
import 'state/tabs_provider.dart';
import 'state/bookmarks_provider.dart';
import 'services/ad_service/ad_service.dart';
import 'features/home/home_screen.dart';
import 'features/browser/browser_screen.dart';
import 'features/tabs/tab_manager_screen.dart';
import 'features/history/history_screen.dart';
import 'features/shortcuts/pinned_sites_screen.dart';
import 'features/downloads/downloads_screen.dart';
import 'features/security/app_lock_screen.dart';
import 'features/proxy/proxy_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/scanner/qr_scanner_screen.dart';
import 'features/exit/exit_screen.dart';
import 'features/bookmarks/bookmarks_screen.dart';
import 'features/permissions/site_permissions_screen.dart';
import 'widgets/app_lock_view.dart';

/// Central GoRouter configuration with all screens.
final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/browser',
      builder: (context, state) {
        String? url;
        if (state.extra is String && (state.extra as String).isNotEmpty) {
          url = state.extra as String;
        } else if (state.uri.queryParameters.containsKey('url')) {
          url = state.uri.queryParameters['url'];
        }
        return BrowserScreen(initialUrl: url);
      },
    ),
    GoRoute(
      path: '/scanner',
      builder: (context, state) => const QrScannerScreen(),
    ),
    GoRoute(
      path: '/exit',
      builder: (context, state) => const ExitScreen(),
    ),
    GoRoute(
      path: '/tabs',
      builder: (context, state) => const TabManagerScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/bookmarks',
      builder: (context, state) => const BookmarksScreen(),
    ),
    GoRoute(
      path: '/pinned-sites',
      builder: (context, state) => const PinnedSitesScreen(),
    ),
    GoRoute(
      path: '/downloads',
      builder: (context, state) => const DownloadsScreen(),
    ),
    GoRoute(
      path: '/app-lock',
      builder: (context, state) => const AppLockSettingsScreen(),
    ),
    GoRoute(
      path: '/proxy',
      builder: (context, state) => const ProxyScreen(),
    ),
    GoRoute(
      path: '/site-permissions',
      builder: (context, state) => const SitePermissionsScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

/// Root MaterialApp with lifecycle management and App Lock Gatekeeper Overlay.
class TxBrowserApp extends ConsumerStatefulWidget {
  const TxBrowserApp({super.key});

  @override
  ConsumerState<TxBrowserApp> createState() => _TxBrowserAppState();
}

class _TxBrowserAppState extends ConsumerState<TxBrowserApp>
    with WidgetsBindingObserver {
  bool _initialized = false;
  StreamSubscription<String>? _deepLinkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 1. Parallelize core settings, security, and proxy initialization
    await Future.wait([
      ref.read(settingsProvider.notifier).loadSettings(),
      ref.read(appLockProvider.notifier).loadSettings(),
      ref.read(proxyProvider.notifier).loadSettings(),
    ]);

    // 2. Restore tabs (purges private tabs per SECURITY.md §3)
    await ref.read(tabsProvider.notifier).restoreTabs();

    // 3. Parallelize remaining metadata loads
    await Future.wait([
      ref.read(shortcutsProvider.notifier).loadShortcuts(),
      ref.read(historyProvider.notifier).loadHistory(),
      ref.read(downloadsProvider.notifier).loadDownloads(),
      ref.read(bookmarksProvider.notifier).loadBookmarks(),
    ]);

    // 4. Asynchronously process Acquisition / Play Install Referrer & Deep Links
    try {
      final db = ref.read(databaseProvider);
      final acquisitionService = ref.read(acquisitionServiceProvider);

      // Check cold-start deep link or referrer
      final initialDeepLink = await acquisitionService.getInitialDeepLink();
      if (initialDeepLink != null && initialDeepLink.isNotEmpty) {
        final uri = Uri.tryParse(initialDeepLink);
        final host = uri?.host.replaceAll('www.', '') ?? 'Link';
        final label = host.isNotEmpty ? (host[0].toUpperCase() + host.substring(1)) : 'Link';
        await ref.read(shortcutsProvider.notifier).addShortcutIfNotExists(
          label: label,
          url: initialDeepLink,
          faviconUrl: uri != null ? 'https://www.google.com/s2/favicons?domain=${uri.host}&sz=128' : null,
        );
        ref.read(tabsProvider.notifier).openTab(url: initialDeepLink);
      } else {
        final deferredPayload = await acquisitionService.checkAndProcessReferrer(db: db);
        if (deferredPayload != null && deferredPayload.targetUrl.isNotEmpty) {
          ref.read(deferredNavigationPayloadProvider.notifier).setPayload(deferredPayload);

          final uri = Uri.tryParse(deferredPayload.targetUrl);
          final host = uri?.host.replaceAll('www.', '') ?? 'Featured';
          final label = host.isNotEmpty ? (host[0].toUpperCase() + host.substring(1)) : 'Site';

          // Auto-add to Quick Access without duplicate
          await ref.read(shortcutsProvider.notifier).addShortcutIfNotExists(
            label: label,
            url: deferredPayload.targetUrl,
            faviconUrl: uri != null ? 'https://www.google.com/s2/favicons?domain=${uri.host}&sz=128' : null,
          );

          // Open target website in tabs
          ref.read(tabsProvider.notifier).openUrl(deferredPayload.targetUrl);
        }
      }

      // Listen for incoming warm deep links
      _deepLinkSubscription = acquisitionService.onDeepLink.listen((url) async {
        if (url.isNotEmpty) {
          final uri = Uri.tryParse(url);
          final host = uri?.host.replaceAll('www.', '') ?? 'Link';
          final label = host.isNotEmpty ? (host[0].toUpperCase() + host.substring(1)) : 'Link';
          await ref.read(shortcutsProvider.notifier).addShortcutIfNotExists(
            label: label,
            url: url,
            faviconUrl: uri != null ? 'https://www.google.com/s2/favicons?domain=${uri.host}&sz=128' : null,
          );
          ref.read(tabsProvider.notifier).openTab(url: url);
          _router.push('/browser', extra: url);
        }
      });
    } catch (_) {}

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      ref.read(tabsProvider.notifier).persistTabs();
      ref.read(appLockProvider.notifier).onAppPaused();
      final policy = ref.read(settingsProvider).autoClearPolicy;
      ref.read(historyProvider.notifier).evaluateAutoClearPolicy(policy);
    } else if (state == AppLifecycleState.resumed) {
      ref.read(appLockProvider.notifier).onAppResumed();
      ref.read(adServiceProvider).handleAppResume();
    } else if (state == AppLifecycleState.detached) {
      final policy = ref.read(settingsProvider).autoClearPolicy;
      if (policy == 'on_app_exit') {
        ref.read(historyProvider.notifier).clearAll();
      }
    }
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final lockState = ref.watch(appLockProvider);

    return MaterialApp.router(
      title: 'TX Browser',
      debugShowCheckedModeBanner: false,
      theme: TxTheme.light(),
      darkTheme: TxTheme.dark(),
      themeMode: settings.themeMode,
      routerConfig: _router,
      builder: (context, child) {
        if (!_initialized) {
          return const Scaffold(
            backgroundColor: Color(0xFFF2F5E8),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4A6B48),
              ),
            ),
          );
        }

        if (lockState.isCurrentlyLocked) {
          return AppLockView(
            title: 'TX Browser Locked',
            subtitle: 'Enter your 4-digit PIN to access browser',
            showBiometrics: lockState.biometricsEnabled,
            isLockedOut: lockState.isLockedOut,
            lockoutSeconds: lockState.remainingLockoutSeconds,
            onPinComplete: (pin) {
              final success =
                  ref.read(appLockProvider.notifier).unlockWithPin(pin);
              if (!success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect PIN')),
                );
              }
            },
            onBiometricTap: () {
              ref.read(appLockProvider.notifier).unlockWithBiometrics();
            },
          );
        }
        return child ?? const SizedBox();
      },
    );
  }
}
