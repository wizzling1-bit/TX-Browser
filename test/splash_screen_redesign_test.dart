import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tx_browser/core/theme/colors.dart';
import 'package:tx_browser/features/splash/splash_screen.dart';
import 'package:tx_browser/state/initialization_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSplashScreen({
    required bool isDark,
    bool disableAnimations = false,
  }) {
    final scheme = isDark ? TxColorScheme.dark : TxColorScheme.light;
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(
          brightness: isDark ? Brightness.dark : Brightness.light,
          scaffoldBackgroundColor: scheme.bg,
          extensions: [scheme],
        ),
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: disableAnimations,
          ),
          child: const SplashScreen(),
        ),
      ),
    );
  }

  group('TX Browser Redesigned SplashScreen Tests', () {
    testWidgets('renders all core brand components, typography and indicator', (tester) async {
      await tester.pumpWidget(buildSplashScreen(isDark: true));

      // Brand typography
      expect(find.text('TX Browser'), findsOneWidget);
      expect(find.text('Premium. Private. Powerful.'), findsOneWidget);

      // Status indicator & status copy
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Getting things ready…'), findsOneWidget);

      // Official logo image asset
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as AssetImage).assetName, 'assets/icons/tx_logo.png');

      // Scaffold background matches dark theme
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, TxColorScheme.dark.bg);
    });

    testWidgets('renders cleanly in Light Mode with authentic light theme tokens', (tester) async {
      await tester.pumpWidget(buildSplashScreen(isDark: false));

      expect(find.text('TX Browser'), findsOneWidget);
      expect(find.text('Premium. Private. Powerful.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Light mode background matches TxColorScheme.light.bg (#F2F5E8)
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, TxColorScheme.light.bg);
    });

    testWidgets('respects system reduced motion setting without throwing', (tester) async {
      await tester.pumpWidget(
        buildSplashScreen(isDark: true, disableAnimations: true),
      );

      expect(find.text('TX Browser'), findsOneWidget);
      expect(find.text('Premium. Private. Powerful.'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('TX Browser'), findsOneWidget);
    });

    testWidgets('reacts to appInitializedProvider state change', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: [TxColorScheme.dark],
            ),
            home: const SplashScreen(),
          ),
        ),
      );

      expect(find.text('TX Browser'), findsOneWidget);
      expect(container.read(appInitializedProvider), isFalse);

      // Simulate initialization complete
      container.read(appInitializedProvider.notifier).markInitialized();
      expect(container.read(appInitializedProvider), isTrue);

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
