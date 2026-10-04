import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tx_browser/core/theme/colors.dart';
import 'package:tx_browser/state/downloads_provider.dart';
import 'package:tx_browser/state/rewarded_perks_provider.dart';
import 'package:tx_browser/widgets/dialogs/app_menu_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildMenuSheet({
    required bool isHomeScreen,
    String currentUrl = '',
    bool isBookmarked = false,
    bool isDesktopMode = false,
    RewardedPerksState? perksState,
    List<DownloadModel>? downloadsList,
    VoidCallback? onUnlockAdFreePass,
    VoidCallback? onToggleBookmark,
    VoidCallback? onToggleDesktopMode,
    VoidCallback? onFindInPage,
    VoidCallback? onShare,
    VoidCallback? onPinToHome,
  }) {
    const scheme = TxColorScheme.dark;
    return ProviderScope(
      overrides: [
        if (perksState != null)
          rewardedPerksProvider.overrideWith(() => _MockRewardedPerksNotifier(perksState)),
        if (downloadsList != null)
          downloadsProvider.overrideWith(() => _MockDownloadsNotifier(downloadsList)),
      ],
      child: MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: scheme.bg,
          extensions: const [scheme],
        ),
        home: Scaffold(
          body: TxAppMenuSheet(
            isHomeScreen: isHomeScreen,
            currentUrl: currentUrl,
            isBookmarked: isBookmarked,
            isDesktopMode: isDesktopMode,
            onUnlockAdFreePass: onUnlockAdFreePass,
            onToggleBookmark: onToggleBookmark,
            onToggleDesktopMode: onToggleDesktopMode,
            onFindInPage: onFindInPage,
            onShare: onShare,
            onPinToHome: onPinToHome,
          ),
        ),
      ),
    );
  }

  group('TxAppMenuSheet Redesign Widget Tests', () {
    testWidgets('renders all core components on Home screen', (tester) async {
      await tester.pumpWidget(buildMenuSheet(isHomeScreen: true));

      // 1. Ad-Free Pass Header Card
      expect(find.text('10-Min Ad-Free Pass'), findsOneWidget);
      expect(find.text('Unlock'), findsOneWidget);

      // 2. 3x2 Quick Actions Grid
      expect(find.text('New tab'), findsOneWidget);
      expect(find.text('Private tab'), findsOneWidget);
      expect(find.text('Bookmarks'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // 3. Featured TX Shield & Privacy Card
      expect(find.text('TX Shield & Privacy'), findsOneWidget);
      expect(find.text('Protected'), findsOneWidget);

      // 4. Safe Exit Button
      expect(find.text('Exit TX Browser'), findsOneWidget);
      expect(find.text('Safely close tabs and purge private session'), findsOneWidget);
    });

    testWidgets('displays active countdown when Ad-Free Pass is active', (tester) async {
      final activePerks = RewardedPerksState(
        adFreeUntil: DateTime.now().add(const Duration(minutes: 8, seconds: 30)),
      );

      await tester.pumpWidget(buildMenuSheet(
        isHomeScreen: true,
        perksState: activePerks,
      ));

      expect(find.text('10-Min Ad-Free Pass'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.textContaining('Active •'), findsOneWidget);
    });

    testWidgets('renders browser-specific grid and secondary list in Browser screen', (tester) async {
      await tester.pumpWidget(buildMenuSheet(
        isHomeScreen: false,
        currentUrl: 'https://example.com',
        isBookmarked: true,
        isDesktopMode: false,
      ));

      // Quick Actions Grid for Browser
      expect(find.text('New tab'), findsOneWidget);
      expect(find.text('Private tab'), findsOneWidget);
      expect(find.text('Bookmarked'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Find in page'), findsOneWidget);
      expect(find.text('Desktop site'), findsOneWidget);

      // TX Shield site stats
      expect(find.text('Active for example.com'), findsOneWidget);

      // Secondary list items
      expect(find.text('Pinned Sites'), findsOneWidget);
      expect(find.text('Pin to Home screen'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Exit button is NOT shown in browser screen
      expect(find.text('Exit TX Browser'), findsNothing);
    });

    testWidgets('fires onUnlockAdFreePass callback when tapped', (tester) async {
      bool unlocked = false;
      await tester.pumpWidget(buildMenuSheet(
        isHomeScreen: true,
        onUnlockAdFreePass: () => unlocked = true,
      ));

      await tester.tap(find.text('10-Min Ad-Free Pass'));
      expect(unlocked, isTrue);
    });
  });
}

class _MockRewardedPerksNotifier extends RewardedPerksNotifier {
  _MockRewardedPerksNotifier(this._initialState);
  final RewardedPerksState _initialState;

  @override
  RewardedPerksState build() => _initialState;
}

class _MockDownloadsNotifier extends DownloadsNotifier {
  _MockDownloadsNotifier(this._initialState);
  final List<DownloadModel> _initialState;

  @override
  List<DownloadModel> build() => _initialState;
}
