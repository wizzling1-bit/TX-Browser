import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Download task status.
enum DownloadStatus { pending, downloading, paused, completed, failed, cancelled }

/// Download progress update model.
class DownloadProgress {
  const DownloadProgress({
    required this.bytesReceived,
    required this.totalBytes,
    required this.progressPercent,
  });

  final int bytesReceived;
  final int totalBytes;
  final int progressPercent;
}

/// Native Android query result.
class NativeDownloadStatus {
  const NativeDownloadStatus({
    required this.status,
    required this.bytesDownloaded,
    required this.totalBytes,
    this.filePath,
    this.reason = 0,
  });

  final DownloadStatus status;
  final int bytesDownloaded;
  final int totalBytes;
  final String? filePath;
  final int reason;
}

/// Production-Grade Download Service.
///
/// Multi-Layer Architecture:
/// - On Android: Uses `android.app.DownloadManager` via [MethodChannel] for OS-level background downloads,
///   system progress notifications, and direct storage in `Environment.DIRECTORY_DOWNLOADS`.
/// - On Non-Android / Tests: Uses streaming HTTP client with chunked progress reporting.
class DownloadService {
  const DownloadService();

  static const MethodChannel _channel = MethodChannel('com.wizzling.tx_browser/downloads');

  /// Enqueues a download via native [DownloadManager] on Android, or streaming HTTP on other platforms.
  Future<int?> enqueueNativeDownload({
    required String url,
    required String fileName,
    String? mimeType,
    String? userAgent,
    String? cookies,
  }) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final id = await _channel.invokeMethod<int>('enqueueDownload', {
          'url': url,
          'fileName': fileName,
          'mimeType': mimeType,
          'userAgent': userAgent,
          'cookies': cookies,
        });
        return id;
      } catch (e) {
        debugPrint('[DownloadService] Native enqueue error: $e');
      }
    }
    return null;
  }

  /// Queries the live progress and status of a native download by [androidDownloadId].
  Future<NativeDownloadStatus?> queryNativeDownload(int androidDownloadId) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final map = await _channel.invokeMapMethod<String, dynamic>('queryDownload', {
          'downloadId': androidDownloadId,
        });

        if (map != null && map.isNotEmpty) {
          final statusStr = map['status'] as String? ?? 'unknown';
          final bytesDownloaded = (map['bytesDownloaded'] as num?)?.toInt() ?? 0;
          final totalBytes = (map['totalBytes'] as num?)?.toInt() ?? 0;
          final filePath = map['filePath'] as String?;
          final reason = (map['reason'] as num?)?.toInt() ?? 0;

          return NativeDownloadStatus(
            status: _parseNativeStatus(statusStr),
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            filePath: filePath,
            reason: reason,
          );
        }
      } catch (e) {
        debugPrint('[DownloadService] Native query error: $e');
      }
    }
    return null;
  }

  /// Cancels an active download in Android's native [DownloadManager].
  Future<bool> cancelNativeDownload(int androidDownloadId) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final removed = await _channel.invokeMethod<bool>('cancelDownload', {
          'downloadId': androidDownloadId,
        });
        return removed ?? false;
      } catch (e) {
        debugPrint('[DownloadService] Native cancel error: $e');
      }
    }
    return false;
  }

  /// Fallback HTTP streaming download with headers, userAgent, cookies, and directory protection.
  Future<File> downloadFileFallback({
    required String url,
    required String fileName,
    required void Function(DownloadProgress progress) onProgress,
    String? userAgent,
    String? cookies,
    Map<String, String>? headers,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final request = http.Request('GET', Uri.parse(url));

    if (userAgent != null && userAgent.isNotEmpty) {
      request.headers['User-Agent'] = userAgent;
    }
    if (cookies != null && cookies.isNotEmpty) {
      request.headers['Cookie'] = cookies;
    }
    if (headers != null) {
      request.headers.addAll(headers);
    }
    request.headers['Accept'] = '*/*';

    final response = await httpClient.send(request);

    if (response.statusCode >= 400) {
      throw HttpException('Download failed with status: ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? 0;
    final dir = await _getStorageDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Ensure collision-free unique filename
    var targetFile = File(p.join(dir.path, fileName));
    if (await targetFile.exists()) {
      final ext = p.extension(fileName);
      final base = p.basenameWithoutExtension(fileName);
      var count = 1;
      while (await targetFile.exists()) {
        targetFile = File(p.join(dir.path, '$base ($count)$ext'));
        count++;
      }
    }

    final sink = targetFile.openWrite();
    var bytesReceived = 0;

    await for (final chunk in response.stream) {
      sink.add(chunk);
      bytesReceived += chunk.length;
      final percent = totalBytes > 0
          ? ((bytesReceived / totalBytes) * 100).clamp(0, 100).toInt()
          : 0;

      onProgress(DownloadProgress(
        bytesReceived: bytesReceived,
        totalBytes: totalBytes,
        progressPercent: percent,
      ));
    }

    await sink.flush();
    await sink.close();

    return targetFile;
  }

  /// Opens downloaded file in device's default viewer app via native FileProvider.
  Future<bool> openFile(String filePath, {String mimeType = '*/*'}) async {
    if (filePath.isEmpty) return false;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final opened = await _channel.invokeMethod<bool>('openFile', {
          'filePath': filePath,
          'mimeType': mimeType,
        });
        return opened ?? false;
      } catch (e) {
        debugPrint('[DownloadService] Native openFile error: $e');
      }
    }
    return false;
  }

  /// Deletes file from local storage.
  Future<bool> deleteFile(String filePath) async {
    if (filePath.isEmpty) return false;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  DownloadStatus _parseNativeStatus(String status) {
    switch (status.toLowerCase()) {
      case 'downloading':
        return DownloadStatus.downloading;
      case 'paused':
        return DownloadStatus.paused;
      case 'completed':
        return DownloadStatus.completed;
      case 'failed':
        return DownloadStatus.failed;
      case 'cancelled':
        return DownloadStatus.cancelled;
      default:
        return DownloadStatus.pending;
    }
  }

  Future<Directory> _getStorageDirectory() async {
    if (!kIsWeb && Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext;
    }
    return await getApplicationDocumentsDirectory();
  }
}
