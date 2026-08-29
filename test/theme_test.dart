import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tx_browser/core/theme/colors.dart';
import 'package:tx_browser/core/theme/theme_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TxTheme & Design Tokens', () {
    test('Light theme builds with correct tokens', () {
      final lightTheme = TxTheme.light();
      expect(lightTheme.brightness, equals(Brightness.light));
      expect(lightTheme.scaffoldBackgroundColor, equals(TxColorScheme.light.bg));
      expect(lightTheme.colorScheme.primary, equals(TxColorScheme.light.primary));

      final extension = lightTheme.extension<TxColorScheme>();
      expect(extension, isNotNull);
      expect(extension!.bg, equals(TxColorScheme.light.bg));
      expect(extension.surface, equals(TxColorScheme.light.surface));
      expect(extension.primary, equals(TxColorScheme.light.primary));
    });

    test('Dark theme swaps primary and secondary accents per DESIGN_SYSTEM.md §8', () {
      final darkTheme = TxTheme.dark();
      expect(darkTheme.brightness, equals(Brightness.dark));
      expect(darkTheme.scaffoldBackgroundColor, equals(TxColorScheme.dark.bg));

      // Vibrant leaf green becomes the primary accent in dark mode
      expect(darkTheme.colorScheme.primary, equals(TxColorScheme.dark.primary));
      expect(TxColorScheme.dark.primary, equals(const Color(0xFF69A86E)));
      // Sage becomes secondary
      expect(TxColorScheme.dark.secondary, equals(const Color(0xFF9DC08B)));
    });
  });
}
