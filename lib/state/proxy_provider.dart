import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../services/proxy_service/proxy_service.dart';
import 'database_provider.dart';

// ---------------------------------------------------------------------------
// Proxy Keys in Drift Settings
// ---------------------------------------------------------------------------

class ProxyKeys {
  ProxyKeys._();
  static const isEnabled = 'proxy_is_enabled';
  static const host = 'proxy_host';
  static const port = 'proxy_port';
  static const protocol = 'proxy_protocol';
  static const username = 'proxy_username';
  static const password = 'proxy_password';
}

// ---------------------------------------------------------------------------
// Proxy State Model
// ---------------------------------------------------------------------------

class ProxyState {
  const ProxyState({
    this.isEnabled = false,
    this.host = '',
    this.port = 8080,
    this.protocol = ProxyProtocol.http,
    this.username = '',
    this.password = '',
    this.isTesting = false,
    this.latencyMs,
    this.lastTestSuccess,
  });

  final bool isEnabled;
  final String host;
  final int port;
  final ProxyProtocol protocol;
  final String username;
  final String password;
  final bool isTesting;
  final int? latencyMs;
  final bool? lastTestSuccess;

  ProxyState copyWith({
    bool? isEnabled,
    String? host,
    int? port,
    ProxyProtocol? protocol,
    String? username,
    String? password,
    bool? isTesting,
    int? latencyMs,
    bool? lastTestSuccess,
  }) {
    return ProxyState(
      isEnabled: isEnabled ?? this.isEnabled,
      host: host ?? this.host,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      username: username ?? this.username,
      password: password ?? this.password,
      isTesting: isTesting ?? this.isTesting,
      latencyMs: latencyMs ?? this.latencyMs,
      lastTestSuccess: lastTestSuccess ?? this.lastTestSuccess,
    );
  }
}

// ---------------------------------------------------------------------------
// Proxy Notifier (Riverpod 3)
// ---------------------------------------------------------------------------

class ProxyNotifier extends Notifier<ProxyState> {
  final _service = const ProxyService();

  @override
  ProxyState build() {
    return const ProxyState();
  }

  AppDatabase get _db => ref.read(databaseProvider);

  /// Loads proxy settings on startup and configures WebView.
  Future<void> loadSettings() async {
    final enabledStr = await _db.getSetting(ProxyKeys.isEnabled);
    final host = await _db.getSetting(ProxyKeys.host) ?? '';
    final portStr = await _db.getSetting(ProxyKeys.port);
    final protoStr = await _db.getSetting(ProxyKeys.protocol);
    final user = await _db.getSetting(ProxyKeys.username) ?? '';
    final pass = await _db.getSetting(ProxyKeys.password) ?? '';

    final port = int.tryParse(portStr ?? '8080') ?? 8080;
    final isEnabled = enabledStr == 'true' && host.isNotEmpty;
    final protocol = _parseProtocol(protoStr);

    state = ProxyState(
      isEnabled: isEnabled,
      host: host,
      port: port,
      protocol: protocol,
      username: user,
      password: pass,
    );

    if (isEnabled) {
      await _service.applyProxy(
        enabled: true,
        host: host,
        port: port,
        protocol: protocol,
      );
    }
  }

  /// Saves and applies proxy configuration.
  Future<void> saveConfig({
    required bool enabled,
    required String host,
    required int port,
    required ProxyProtocol protocol,
    String username = '',
    String password = '',
  }) async {
    await _db.setSetting(ProxyKeys.isEnabled, enabled.toString());
    await _db.setSetting(ProxyKeys.host, host);
    await _db.setSetting(ProxyKeys.port, port.toString());
    await _db.setSetting(ProxyKeys.protocol, protocol.name);
    await _db.setSetting(ProxyKeys.username, username);
    await _db.setSetting(ProxyKeys.password, password);

    state = state.copyWith(
      isEnabled: enabled,
      host: host,
      port: port,
      protocol: protocol,
      username: username,
      password: password,
    );

    await _service.applyProxy(
      enabled: enabled,
      host: host,
      port: port,
      protocol: protocol,
    );
  }

  /// Toggle proxy on / off.
  Future<void> setEnabled(bool enabled) async {
    await _db.setSetting(ProxyKeys.isEnabled, enabled.toString());
    state = state.copyWith(isEnabled: enabled);

    await _service.applyProxy(
      enabled: enabled,
      host: state.host,
      port: state.port,
      protocol: state.protocol,
    );
  }

  /// Test connection latency to configured proxy.
  Future<bool> testCurrentConnection() async {
    state = state.copyWith(isTesting: true);
    final latency = await _service.testConnection(state.host, state.port);
    state = state.copyWith(
      isTesting: false,
      latencyMs: latency,
      lastTestSuccess: latency != null,
    );
    return latency != null;
  }

  ProxyProtocol _parseProtocol(String? name) {
    switch (name) {
      case 'https':
        return ProxyProtocol.https;
      case 'socks5':
        return ProxyProtocol.socks5;
      default:
        return ProxyProtocol.http;
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final proxyProvider =
    NotifierProvider<ProxyNotifier, ProxyState>(ProxyNotifier.new);
