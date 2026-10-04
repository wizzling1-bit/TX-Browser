import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether core app bootstrap and initialization is complete.
/// Used by [SplashScreen] to coordinate seamless transition to Home.
final appInitializedProvider =
    NotifierProvider<AppInitializationNotifier, bool>(
  AppInitializationNotifier.new,
);

class AppInitializationNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markInitialized() {
    state = true;
  }
}
