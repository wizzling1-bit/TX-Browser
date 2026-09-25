import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import '../data/database/app_database.dart';
import '../services/download_service/download_service.dart';
import 'database_provider.dart';

// ---------------------------------------------------------------------------
// Download Model (in-memory)
// ---------------------------------------------------------------------------

class DownloadModel {
  const DownloadModel({
    required this.id,
    this.androidDownloadId,
    required this.fileName,
    required this.filePath,
    required this.sourceUrl,
    this.mimeType = 'application/octet-stream',
    this.sizeBytes = 0,
    this.downloadedBytes = 0,
    this.speedBytesPerSec = 0,
    this.status = DownloadStatus.pending,
    this.progressPercent = 0,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final int? androidDownloadId;
  final String fileName;
  final String filePath;
  final String sourceUrl;
  final String mimeType;
  final int sizeBytes;
  final int downloadedBytes;
  final int speedBytesPerSec;
  final DownloadStatus status;
  final int progressPercent;
  final DateTime createdAt;
  final DateTime? completedAt;

  DownloadModel copyWith({
    int? androidDownloadId,
    String? filePath,
    int? sizeBytes,
    int? downloadedBytes,
    int? speedBytesPerSec,
    DownloadStatus? status,
    int? progressPercent,
    DateTime? completedAt,
  }) {
    return DownloadModel(
      id: id,
      androidDownloadId: androidDownloadId ?? this.androidDownloadId,
      fileName: fileName,
      filePath: filePath ?? this.filePath,
      sourceUrl: sourceUrl,
      mimeType: mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      status: status ?? this.status,
      progressPercent: progressPercent ?? this.progressPercent,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Downloads Notifier (Riverpod 3)
// ---------------------------------------------------------------------------

class DownloadsNotifier extends Notifier<List<DownloadModel>> {
  static const _uuid = Uuid();
  final _service = const DownloadService();
  Timer? _pollingTimer;

  // Track previous bytes for calculating real-time download speed
  final Map<String, int> _lastSampledBytes = {};
  DateTime _lastSampleTime = DateTime.now();

  @override
  List<DownloadModel> build() {
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });
    return [];
  }

  AppDatabase get _db => ref.read(databaseProvider);

  /// Load downloads from Drift SQLite and reconcile with native Android state.
  Future<void> loadDownloads() async {
    final entries = await _db.getAllDownloads();
    final models = <DownloadModel>[];

    for (final d in entries) {
      final status = _parseStatus(d.status);
      models.add(DownloadModel(
        id: d.id,
        androidDownloadId: d.androidDownloadId,
        fileName: d.fileName,
        filePath: d.filePath,
        sourceUrl: d.sourceUrl,
        mimeType: d.mimeType,
        sizeBytes: d.sizeBytes,
        downloadedBytes: status == DownloadStatus.completed ? d.sizeBytes : 0,
        status: status,
        progressPercent: d.progressPercent,
        createdAt: d.createdAt,
        completedAt: d.completedAt,
      ));
    }
    state = models;

    _checkAndStartPolling();
  }

  /// Start a new download.
  Future<void> startDownload(
    String url, {
    String? customFileName,
    String? mimeType,
    String? userAgent,
    String? cookies,
  }) async {
    final id = _uuid.v4();
    final uri = Uri.parse(url);
    final fileName = customFileName ??
        (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'download_${DateTime.now().millisecondsSinceEpoch}');
    final resolvedMime = mimeType ?? _guessMimeType(fileName);

    // 1. Try native Android DownloadManager
    final androidDownloadId = await _service.enqueueNativeDownload(
      url: url,
      fileName: fileName,
      mimeType: resolvedMime,
      userAgent: userAgent,
      cookies: cookies,
    );

    final initialModel = DownloadModel(
      id: id,
      androidDownloadId: androidDownloadId,
      fileName: fileName,
      filePath: '',
      sourceUrl: url,
      mimeType: resolvedMime,
      status: DownloadStatus.downloading,
      progressPercent: 0,
      createdAt: DateTime.now(),
    );

    state = [initialModel, ...state];

    await _db.insertDownload(DownloadsCompanion.insert(
      id: id,
      fileName: fileName,
      filePath: '',
      sourceUrl: url,
      mimeType: Value(resolvedMime),
      status: const Value('downloading'),
      progressPercent: const Value(0),
      androidDownloadId: Value(androidDownloadId),
    ));

    if (androidDownloadId != null) {
      // Native download enqueued successfully, activate progress polling
      _checkAndStartPolling();
    } else {
      // Non-Android / fallback download
      _startFallbackDownload(id, url, fileName);
    }
  }

  void _startFallbackDownload(String id, String url, String fileName) async {
    var lastReportedPercent = -1;

    try {
      final file = await _service.downloadFileFallback(
        url: url,
        fileName: fileName,
        onProgress: (progress) {
          if (progress.progressPercent != lastReportedPercent) {
            lastReportedPercent = progress.progressPercent;
            state = state.map((item) {
              if (item.id == id) {
                return item.copyWith(
                  progressPercent: progress.progressPercent,
                  downloadedBytes: progress.bytesReceived,
                  sizeBytes: progress.totalBytes > 0 ? progress.totalBytes : progress.bytesReceived,
                );
              }
              return item;
            }).toList();
          }
        },
      );

      final completedAt = DateTime.now();
      final fileSize = await file.length();

      await _db.updateDownload(DownloadsCompanion(
        id: Value(id),
        filePath: Value(file.path),
        status: const Value('completed'),
        sizeBytes: Value(fileSize),
        progressPercent: const Value(100),
        completedAt: Value(completedAt),
      ));

      DownloadModel? completedModel;
      state = state.map((item) {
        if (item.id == id) {
          final updated = item.copyWith(
            filePath: file.path,
            status: DownloadStatus.completed,
            progressPercent: 100,
            downloadedBytes: fileSize,
            sizeBytes: fileSize,
            completedAt: completedAt,
          );
          completedModel = updated;
          return updated;
        }
        return item;
      }).toList();
      if (completedModel != null) {
        ref.read(downloadCompletedEventProvider.notifier).emit(completedModel!);
      }
    } catch (_) {
      await _db.updateDownload(DownloadsCompanion(
        id: Value(id),
        status: const Value('failed'),
      ));

      state = state.map((item) {
        if (item.id == id) {
          return item.copyWith(status: DownloadStatus.failed);
        }
        return item;
      }).toList();
    }
  }

  void _checkAndStartPolling() {
    final hasActiveDownloads = state.any(
      (d) => d.status == DownloadStatus.downloading && d.androidDownloadId != null,
    );

    if (hasActiveDownloads && (_pollingTimer == null || !_pollingTimer!.isActive)) {
      _pollingTimer = Timer.periodic(const Duration(milliseconds: 600), (_) => _pollActiveDownloads());
    } else if (!hasActiveDownloads) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  Future<void> _pollActiveDownloads() async {
    final now = DateTime.now();
    final elapsedSec = now.difference(_lastSampleTime).inMilliseconds / 1000.0;
    _lastSampleTime = now;

    var stateChanged = false;
    final updatedList = <DownloadModel>[];

    for (final item in state) {
      if (item.status == DownloadStatus.downloading && item.androidDownloadId != null) {
        final nativeStatus = await _service.queryNativeDownload(item.androidDownloadId!);
        if (nativeStatus != null) {
          final bytes = nativeStatus.bytesDownloaded;
          final total = nativeStatus.totalBytes;
          final percent = total > 0 ? ((bytes / total) * 100).clamp(0, 100).toInt() : 0;

          // Calculate speed
          final prevBytes = _lastSampleBytes(item.id, bytes);
          final speed = elapsedSec > 0 ? ((bytes - prevBytes) / elapsedSec).clamp(0, 100000000).toInt() : 0;
          _lastSampledBytes[item.id] = bytes;

          final isFinished = nativeStatus.status == DownloadStatus.completed;
          final isFailed = nativeStatus.status == DownloadStatus.failed;

          if (isFinished || isFailed || percent != item.progressPercent || bytes != item.downloadedBytes) {
            stateChanged = true;
            final updated = item.copyWith(
              status: nativeStatus.status,
              progressPercent: isFinished ? 100 : percent,
              downloadedBytes: bytes,
              sizeBytes: total > 0 ? total : bytes,
              speedBytesPerSec: isFinished ? 0 : speed,
              filePath: nativeStatus.filePath ?? item.filePath,
              completedAt: isFinished ? DateTime.now() : item.completedAt,
            );

            if (isFinished || isFailed) {
              await _db.updateDownload(DownloadsCompanion(
                id: Value(item.id),
                status: Value(nativeStatus.status.name),
                filePath: Value(updated.filePath),
                sizeBytes: Value(updated.sizeBytes),
                progressPercent: Value(updated.progressPercent),
                completedAt: Value(updated.completedAt),
              ));
              if (isFinished) {
                ref.read(downloadCompletedEventProvider.notifier).emit(updated);
              }
            }

            updatedList.add(updated);
            continue;
          }
        }
      }
      updatedList.add(item);
    }

    if (stateChanged) {
      state = updatedList;
      _checkAndStartPolling();
    }
  }

  int _lastSampleBytes(String id, int currentBytes) {
    return _lastSampledBytes[id] ?? currentBytes;
  }

  /// Cancel an in-flight download.
  Future<void> cancelDownload(String id) async {
    final item = state.firstWhere((d) => d.id == id, orElse: () => state.first);
    if (item.androidDownloadId != null) {
      await _service.cancelNativeDownload(item.androidDownloadId!);
    }

    await _db.updateDownload(DownloadsCompanion(
      id: Value(id),
      status: const Value('cancelled'),
    ));

    state = state.map((d) {
      if (d.id == id) {
        return d.copyWith(status: DownloadStatus.cancelled, speedBytesPerSec: 0);
      }
      return d;
    }).toList();

    _checkAndStartPolling();
  }

  /// Open a completed download in the system viewer.
  Future<void> openDownload(String id) async {
    final item = state.firstWhere((d) => d.id == id);
    if (item.filePath.isNotEmpty) {
      await _service.openFile(item.filePath);
    }
  }

  /// Delete a download record and its local file.
  Future<void> deleteDownload(String id) async {
    final item = state.firstWhere((d) => d.id == id, orElse: () => state.first);
    if (item.filePath.isNotEmpty) {
      await _service.deleteFile(item.filePath);
    }

    await _db.deleteDownload(id);
    state = state.where((d) => d.id != id).toList();
    _lastSampledBytes.remove(id);
  }

  DownloadStatus _parseStatus(String s) {
    switch (s) {
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

  String _guessMimeType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.mp4':
        return 'video/mp4';
      case '.mp3':
        return 'audio/mpeg';
      case '.zip':
        return 'application/zip';
      case '.apk':
        return 'application/vnd.android.package-archive';
      default:
        return 'application/octet-stream';
    }
  }
}

final downloadsProvider = NotifierProvider<DownloadsNotifier, List<DownloadModel>>(
  DownloadsNotifier.new,
);

/// Notifier broadcasting the most recently completed download for bottom sheet display.
class DownloadCompleteEventNotifier extends Notifier<DownloadModel?> {
  @override
  DownloadModel? build() => null;

  void emit(DownloadModel model) {
    state = model;
  }

  void reset() {
    state = null;
  }
}

final downloadCompletedEventProvider =
    NotifierProvider<DownloadCompleteEventNotifier, DownloadModel?>(
  DownloadCompleteEventNotifier.new,
);
