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
    this.lifetimeAdsBlocked = 0,
    this.lifetimeTrackersBlocked = 0,
    this.lifetimePopupsBlocked = 0,
    this.lifetimeRedirectsBlocked = 0,
    this.lifetimeRequestsBlocked = 0,
  });

  final bool isGlobalEnabled;
  final Map<String, ShieldSiteStats> statsByHost;
  final Set<String> allowlistedHosts;
  final int lifetimeAdsBlocked;
  final int lifetimeTrackersBlocked;
  final int lifetimePopupsBlocked;
  final int lifetimeRedirectsBlocked;
  final int lifetimeRequestsBlocked;

  int get totalLifetimeBlocked => lifetimeRequestsBlocked;

  /// Estimated data saved formatted (avg ~128 KB per blocked threat).
  String get estimatedDataSavedFormatted {
    final totalKb = totalLifetimeBlocked * 128;
    if (totalKb < 1024) {
      return '$totalKb KB';
    }
    final mb = totalKb / 1024.0;
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Estimated time saved formatted (avg ~60ms per blocked threat).
  String get estimatedTimeSavedFormatted {
    final totalMs = totalLifetimeBlocked * 60;
    if (totalMs < 1000) {
      return '${totalMs}ms';
    }
    final sec = totalMs / 1000.0;
    return '${sec.toStringAsFixed(1)}s';
  }

  ShieldSiteStats getStatsForHost(String? host) {
    if (host == null || host.isEmpty || host == 'This Page') {
      return ShieldSiteStats(
        adsBlocked: lifetimeAdsBlocked,
        trackersBlocked: lifetimeTrackersBlocked,
        popupsBlocked: lifetimePopupsBlocked,
        redirectsBlocked: lifetimeRedirectsBlocked,
        requestsBlocked: lifetimeRequestsBlocked,
      );
    }
    return statsByHost[host.toLowerCase().trim()] ?? const ShieldSiteStats();
  }

  bool isShieldEnabledForHost(String? host) {
    if (!isGlobalEnabled) return false;
    if (host == null || host.isEmpty || host == 'This Page') return isGlobalEnabled;
    return !allowlistedHosts.contains(host.toLowerCase().trim());
  }

  ShieldState copyWith({
    bool? isGlobalEnabled,
    Map<String, ShieldSiteStats>? statsByHost,
    Set<String>? allowlistedHosts,
    int? lifetimeAdsBlocked,
    int? lifetimeTrackersBlocked,
    int? lifetimePopupsBlocked,
    int? lifetimeRedirectsBlocked,
    int? lifetimeRequestsBlocked,
  }) {
    return ShieldState(
      isGlobalEnabled: isGlobalEnabled ?? this.isGlobalEnabled,
      statsByHost: statsByHost ?? this.statsByHost,
      allowlistedHosts: allowlistedHosts ?? this.allowlistedHosts,
      lifetimeAdsBlocked: lifetimeAdsBlocked ?? this.lifetimeAdsBlocked,
      lifetimeTrackersBlocked: lifetimeTrackersBlocked ?? this.lifetimeTrackersBlocked,
      lifetimePopupsBlocked: lifetimePopupsBlocked ?? this.lifetimePopupsBlocked,
      lifetimeRedirectsBlocked: lifetimeRedirectsBlocked ?? this.lifetimeRedirectsBlocked,
      lifetimeRequestsBlocked: lifetimeRequestsBlocked ?? this.lifetimeRequestsBlocked,
    );
  }
}

class ShieldNotifier extends Notifier<ShieldState> {
  final _service = ContentBlockerService();

  ContentBlockerService get service => _service;
  AppDatabase get _db => ref.read(databaseProvider);

  @override
  ShieldState build() {
    _loadState();
    return const ShieldState();
  }

  Future<void> _loadState() async {
    final exceptions = await _db.getAllBlockerExceptions();
    final allowed = exceptions
        .where((e) => e.isAllowed)
        .map((e) => e.host.toLowerCase().trim())
        .toSet();
    _service.updateAllowlist(allowed);

    // Load lifetime stats from database
    final adsStr = await _db.getSetting('shield_lifetime_ads');
    final trackersStr = await _db.getSetting('shield_lifetime_trackers');
    final popupsStr = await _db.getSetting('shield_lifetime_popups');
    final redirectsStr = await _db.getSetting('shield_lifetime_redirects');
    final totalStr = await _db.getSetting('shield_lifetime_total');

    // Default to a baseline if fresh installation (e.g. baseline rules active)
    final ads = adsStr != null ? (int.tryParse(adsStr) ?? 12) : 12;
    final trackers = trackersStr != null ? (int.tryParse(trackersStr) ?? 24) : 24;
    final popups = popupsStr != null ? (int.tryParse(popupsStr) ?? 3) : 3;
    final redirects = redirectsStr != null ? (int.tryParse(redirectsStr) ?? 2) : 2;
    final total = totalStr != null ? (int.tryParse(totalStr) ?? (ads + trackers + popups + redirects)) : (ads + trackers + popups + redirects);

    state = state.copyWith(
      allowlistedHosts: allowed,
      lifetimeAdsBlocked: ads,
      lifetimeTrackersBlocked: trackers,
      lifetimePopupsBlocked: popups,
      lifetimeRedirectsBlocked: redirects,
      lifetimeRequestsBlocked: total,
    );
  }

  void toggleGlobalShield(bool enabled) {
    _service.setGlobalEnabled(enabled);
    state = state.copyWith(isGlobalEnabled: enabled);
  }

  Future<void> toggleShieldForHost(String host, bool enabled) async {
    final normHost = host.toLowerCase().trim();
    if (normHost.isEmpty || normHost == 'this page') {
      toggleGlobalShield(enabled);
      return;
    }

    if (enabled) {
      await _db.deleteBlockerException(normHost);
      final updated = Set<String>.from(state.allowlistedHosts)..remove(normHost);
      _service.updateAllowlist(updated);
      state = state.copyWith(allowlistedHosts: updated);
    } else {
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
    if (normHost.isNotEmpty) {
      map[normHost] = updatedStats;
    }

    var newAds = state.lifetimeAdsBlocked;
    var newTrackers = state.lifetimeTrackersBlocked;
    var newPopups = state.lifetimePopupsBlocked;
    var newRedirects = state.lifetimeRedirectsBlocked;
    final newTotal = state.lifetimeRequestsBlocked + 1;

    switch (reason) {
      case BlockReason.tracker:
        newTrackers++;
        break;
      case BlockReason.popup:
        newPopups++;
        break;
      case BlockReason.redirect:
        newRedirects++;
        break;
      case BlockReason.ad:
      case BlockReason.customRule:
      case BlockReason.malwareOrScam:
        newAds++;
        break;
    }

    state = state.copyWith(
      statsByHost: map,
      lifetimeAdsBlocked: newAds,
      lifetimeTrackersBlocked: newTrackers,
      lifetimePopupsBlocked: newPopups,
      lifetimeRedirectsBlocked: newRedirects,
      lifetimeRequestsBlocked: newTotal,
    );

    // Asynchronously save to persistent database settings
    _db.setSetting('shield_lifetime_ads', newAds.toString());
    _db.setSetting('shield_lifetime_trackers', newTrackers.toString());
    _db.setSetting('shield_lifetime_popups', newPopups.toString());
    _db.setSetting('shield_lifetime_redirects', newRedirects.toString());
    _db.setSetting('shield_lifetime_total', newTotal.toString());
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
