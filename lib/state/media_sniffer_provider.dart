import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/media_sniffer_service/media_patterns.dart';
import '../services/media_sniffer_service/media_sniffer_service.dart';

// ---------------------------------------------------------------------------
// Sniffed Media Model
// ---------------------------------------------------------------------------

class SniffedMedia {
  const SniffedMedia({
    required this.id,
    required this.url,
    required this.normalizedUrl,
    required this.fileName,
    required this.mimeType,
    required this.sourceHost,
    this.title,
    this.thumbnailUrl,
    this.resolution,
    this.estimatedSizeBytes,
    required this.isStream,
    required this.isPolicyBlocked,
    required this.isVideo,
    required this.isAudio,
    required this.detectedAt,
  });

  final String id;
  final String url;
  final String normalizedUrl;
  final String fileName;
  final String mimeType;
  final String sourceHost;
  final String? title;
  final String? thumbnailUrl;
  final String? resolution;
  final int? estimatedSizeBytes;
  final bool isStream;
  final bool isPolicyBlocked;
  final bool isVideo;
  final bool isAudio;
  final DateTime detectedAt;

  /// Canonical group key for clustering chunks and variations of the same video.
  String get groupKey {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      if (host.contains('googlevideo.com') || host.contains('youtube.com')) {
        final ytId = uri.queryParameters['id'] ?? uri.queryParameters['docid'];
        if (ytId != null && ytId.isNotEmpty) {
          return 'yt_$ytId';
        }
      }
      if (title != null && title!.isNotEmpty && !title!.startsWith('http') && title != 'New Tab') {
        return '${host}_${title!.trim().toLowerCase()}';
      }
      return uri.replace(query: '', fragment: '').toString();
    } catch (_) {
      return normalizedUrl;
    }
  }

  String get formattedSize {
    if (isStream) return 'Adaptive Stream';
    if (estimatedSizeBytes != null && estimatedSizeBytes! > 0) {
      const suffixes = ['B', 'KB', 'MB', 'GB'];
      var i = 0;
      double d = estimatedSizeBytes!.toDouble();
      while (d >= 1024 && i < suffixes.length - 1) {
        d /= 1024;
        i++;
      }
      return '${d.toStringAsFixed(1)} ${suffixes[i]}';
    }
    return 'Ready to Download';
  }

  SniffedMedia copyWith({
    String? url,
    String? fileName,
    String? mimeType,
    String? title,
    String? thumbnailUrl,
    String? resolution,
    int? estimatedSizeBytes,
    bool clearEstimatedSize = false,
    bool? isStream,
    bool? isPolicyBlocked,
  }) {
    return SniffedMedia(
      id: id,
      url: url ?? this.url,
      normalizedUrl: normalizedUrl,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      sourceHost: sourceHost,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      resolution: resolution ?? this.resolution,
      estimatedSizeBytes: clearEstimatedSize ? null : (estimatedSizeBytes ?? this.estimatedSizeBytes),
      isStream: isStream ?? this.isStream,
      isPolicyBlocked: isPolicyBlocked ?? this.isPolicyBlocked,
      isVideo: isVideo,
      isAudio: isAudio,
      detectedAt: detectedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Media Sniffer State
// ---------------------------------------------------------------------------

class MediaSnifferState {
  const MediaSnifferState({
    this.items = const [],
    this.isScanning = false,
  });

  final List<SniffedMedia> items;
  final bool isScanning;

  bool get hasMedia => items.isNotEmpty;

  List<SniffedMedia> get downloadableItems =>
      items.where((item) => !item.isPolicyBlocked).toList();

  int get downloadableCount => downloadableItems.length;

  MediaSnifferState copyWith({
    List<SniffedMedia>? items,
    bool? isScanning,
  }) {
    return MediaSnifferState(
      items: items ?? this.items,
      isScanning: isScanning ?? this.isScanning,
    );
  }
}

// ---------------------------------------------------------------------------
// Media Sniffer Notifier (Riverpod 3)
// ---------------------------------------------------------------------------

class MediaSnifferNotifier extends Notifier<MediaSnifferState> {
  final _service = MediaSnifferService.instance;

  @override
  MediaSnifferState build() {
    return const MediaSnifferState();
  }

  /// Evaluates an incoming URL and enqueues it if valid media.
  void addMediaFromUrl(
    String url, {
    String? contentType,
    String? pageTitle,
    String? posterUrl,
    int? videoWidth,
    int? videoHeight,
  }) {
    final candidate = _service.evaluateUrl(
      url,
      contentType: contentType,
      pageTitle: pageTitle,
      posterUrl: posterUrl,
      videoWidth: videoWidth,
      videoHeight: videoHeight,
    );

    if (candidate == null) return;

    final groupKey = candidate.groupKey;
    final existingIndex = state.items.indexWhere(
      (m) => m.groupKey == groupKey || m.normalizedUrl == candidate.normalizedUrl || m.url == candidate.url,
    );

    if (existingIndex != -1) {
      final existing = state.items[existingIndex];
      final newScore = _calculateMediaScore(candidate);
      final existingScore = _calculateScoreFromMedia(existing);

      if (newScore > existingScore) {
        // Upgrade to the better, complete working stream format
        final updatedList = List<SniffedMedia>.from(state.items);
        updatedList[existingIndex] = existing.copyWith(
          url: candidate.url,
          fileName: candidate.fileName,
          mimeType: candidate.mimeType,
          resolution: candidate.resolution ?? existing.resolution,
          estimatedSizeBytes: candidate.estimatedSizeBytes ?? existing.estimatedSizeBytes,
          thumbnailUrl: candidate.thumbnailUrl ?? existing.thumbnailUrl,
          title: (candidate.title != null && !candidate.title!.startsWith('http'))
              ? candidate.title
              : existing.title,
          isStream: candidate.isStream,
        );
        state = state.copyWith(items: updatedList);
      } else {
        // Existing is already better; merge any missing metadata in the background
        final titleNeedsUpdate = (existing.title == null || existing.title!.startsWith('http')) &&
            candidate.title != null &&
            !candidate.title!.startsWith('http');
        final needsUpdate = (existing.thumbnailUrl == null && candidate.thumbnailUrl != null) ||
            (existing.resolution == null && candidate.resolution != null) ||
            (existing.estimatedSizeBytes == null && candidate.estimatedSizeBytes != null) ||
            titleNeedsUpdate;

        if (needsUpdate) {
          final updatedList = List<SniffedMedia>.from(state.items);
          updatedList[existingIndex] = existing.copyWith(
            thumbnailUrl: existing.thumbnailUrl ?? candidate.thumbnailUrl,
            resolution: existing.resolution ?? candidate.resolution,
            estimatedSizeBytes: existing.estimatedSizeBytes ?? candidate.estimatedSizeBytes,
            title: titleNeedsUpdate ? candidate.title : existing.title,
            fileName: titleNeedsUpdate ? candidate.fileName : existing.fileName,
          );
          state = state.copyWith(items: updatedList);
        }
      }
      return;
    }

    final newMedia = SniffedMedia(
      id: 'media_${state.items.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
      url: candidate.url,
      normalizedUrl: candidate.normalizedUrl,
      fileName: candidate.fileName,
      mimeType: candidate.mimeType,
      sourceHost: candidate.sourceHost,
      title: candidate.title,
      thumbnailUrl: candidate.thumbnailUrl,
      resolution: candidate.resolution,
      estimatedSizeBytes: candidate.estimatedSizeBytes,
      isStream: candidate.isStream,
      isPolicyBlocked: candidate.isPolicyBlocked,
      isVideo: candidate.isVideo,
      isAudio: candidate.isAudio,
      detectedAt: candidate.detectedAt,
    );

    state = state.copyWith(
      items: [newMedia, ...state.items],
    );

    // Asynchronously probe size in background if not known and not streaming
    if (newMedia.estimatedSizeBytes == null && !newMedia.isStream && !newMedia.isPolicyBlocked) {
      _probeSizeAsync(newMedia.url);
    }
  }

  /// Probes the server for content size and updates state reactively.
  Future<void> _probeSizeAsync(String url) async {
    final size = await _service.fetchContentLength(url);
    if (size != null && size > 0) {
      updateMediaSize(url, size);
    }
  }

  /// Updates the resolved byte size for a media item.
  void updateMediaSize(String url, int sizeBytes, {String? resolution}) {
    final normalized = MediaPatterns.normalizeMediaUrl(url);
    final idx = state.items.indexWhere(
      (m) => m.url == url || m.normalizedUrl == normalized,
    );
    if (idx != -1) {
      final updatedList = List<SniffedMedia>.from(state.items);
      updatedList[idx] = updatedList[idx].copyWith(
        estimatedSizeBytes: sizeBytes,
        resolution: resolution ?? updatedList[idx].resolution,
      );
      state = state.copyWith(items: updatedList);
    }
  }

  int _calculateMediaScore(MediaCandidate candidate) {
    int score = 0;
    final uri = Uri.tryParse(candidate.url);
    final itag = uri?.queryParameters['itag'];

    // Prioritize complete standalone playable audio+video formats
    if (itag == '22') {
      score += 2000; // 720p HD combined video+audio
    } else if (itag == '37') {
      score += 2200; // 1080p combined video+audio
    } else if (itag == '18') {
      score += 1500; // 360p SD combined video+audio
    } else if (candidate.isVideo && !candidate.isStream) {
      score += 1000; // Standalone direct video file
    } else if (candidate.isStream) {
      score += 600; // Adaptive stream manifest
    } else if (candidate.isAudio) {
      score += 200; // Audio stream
    }

    // Penalize DASH standalone video-only chunks without audio
    const videoOnlyItags = {'137', '136', '135', '134', '160', '248', '247', '244', '278', '399', '398'};
    if (itag != null && videoOnlyItags.contains(itag)) {
      score -= 400;
    }

    final res = candidate.resolution;
    if (res != null) {
      if (res.contains('4K')) {
        score += 500;
      } else if (res.contains('1080p')) {
        score += 300;
      } else if (res.contains('720p')) {
        score += 200;
      } else if (res.contains('480p')) {
        score += 100;
      }
    }

    if (candidate.estimatedSizeBytes != null && candidate.estimatedSizeBytes! > 0) {
      score += 50;
    }

    return score;
  }

  int _calculateScoreFromMedia(SniffedMedia media) {
    int score = 0;
    final uri = Uri.tryParse(media.url);
    final itag = uri?.queryParameters['itag'];

    if (itag == '22') {
      score += 2000;
    } else if (itag == '37') {
      score += 2200;
    } else if (itag == '18') {
      score += 1500;
    } else if (media.isVideo && !media.isStream) {
      score += 1000;
    } else if (media.isStream) {
      score += 600;
    } else if (media.isAudio) {
      score += 200;
    }

    const videoOnlyItags = {'137', '136', '135', '134', '160', '248', '247', '244', '278', '399', '398'};
    if (itag != null && videoOnlyItags.contains(itag)) {
      score -= 400;
    }

    final res = media.resolution;
    if (res != null) {
      if (res.contains('4K')) {
        score += 500;
      } else if (res.contains('1080p')) {
        score += 300;
      } else if (res.contains('720p')) {
        score += 200;
      } else if (res.contains('480p')) {
        score += 100;
      }
    }

    if (media.estimatedSizeBytes != null && media.estimatedSizeBytes! > 0) {
      score += 50;
    }

    return score;
  }

  /// Clears sniffed media when navigating to a new page.
  void clear() {
    if (state.items.isNotEmpty) {
      state = const MediaSnifferState();
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final mediaSnifferServiceProvider = Provider<MediaSnifferService>((ref) {
  return MediaSnifferService.instance;
});

final mediaSnifferProvider =
    NotifierProvider<MediaSnifferNotifier, MediaSnifferState>(MediaSnifferNotifier.new);
