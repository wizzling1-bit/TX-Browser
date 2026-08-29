import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../services/content_blocker/content_blocker_service.dart';
import 'database_provider.dart';

class ShieldSiteStats {
  const ShieldSiteStats({
    this.trackersBlocked = 0,
    this.adsBlocked = 0,
    this.popupsBlocked = 0,
    this.redirectsBlocked = 0,
    this.requestsBlocked = 0,
  });

  final int trackersBlocked;
  final int adsBlocked;
  final int popupsBlocked;
  final int redirectsBlocked;
  final int requestsBlocked;

  ShieldSiteStats increment(BlockReason reason) {
    switch (reason) {
      case BlockReason.tracker:
        return ShieldSiteStats(
          trackersBlocked: trackersBlocked + 1,
          adsBlocked: adsBlocked,
          popupsBlocked: popupsBlocked,
          redirectsBlocked: redirectsBlocked,
          requestsBlocked: requestsBlocked + 1,
        );
      case BlockReason.popup:
        return ShieldSiteStats(
          trackersBlocked: trackersBlocked,
          adsBlocked: adsBlocked,
          popupsBlocked: popupsBlocked + 1,
          redirectsBlocked: redirectsBlocked,
          requestsBlocked: requestsBlocked + 1,
        );
      case BlockReason.redirect:
        return ShieldSiteStats(
          trackersBlocked: trackersBlocked,
          adsBlocked: adsBlocked,
          popupsBlocked: popupsBlocked,
          redirectsBlocked: redirectsBlocked + 1,
          requestsBlocked: requestsBlocked + 1,
        );
      case BlockReason.ad:
      case BlockReason.customRule:
      case BlockReason.malwareOrScam:
        return ShieldSiteStats(
          trackersBlocked: trackersBlocked,
          adsBlocked: adsBlocked + 1,
          popupsBlocked: popupsBlocked,
          redirectsBlocked: redirectsBlocked,
          requestsBlocked: requestsBlocked + 1,
        );
    }
  }
}

class ShieldState {
  const ShieldState({
    this.isGlobalEnabled = true,
    this.statsByHost = const {},
    this.allowlistedHosts = const {},
  });

  final bool isGlobalEnabled;
  final Map<String, ShieldSiteStats> statsByHost;
  final Set<String> allowlistedHosts;

  ShieldSiteStats getStatsForHost(String? host) {
    if (host == null || host.isEmpty) return const ShieldSiteStats();
    return statsByHost[host.toLowerCase().trim()] ?? const ShieldSiteStats();
  }

  bool isShieldEnabledForHost(String? host) {
    if (!isGlobalEnabled) return false;
    if (host == null || host.isEmpty) return isGlobalEnabled;
    return !allowlistedHosts.contains(host.toLowerCase().trim());
  }

  ShieldState copyWith({
    bool? isGlobalEnabled,
    Map<String, ShieldSiteStats>? statsByHost,
    Set<String>? allowlistedHosts,
  }) {
    return ShieldState(
      isGlobalEnabled: isGlobalEnabled ?? this.isGlobalEnabled,
      statsByHost: statsByHost ?? this.statsByHost,
      allowlistedHosts: allowlistedHosts ?? this.allowlistedHosts,
    );
  }
}

class ShieldNotifier extends Notifier<ShieldState> {
  final _service = ContentBlockerService();

  ContentBlockerService get service => _service;
  AppDatabase get _db => ref.read(databaseProvider);

  @override
  ShieldState build() {
    _loadExceptions();
    return const ShieldState();
  }

  Future<void> _loadExceptions() async {
    final exceptions = await _db.getAllBlockerExceptions();
    final allowed = exceptions
        .where((e) => e.isAllowed)
        .map((e) => e.host.toLowerCase().trim())
        .toSet();
    _service.updateAllowlist(allowed);

    state = state.copyWith(allowlistedHosts: allowed);
  }

  void toggleGlobalShield(bool enabled) {
    _service.setGlobalEnabled(enabled);
    state = state.copyWith(isGlobalEnabled: enabled);
  }

  Future<void> toggleShieldForHost(String host, bool enabled) async {
    final normHost = host.toLowerCase().trim();
    if (normHost.isEmpty) return;

    if (enabled) {
      // Remove from allowlist (i.e. shield is ON)
      await _db.deleteBlockerException(normHost);
      final updated = Set<String>.from(state.allowlistedHosts)..remove(normHost);
      _service.updateAllowlist(updated);
      state = state.copyWith(allowlistedHosts: updated);
    } else {
      // Add to allowlist (i.e. shield is OFF for this site)
      await _db.setBlockerException(
        ContentBlockerExceptionsCompanion.insert(
          host: normHost,
          isAllowed: const Value(true),
        ),
      );
      final updated = Set<String>.from(state.allowlistedHosts)..add(normHost);
      _service.updateAllowlist(updated);
      state = state.copyWith(allowlistedHosts: updated);
    }
  }

  /// Resets protection and stats for a given site.
  Future<void> resetSiteProtection(String host) async {
    final normHost = host.toLowerCase().trim();
    if (normHost.isEmpty) return;

    await _db.deleteBlockerException(normHost);
    final updated = Set<String>.from(state.allowlistedHosts)..remove(normHost);
    _service.updateAllowlist(updated);

    final map = Map<String, ShieldSiteStats>.from(state.statsByHost);
    map.remove(normHost);

    state = state.copyWith(
      allowlistedHosts: updated,
      statsByHost: map,
    );
  }

  void recordBlockEvent({required String pageHost, required BlockReason reason}) {
    final normHost = pageHost.toLowerCase().trim();
    final currentStats = state.statsByHost[normHost] ?? const ShieldSiteStats();
    final updatedStats = currentStats.increment(reason);

    final map = Map<String, ShieldSiteStats>.from(state.statsByHost);
    map[normHost] = updatedStats;

    state = state.copyWith(statsByHost: map);
  }

  void resetStatsForHost(String pageHost) {
    final normHost = pageHost.toLowerCase().trim();
    final map = Map<String, ShieldSiteStats>.from(state.statsByHost);
    map.remove(normHost);
    state = state.copyWith(statsByHost: map);
  }
}

final shieldProvider = NotifierProvider<ShieldNotifier, ShieldState>(
  ShieldNotifier.new,
);
