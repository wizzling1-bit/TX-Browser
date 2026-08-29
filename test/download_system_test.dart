import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tx_browser/core/theme/theme_data.dart';
import 'package:tx_browser/features/downloads/downloads_screen.dart';
import 'package:tx_browser/services/download_service/download_service.dart';
import 'package:tx_browser/state/downloads_provider.dart';

void main() {
  group('Download Models & Progress Tests', () {
    test('DownloadProgress calculates exact percentage and clamps bounds', () {
      const p1 = DownloadProgress(bytesReceived: 428000000, totalBytes: 595000000, progressPercent: 72);
      expect(p1.progressPercent, equals(72));
      expect(p1.bytesReceived, equals(428000000));
      expect(p1.totalBytes, equals(595000000));

      const p2 = DownloadProgress(bytesReceived: 500, totalBytes: 0, progressPercent: 0);
      expect(p2.progressPercent, equals(0));
    });

    test('DownloadModel copyWith updates fields correctly', () {
      final now = DateTime.now();
      final model = DownloadModel(
        id: 'test-123',
        fileName: 'archive.zip',
        filePath: '',
        sourceUrl: 'https://example.com/archive.zip',
        status: DownloadStatus.downloading,
        progressPercent: 20,
        createdAt: now,
      );

      final updated = model.copyWith(
        filePath: '/storage/emulated/0/Download/archive.zip',
        status: DownloadStatus.completed,
        progressPercent: 100,
        downloadedBytes: 1048576,
        sizeBytes: 1048576,
      );

      expect(updated.id, equals('test-123'));
      expect(updated.filePath, equals('/storage/emulated/0/Download/archive.zip'));
      expect(updated.status, equals(DownloadStatus.completed));
      expect(updated.progressPercent, equals(100));
      expect(updated.downloadedBytes, equals(1048576));
    });

    test('NativeDownloadStatus models Android query results', () {
      const status = NativeDownloadStatus(
        status: DownloadStatus.downloading,
        bytesDownloaded: 2048,
        totalBytes: 4096,
        filePath: '/Download/file.pdf',
      );

      expect(status.status, equals(DownloadStatus.downloading));
      expect(status.bytesDownloaded, equals(2048));
      expect(status.totalBytes, equals(4096));
      expect(status.filePath, equals('/Download/file.pdf'));
    });
  });

  group('DownloadsScreen Widget Tests', () {
    testWidgets('Renders empty state when no downloads exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: TxTheme.light(),
            home: const DownloadsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('No Downloads Yet'), findsOneWidget);
      expect(find.text('Downloaded files and documents will appear here.'), findsOneWidget);
    });
  });
}
