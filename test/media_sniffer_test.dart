import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:tx_browser/services/media_sniffer_service/media_patterns.dart';
import 'package:tx_browser/services/media_sniffer_service/media_sniffer_service.dart';
import 'package:tx_browser/state/media_sniffer_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaPatterns Tests', () {
    test('Identifies video and audio extensions accurately', () {
      expect(MediaPatterns.hasMediaExtension('https://example.com/video.mp4'), isTrue);
      expect(MediaPatterns.hasMediaExtension('https://cdn.test/stream.m3u8'), isTrue);
      expect(MediaPatterns.hasMediaExtension('https://cdn.test/song.mp3'), isTrue);
      expect(MediaPatterns.hasMediaExtension('https://cdn.test/audio.aac'), isTrue);
      expect(MediaPatterns.hasMediaExtension('https://cdn.test/clip.webm'), isTrue);
      expect(MediaPatterns.hasMediaExtension('https://cdn.test/manifest.mpd'), isTrue);
      expect(MediaPatterns.hasMediaExtension('https://example.com/page.html'), isFalse);
      expect(MediaPatterns.hasMediaExtension('https://example.com/script.js'), isFalse);
      expect(MediaPatterns.hasMediaExtension('https://example.com/image.jpg'), isFalse);
    });

    test('Policy blocking limitation is removed so all domains are allowed for download', () {
      expect(MediaPatterns.isPolicyBlocked('googlevideo.com'), isFalse);
      expect(MediaPatterns.isPolicyBlocked('r4---sn-ab5sznzl.googlevideo.com'), isFalse);
      expect(MediaPatterns.isPolicyBlocked('youtube.com'), isFalse);
      expect(MediaPatterns.isPolicyBlocked('www.youtube.com'), isFalse);
      expect(MediaPatterns.isPolicyBlocked('vimeo.com'), isFalse);
      expect(MediaPatterns.isPolicyBlocked('dailymotion.com'), isFalse);
    });

    test('Identifies adaptive streams', () {
      expect(MediaPatterns.isStream('https://cdn.example.com/live/playlist.m3u8'), isTrue);
      expect(MediaPatterns.isStream('https://cdn.example.com/dash/stream.mpd'), isTrue);
      expect(MediaPatterns.isStream('https://cdn.example.com/stream', mimeType: 'application/x-mpegURL'), isTrue);
      expect(MediaPatterns.isStream('https://cdn.example.com/video.mp4'), isFalse);
    });

    test('Infers resolution from URL tokens and dimension inputs', () {
      expect(MediaPatterns.inferResolution(url: 'https://cdn.example.com/video_1080p.mp4'), '1080p FHD');
      expect(MediaPatterns.inferResolution(url: 'https://cdn.example.com/clip_720p.mp4'), '720p HD');
      expect(MediaPatterns.inferResolution(url: 'https://cdn.example.com/4k_nature.webm'), '4K (2160p)');
      expect(MediaPatterns.inferResolution(height: 1080), '1080p FHD');
      expect(MediaPatterns.inferResolution(height: 720), '720p HD');
      expect(MediaPatterns.inferResolution(height: 480), '480p SD');
      expect(MediaPatterns.inferResolution(isAudio: true), 'Audio');
    });

    test('Sanitizes filenames safely for Android filesystem', () {
      final sanitized = MediaPatterns.sanitizeFileName('My Video: Part 1/2? <HD> *special*');
      expect(sanitized.contains(':'), isFalse);
      expect(sanitized.contains('/'), isFalse);
      expect(sanitized.contains('?'), isFalse);
      expect(sanitized.contains('<'), isFalse);
      expect(sanitized.contains('>'), isFalse);
      expect(sanitized.contains('*'), isFalse);
      expect(sanitized.endsWith('.mp4'), isTrue);
    });

    test('Normalizes media URLs to strip range/transient query parameters for deduplication', () {
      const url1 = 'https://cdn.example.com/video.mp4?range=0-1000&bytestart=0&t=123';
      const url2 = 'https://cdn.example.com/video.mp4?range=1001-2000&bytestart=1001&t=456';

      final norm1 = MediaPatterns.normalizeMediaUrl(url1);
      final norm2 = MediaPatterns.normalizeMediaUrl(url2);

      expect(norm1, 'https://cdn.example.com/video.mp4');
      expect(norm2, 'https://cdn.example.com/video.mp4');
      expect(norm1, equals(norm2));
    });
  });

  group('MediaSnifferService Tests', () {
    final service = MediaSnifferService.instance;

    test('isMediaUrl detects direct and CDN media URLs', () {
      expect(service.isMediaUrl('https://example.com/sample.mp4'), isTrue);
      expect(service.isMediaUrl('https://example.com/track.mp3'), isTrue);
      expect(service.isMediaUrl('https://rr1---sn-4g5ednsl.googlevideo.com/videoplayback?id=123'), isTrue);
      expect(service.isMediaUrl('https://example.com/style.css'), isFalse);
      expect(service.isMediaUrl('blob:https://example.com/123-abc'), isFalse);
      expect(service.isMediaUrl('data:video/mp4;base64,...'), isFalse);
    });

    test('evaluateUrl returns candidate with parsed metadata', () {
      final candidate = service.evaluateUrl(
        'https://vimeo.com/video_720p.mp4',
        contentType: 'video/mp4',
        pageTitle: 'Cool Drone Footage',
      );

      expect(candidate, isNotNull);
      expect(candidate!.isVideo, isTrue);
      expect(candidate.isAudio, isFalse);
      expect(candidate.isStream, isFalse);
      expect(candidate.isPolicyBlocked, isFalse);
      expect(candidate.resolution, '720p HD');
      expect(candidate.sourceHost, 'vimeo.com');
      expect(candidate.fileName.endsWith('.mp4'), isTrue);
    });

    test('evaluateUrl marks YouTube streams as downloadable with policy limitation removed', () {
      final candidate = service.evaluateUrl(
        'https://r4---sn-ab5sznzl.googlevideo.com/videoplayback?id=yt_video_1',
        contentType: 'video/mp4',
        pageTitle: 'YouTube Video',
      );

      expect(candidate, isNotNull);
      expect(candidate!.isPolicyBlocked, isFalse);
      expect(candidate.sourceHost.contains('googlevideo.com'), isTrue);
    });

    test('getMediaSnifferUserScript returns UserScript at document start with fetch and XHR hooks', () {
      final script = service.getMediaSnifferUserScript();
      expect(script.injectionTime, UserScriptInjectionTime.AT_DOCUMENT_START);
      expect(script.source.contains('onMediaDetected'), isTrue);
      expect(script.source.contains('window.fetch'), isTrue);
      expect(script.source.contains('XMLHttpRequest'), isTrue);
      expect(script.source.contains('MutationObserver'), isTrue);
    });
  });

  group('MediaSnifferProvider State Tests', () {
    test('Adds media and handles deduplication gracefully', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mediaSnifferProvider.notifier);

      expect(container.read(mediaSnifferProvider).hasMedia, isFalse);

      // Add first video
      notifier.addMediaFromUrl(
        'https://cdn.example.com/video.mp4?range=0-1000',
        contentType: 'video/mp4',
        pageTitle: 'Awesome Clip',
      );

      var state = container.read(mediaSnifferProvider);
      expect(state.hasMedia, isTrue);
      expect(state.items.length, 1);
      expect(state.downloadableCount, 1);
      expect(state.items.first.title, 'Awesome Clip');

      // Add chunk from same video (should deduplicate via normalized URL)
      notifier.addMediaFromUrl(
        'https://cdn.example.com/video.mp4?range=1001-2000',
        contentType: 'video/mp4',
      );

      state = container.read(mediaSnifferProvider);
      expect(state.items.length, 1, reason: 'Duplicate video should be merged rather than appended');

      // Add a distinct audio track
      notifier.addMediaFromUrl(
        'https://cdn.example.com/soundtrack.mp3',
        contentType: 'audio/mp3',
        pageTitle: 'Background Music',
      );

      state = container.read(mediaSnifferProvider);
      expect(state.items.length, 2);
      expect(state.items.any((i) => i.isAudio), isTrue);

      // Clear on navigation
      notifier.clear();
      state = container.read(mediaSnifferProvider);
      expect(state.hasMedia, isFalse);
      expect(state.items.isEmpty, isTrue);
    });

    test('Deduplicates sequence chunks (sq=0, sq=1, sq=2) into single item', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mediaSnifferProvider.notifier);

      notifier.addMediaFromUrl(
        'https://r4---sn-ab5sznzl.googlevideo.com/videoplayback?id=yt_vid_99&itag=18&sq=0&range=0-50000',
        pageTitle: 'Cool Music Video',
      );
      notifier.addMediaFromUrl(
        'https://r4---sn-ab5sznzl.googlevideo.com/videoplayback?id=yt_vid_99&itag=18&sq=1&range=50001-100000',
        pageTitle: 'Cool Music Video',
      );
      notifier.addMediaFromUrl(
        'https://r4---sn-ab5sznzl.googlevideo.com/videoplayback?id=yt_vid_99&itag=18&sq=2&range=100001-150000',
        pageTitle: 'Cool Music Video',
      );

      final state = container.read(mediaSnifferProvider);
      expect(state.items.length, 1, reason: 'Sequence chunks for the same stream must be collapsed into one item');
      expect(state.items.first.title, 'Cool Music Video');
    });

    test('Clusters YouTube itags to present only the best working complete video', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mediaSnifferProvider.notifier);

      // 1. First, an audio-only chunk arrives (itag=140)
      notifier.addMediaFromUrl(
        'https://r4---sn-ab5sznzl.googlevideo.com/videoplayback?id=yt_vid_123&itag=140&sq=0',
        pageTitle: 'Hit Song - Official Video',
      );
      var state = container.read(mediaSnifferProvider);
      expect(state.items.length, 1);

      // 2. Next, a video-only DASH chunk without sound arrives (itag=137, 1080p video only)
      notifier.addMediaFromUrl(
        'https://r4---sn-ab5sznzl.googlevideo.com/videoplayback?id=yt_vid_123&itag=137&sq=0',
        pageTitle: 'Hit Song - Official Video',
      );
      state = container.read(mediaSnifferProvider);
      expect(state.items.length, 1, reason: 'Must not show duplicate entries for the same YouTube video session');

      // 3. Complete standalone working video with both audio and video arrives (itag=22, 720p HD)
      notifier.addMediaFromUrl(
        'https://r4---sn-ab5sznzl.googlevideo.com/videoplayback?id=yt_vid_123&itag=22&sq=0',
        pageTitle: 'Hit Song - Official Video',
      );
      state = container.read(mediaSnifferProvider);
      expect(state.items.length, 1, reason: 'Should upgrade the existing card to the complete working video');
      expect(state.items.first.url.contains('itag=22'), isTrue, reason: 'Must hold the complete 720p HD stream URL');
    });

    test('Formatted size displays correct suffixes', () {
      final mediaSmall = SniffedMedia(
        id: '1',
        url: 'https://example.com/a.mp4',
        normalizedUrl: 'https://example.com/a.mp4',
        fileName: 'a.mp4',
        mimeType: 'video/mp4',
        sourceHost: 'example.com',
        isStream: false,
        isPolicyBlocked: false,
        isVideo: true,
        isAudio: false,
        estimatedSizeBytes: 5242880, // 5 MB
        detectedAt: DateTime.now(),
      );
      expect(mediaSmall.formattedSize, '5.0 MB');

      final mediaStream = mediaSmall.copyWith(isStream: true);
      expect(mediaStream.formattedSize, 'Adaptive Stream');

      final mediaNullSize = mediaSmall.copyWith(clearEstimatedSize: true);
      expect(mediaNullSize.formattedSize, 'Ready to Download');
    });
  });
}
