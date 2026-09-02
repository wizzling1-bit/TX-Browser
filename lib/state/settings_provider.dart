import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/search_engines.dart';
import '../data/database/app_database.dart';
import 'database_provider.dart';

// ---------------------------------------------------------------------------
// Settings keys
// ---------------------------------------------------------------------------

class SettingsKeys {
  SettingsKeys._();

  static const themeMode = 'theme_mode';
  static const defaultSearchEngine = 'default_search_engine';
  static const homepageMode = 'homepage_mode';
  static const desktopSiteDefault = 'desktop_site_default';
  static const onboardingComplete = 'onboarding_complete';
  static const autoClearPolicy = 'auto_clear_policy';
}

// ---------------------------------------------------------------------------
// Settings state
// ---------------------------------------------------------------------------

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.searchEngine = SearchEngine.google,
    this.homepageMode = 'tx_home',
    this.desktopSiteDefault = false,
    this.onboardingComplete = false,
    this.autoClearPolicy = 'never',
  });

  final ThemeMode themeMode;
  final SearchEngine searchEngine;
  final String homepageMode;
  final bool desktopSiteDefault;
  final bool onboardingComplete;
  final String autoClearPolicy;

  AppSettings copyWith({
    ThemeMode? themeMode,
    SearchEngine? searchEngine,
    String? homepageMode,
    bool? desktopSiteDefault,
    bool? onboardingComplete,
    String? autoClearPolicy,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      searchEngine: searchEngine ?? this.searchEngine,
      homepageMode: homepageMode ?? this.homepageMode,
      desktopSiteDefault: desktopSiteDefault ?? this.desktopSiteDefault,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      autoClearPolicy: autoClearPolicy ?? this.autoClearPolicy,
    );
  }
}

// ---------------------------------------------------------------------------
// Settings notifier (Riverpod 3 Notifier)
// ---------------------------------------------------------------------------

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    return const AppSettings();
  }

  AppDatabase get _db => ref.read(databaseProvider);

  /// Loads all settings from Drift on startup.
  Future<void> loadSettings() async {
    final themeStr = await _db.getSetting(SettingsKeys.themeMode);
    final engineStr = await _db.getSetting(SettingsKeys.defaultSearchEngine);
    final homepageStr = await _db.getSetting(SettingsKeys.homepageMode);
    final desktopStr = await _db.getSetting(SettingsKeys.desktopSiteDefault);
    final onboardingStr = await _db.getSetting(SettingsKeys.onboardingComplete);
    final autoClearStr = await _db.getSetting(SettingsKeys.autoClearPolicy);

    state = AppSettings(
      themeMode: _parseThemeMode(themeStr),
      searchEngine: SearchEngine.fromName(engineStr),
      homepageMode: homepageStr ?? 'tx_home',
      desktopSiteDefault: desktopStr == 'true',
      onboardingComplete: onboardingStr == 'true',
      autoClearPolicy: autoClearStr ?? 'never',
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _db.setSetting(SettingsKeys.themeMode, mode.name);
  }

  Future<void> setSearchEngine(SearchEngine engine) async {
    state = state.copyWith(searchEngine: engine);
    await _db.setSetting(SettingsKeys.defaultSearchEngine, engine.name);
  }

  Future<void> setHomepageMode(String mode) async {
    state = state.copyWith(homepageMode: mode);
    await _db.setSetting(SettingsKeys.homepageMode, mode);
  }

  Future<void> setDesktopSiteDefault(bool enabled) async {
    state = state.copyWith(desktopSiteDefault: enabled);
    await _db.setSetting(
        SettingsKeys.desktopSiteDefault, enabled.toString());
  }

  Future<void> setAutoClearPolicy(String policy) async {
    state = state.copyWith(autoClearPolicy: policy);
    await _db.setSetting(SettingsKeys.autoClearPolicy, policy);
  }

  Future<void> setOnboardingComplete(bool complete) async {
    state = state.copyWith(onboardingComplete: complete);
    await _db.setSetting(
        SettingsKeys.onboardingComplete, complete.toString());
  }

  ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
