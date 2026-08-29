import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app.dart';
import 'services/content_blocker/content_blocker_service.dart';

/// Production app entry point.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch all Flutter framework errors safely
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[TxBrowser Error] ${details.exceptionAsString()}');
  };

  // Catch unhandled asynchronous errors
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[TxBrowser Async Error] $error\n$stack');
    return true; // Handled
  };

  // Initialize AdMob and Content Blocker ServiceWorker on mobile platforms
  if (!kIsWeb) {
    try {
      await MobileAds.instance.initialize();
    } catch (_) {
      // Offline / test environment graceful fallback
    }

    try {
      await ContentBlockerService().initServiceWorkerInterception();
    } catch (_) {
      // Fallback
    }
  }

  runApp(
    const ProviderScope(
      child: TxBrowserApp(),
    ),
  );
}
