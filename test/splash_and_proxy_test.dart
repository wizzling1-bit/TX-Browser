import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tx_browser/core/theme/colors.dart';
import 'package:tx_browser/features/splash/splash_screen.dart';
import 'package:tx_browser/features/exit/exit_screen.dart';
import 'package:tx_browser/services/proxy_service/proxy_service.dart';
import 'package:tx_browser/state/proxy_provider.dart';

void main() {
  group('ProxyService & State Tests', () {
    test('ProxyState defaults to disconnected', () {
      const state = ProxyState();
      expect(state.isEnabled, isFalse);
      expect(state.host, isEmpty);
      expect(state.port, equals(8080));
      expect(state.protocol, equals(ProxyProtocol.http));
      expect(state.isTesting, isFalse);
    });

    test('ProxyState copyWith correctly updates fields', () {
      const state = ProxyState();
      final updated = state.copyWith(
        isEnabled: true,
        host: '192.168.1.1',
        port: 9050,
        protocol: ProxyProtocol.socks5,
        latencyMs: 42,
        lastTestSuccess: true,
      );

      expect(updated.isEnabled, isTrue);
      expect(updated.host, equals('192.168.1.1'));
      expect(updated.port, equals(9050));
      expect(updated.protocol, equals(ProxyProtocol.socks5));
      expect(updated.latencyMs, equals(42));
      expect(updated.lastTestSuccess, isTrue);
    });

    test('ProxyService testConnection handles invalid host and port gracefully', () async {
      const service = ProxyService();
      final latency = await service.testConnection('', 0);
      expect(latency, isNull);
    });
  });

  group('SplashScreen Widget Tests', () {
    testWidgets('SplashScreen renders title and tagline', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              extensions: [TxColorScheme.light],
            ),
            home: const SplashScreen(),
          ),
        ),
      );

      expect(find.text('TX Browser'), findsOneWidget);
      expect(find.text('Premium. Private. Powerful.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
    });
  });

  group('ExitScreen Widget Tests', () {
    testWidgets('ExitScreen renders exit confirmation and buttons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              extensions: [TxColorScheme.light],
            ),
            home: const ExitScreen(),
          ),
        ),
      );

      expect(find.text('Ready to Exit?'), findsOneWidget);
      expect(find.text('Stay'), findsOneWidget);
      expect(find.text('Exit App'), findsOneWidget);
    });
  });
}
