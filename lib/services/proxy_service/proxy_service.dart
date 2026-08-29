import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Proxy protocol options.
enum ProxyProtocol { http, https, socks5 }

/// Proxy Service — routes WebView traffic through HTTP/SOCKS proxy.
class ProxyService {
  const ProxyService();

  /// Applies proxy settings to Android InAppWebView ProxyController.
  Future<bool> applyProxy({
    required bool enabled,
    required String host,
    required int port,
    ProxyProtocol protocol = ProxyProtocol.http,
    List<String> bypassRules = const ['<local>', 'localhost', '127.0.0.1'],
  }) async {
    try {
      final proxyController = ProxyController.instance();
      if (!enabled || host.isEmpty || port <= 0) {
        await proxyController.clearProxyOverride();
        return true;
      }

      final scheme = protocol == ProxyProtocol.socks5 ? 'socks5' : 'http';
      final proxyUrl = '$scheme://$host:$port';

      final proxyRule = ProxyRule(url: proxyUrl);
      final settings = ProxySettings(
        proxyRules: [proxyRule],
        bypassRules: bypassRules,
      );

      await proxyController.setProxyOverride(settings: settings);
      return true;
    } catch (_) {
      // Platform fallback or mock environment
      return false;
    }
  }

  /// Tests latency / connectivity to the proxy host and port.
  Future<int?> testConnection(String host, int port, {Duration timeout = const Duration(seconds: 4)}) async {
    if (host.isEmpty || port <= 0) return null;
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      stopwatch.stop();
      await socket.close();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }
}
