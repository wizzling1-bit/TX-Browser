import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'media_patterns.dart';

/// Candidate media item evaluated by the sniffer engine before state insertion.
class MediaCandidate {
  const MediaCandidate({
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
}

/// Production-ready media sniffer engine for Tx Browser.
///
/// Features:
/// 1. Dual-layer sniffing: Network request interception (Dart) + DOM/Property mutation sniffing (JavaScript).
/// 2. Asynchronous size estimation via parallel `HEAD` / `Range` probes with 3-second timeout and LRU caching.
/// 3. Strict compliance: Flags YouTube/DRM as policy-restricted without breaking user browsing.
/// 4. Intelligent deduplication and file naming.
class MediaSnifferService {
  MediaSnifferService._();

  static final MediaSnifferService instance = MediaSnifferService._();

  final Map<String, int?> _sizeCache = <String, int?>{};
  final Map<String, String?> _mimeCache = <String, String?>{};

  /// Returns true if [url] is a plausible media resource based on O(1) extension/host checks.
  bool isMediaUrl(String url) {
    if (url.isEmpty || url.startsWith('blob:') || url.startsWith('data:')) {
      return false;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;

    // 1. Check path extension
    if (MediaPatterns.hasMediaExtension(uri.path)) {
      return true;
    }

    // 2. Check path for embedded media extensions (e.g. /hls/stream.m3u8/segment.ts or .mp4)
    final lowerPath = uri.path.toLowerCase();
    for (final ext in MediaPatterns.allMediaExtensions) {
      if (lowerPath.endsWith('.$ext') || lowerPath.contains('.$ext/') || lowerPath.contains('.$ext?')) {
        return true;
      }
    }

    // 3. Check query parameter hints (e.g., ?mime=video/mp4 or ?format=mp4)
    final mimeParam = uri.queryParameters['mime'] ?? uri.queryParameters['format'];
    if (mimeParam != null && (mimeParam.contains('video') || mimeParam.contains('audio') || mimeParam.contains('mp4'))) {
      return true;
    }

    // 4. Known media CDNs with direct streams (e.g. googlevideo.com / videoplayback)
    final host = uri.host.toLowerCase();
    if (host == 'googlevideo.com' || host.endsWith('.googlevideo.com')) {
      return uri.path.contains('videoplayback');
    }

    if (MediaPatterns.knownMediaCdns.any((cdn) => host == cdn || host.endsWith('.$cdn'))) {
      if (uri.path.contains('video') || uri.path.contains('stream') || uri.path.contains('media')) {
        return true;
      }
    }

    return false;
  }

  /// Evaluates an incoming URL (from network interceptor or JavaScript DOM hook).
  MediaCandidate? evaluateUrl(
    String url, {
    String? contentType,
    String? pageTitle,
    String? posterUrl,
    int? videoWidth,
    int? videoHeight,
  }) {
    if (url.isEmpty) return null;

    final trimmed = url.trim();
    if (trimmed.startsWith('blob:') || trimmed.startsWith('data:') || trimmed.startsWith('javascript:')) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    final host = uri.host.toLowerCase();
    final ext = MediaPatterns.extractExtension(uri.path);

    // Verify if it is media by extension, content type, known endpoint, or query parameter hints
    final hasMediaExt = ext != null && MediaPatterns.allMediaExtensions.contains(ext);
    final isMediaMime = contentType != null && MediaPatterns.isMediaMimeType(contentType);
    final isVideoPlayback = (host == 'googlevideo.com' || host.endsWith('.googlevideo.com')) &&
        uri.path.contains('videoplayback');
    final mimeParam = uri.queryParameters['mime'] ?? uri.queryParameters['format'];
    final hasMimeInQuery = mimeParam != null && (mimeParam.contains('video') || mimeParam.contains('audio'));

    if (!hasMediaExt && !isMediaMime && !isVideoPlayback && !hasMimeInQuery) {
      return null;
    }

    final isPolicyBlocked = MediaPatterns.isPolicyBlocked(host);
    final isStream = MediaPatterns.isStream(trimmed, mimeType: contentType ?? mimeParam);
    final isAudio = (ext != null && MediaPatterns.audioExtensions.contains(ext)) ||
        (contentType != null && contentType.toLowerCase().startsWith('audio/')) ||
        (mimeParam != null && mimeParam.contains('audio'));
    final isVideo = !isAudio;

    // Derive MIME type
    final resolvedMime = contentType ??
        mimeParam ??
        _mimeCache[trimmed] ??
        _inferMimeType(ext, isVideo: isVideo, isStream: isStream);

    // Determine resolution
    final resolution = isStream
        ? 'HLS Stream'
        : MediaPatterns.inferResolution(
            url: trimmed,
            width: videoWidth,
            height: videoHeight,
            isAudio: isAudio,
          );

    // Derive file name
    final defaultExt = isStream ? 'm3u8' : (isAudio ? 'mp3' : (ext ?? 'mp4'));
    String baseName;
    if (pageTitle != null && pageTitle.trim().isNotEmpty && pageTitle != 'New Tab' && !pageTitle.startsWith('http')) {
      baseName = pageTitle.trim();
    } else if (uri.pathSegments.isNotEmpty) {
      baseName = p.basenameWithoutExtension(uri.pathSegments.last);
      if (baseName.isEmpty || baseName == 'videoplayback') {
        baseName = 'video_${uri.host}';
      }
    } else {
      baseName = 'media_${DateTime.now().millisecondsSinceEpoch}';
    }

    final sanitizedFileName = MediaPatterns.sanitizeFileName(baseName, defaultExt: defaultExt);
    final normalizedUrl = MediaPatterns.normalizeMediaUrl(trimmed);

    // Immediate size resolution from cache or URL parameters (e.g. clen / size)
    int? estimatedSize = _sizeCache[normalizedUrl] ?? _sizeCache[trimmed];
    if (estimatedSize == null && uri.queryParameters.containsKey('clen')) {
      estimatedSize = int.tryParse(uri.queryParameters['clen']!);
      if (estimatedSize != null && estimatedSize > 0) {
        _sizeCache[normalizedUrl] = estimatedSize;
      }
    } else if (estimatedSize == null && uri.queryParameters.containsKey('size')) {
      estimatedSize = int.tryParse(uri.queryParameters['size']!);
      if (estimatedSize != null && estimatedSize > 0) {
        _sizeCache[normalizedUrl] = estimatedSize;
      }
    }

    return MediaCandidate(
      url: normalizedUrl,
      normalizedUrl: normalizedUrl,
      fileName: sanitizedFileName,
      mimeType: resolvedMime,
      sourceHost: host,
      title: (pageTitle != null && pageTitle.isNotEmpty && !pageTitle.startsWith('http'))
          ? pageTitle
          : sanitizedFileName,
      thumbnailUrl: (posterUrl != null && posterUrl.isNotEmpty) ? posterUrl : null,
      resolution: resolution,
      estimatedSizeBytes: estimatedSize,
      isStream: isStream,
      isPolicyBlocked: isPolicyBlocked,
      isVideo: isVideo,
      isAudio: isAudio,
      detectedAt: DateTime.now(),
    );
  }

  /// Probes the media server asynchronously for `Content-Length` and `Content-Type`.
  ///
  /// Uses a strict 3-second timeout and falls back to a 1-byte Range probe if `HEAD`
  /// is rejected by the CDN with HTTP 405 / 403.
  Future<int?> fetchContentLength(
    String url, {
    Map<String, String>? headers,
  }) async {
    final normalized = MediaPatterns.normalizeMediaUrl(url);
    if (_sizeCache.containsKey(normalized)) {
      return _sizeCache[normalized];
    }

    try {
      final uri = Uri.parse(url);
      final reqHeaders = <String, String>{
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
        'Accept': '*/*',
        ...?headers,
      };

      // 1. Try HEAD request
      final headResponse = await http
          .head(uri, headers: reqHeaders)
          .timeout(const Duration(seconds: 3));

      if (headResponse.statusCode >= 200 && headResponse.statusCode < 300) {
        final lengthHeader = headResponse.headers['content-length'];
        if (lengthHeader != null) {
          final bytes = int.tryParse(lengthHeader.trim());
          if (bytes != null && bytes > 0) {
            _sizeCache[normalized] = bytes;
            final type = headResponse.headers['content-type'];
            if (type != null) _mimeCache[normalized] = type;
            return bytes;
          }
        }
      }

      // 2. If HEAD returned 405 Method Not Allowed or 0 bytes, try 1-byte Range probe
      if (headResponse.statusCode == 405 || headResponse.statusCode == 403 || headResponse.contentLength == 0) {
        final rangeHeaders = Map<String, String>.from(reqHeaders);
        rangeHeaders['Range'] = 'bytes=0-0';

        final client = http.Client();
        try {
          final req = http.Request('GET', uri);
          req.headers.addAll(rangeHeaders);
          final streamed = await client.send(req).timeout(const Duration(seconds: 3));

          // Look for Content-Range: bytes 0-0/12345678
          final contentRange = streamed.headers['content-range'];
          if (contentRange != null && contentRange.contains('/')) {
            final totalStr = contentRange.split('/').last.trim();
            final bytes = int.tryParse(totalStr);
            if (bytes != null && bytes > 0) {
              _sizeCache[normalized] = bytes;
              return bytes;
            }
          }
        } finally {
          client.close();
        }
      }
    } catch (_) {
      // Timeout or network probe failure — fail open with null size
    }

    _sizeCache[normalized] = null;
    return null;
  }

  /// Builds the injected UserScript that performs client-side DOM and network sniffing.
  UserScript getMediaSnifferUserScript() {
    const scriptSource = '''
(function() {
  if (window.__tx_media_sniffer_installed__) return;
  window.__tx_media_sniffer_installed__ = true;

  const reportedUrls = new Set();
  const MEDIA_REGEX = /\\.(mp4|webm|mkv|flv|mov|avi|wmv|3gp|m4v|ogv|m3u8|mpd|ts|mp3|m4a|aac|wav|ogg|flac)(\\?|#|\$)/i;
  const STATIC_ASSET_REGEX = /\\.(js|css|png|jpg|jpeg|gif|svg|webp|ico|woff|woff2|ttf|eot)(\\?|#|\$)/i;

  function isProbableMediaUrl(url) {
    if (!url || typeof url !== 'string') return false;
    const clean = url.trim();
    if (clean.startsWith('blob:') || clean.startsWith('data:') || clean.startsWith('javascript:')) return false;
    if (STATIC_ASSET_REGEX.test(clean)) return false;
    if (MEDIA_REGEX.test(clean)) return true;
    if (clean.includes('videoplayback') || clean.includes('mime=video') || clean.includes('mime=audio') || clean.includes('format=mp4')) return true;
    return false;
  }

  function normalizeMediaUrl(url) {
    try {
      const u = new URL(url);
      ['range', 'bytestart', 'byteend', 'rn', '_nc_rid', 't', 'sq', 'chunk', 'part', 'segment', 'seg', 'frag'].forEach(p => u.searchParams.delete(p));
      return u.toString();
    } catch(e) {
      return url;
    }
  }

  function reportMedia(url, meta) {
    if (!url || typeof url !== 'string') return;
    const cleanUrl = url.trim();
    if (cleanUrl.startsWith('blob:') || cleanUrl.startsWith('data:') || cleanUrl.startsWith('javascript:')) return;
    const normalized = normalizeMediaUrl(cleanUrl);
    if (reportedUrls.has(normalized)) return;
    reportedUrls.add(normalized);

    try {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('onMediaDetected', {
          url: normalized,
          mimeType: (meta && meta.mimeType) || '',
          title: (meta && meta.title) || document.title || '',
          poster: (meta && meta.poster) || '',
          videoWidth: (meta && meta.videoWidth) || 0,
          videoHeight: (meta && meta.videoHeight) || 0
        });
      }
    } catch (e) {}
  }

  function getOgImage() {
    try {
      const og = document.querySelector('meta[property="og:image"]');
      return og ? og.getAttribute('content') : '';
    } catch (e) {
      return '';
    }
  }

  function scanElement(el) {
    if (!el) return;
    const tagName = el.tagName ? el.tagName.toUpperCase() : '';
    const ogImage = getOgImage();

    if (tagName === 'VIDEO' || tagName === 'AUDIO') {
      const src = el.currentSrc || el.src || el.getAttribute('src');
      if (src) {
        reportMedia(src, {
          mimeType: tagName === 'VIDEO' ? 'video/mp4' : 'audio/mp3',
          poster: el.poster || ogImage,
          videoWidth: el.videoWidth || 0,
          videoHeight: el.videoHeight || 0,
          title: document.title
        });
      }

      // Check inner <source> children
      try {
        const sources = el.querySelectorAll('source');
        sources.forEach(s => {
          const sUrl = s.src || s.getAttribute('src');
          if (sUrl) {
            reportMedia(sUrl, {
              mimeType: s.type || (tagName === 'VIDEO' ? 'video/mp4' : 'audio/mp3'),
              poster: el.poster || ogImage,
              videoWidth: el.videoWidth || 0,
              videoHeight: el.videoHeight || 0,
              title: document.title
            });
          }
        });
      } catch (e) {}
    } else if (tagName === 'SOURCE') {
      const parent = el.parentElement;
      const isVideo = parent && parent.tagName === 'VIDEO';
      const sUrl = el.src || el.getAttribute('src');
      if (sUrl) {
        reportMedia(sUrl, {
          mimeType: el.type || (isVideo ? 'video/mp4' : 'audio/mp3'),
          poster: (parent && parent.poster) || ogImage,
          videoWidth: (parent && parent.videoWidth) || 0,
          videoHeight: (parent && parent.videoHeight) || 0,
          title: document.title
        });
      }
    }
  }

  function scanAllMedia() {
    try {
      document.querySelectorAll('video, audio, source').forEach(scanElement);
    } catch (e) {}
  }

  // 1. Hook window.fetch for dynamic streaming / HLS / DASH / CDN chunk fetches
  try {
    if (window.fetch) {
      const originalFetch = window.fetch;
      window.fetch = function(input, init) {
        try {
          const u = typeof input === 'string' ? input : (input && input.url ? input.url : '');
          if (u && isProbableMediaUrl(u)) {
            reportMedia(u, {
              title: document.title,
              poster: getOgImage()
            });
          }
        } catch (e) {}
        return originalFetch.apply(this, arguments);
      };
    }
  } catch (e) {}

  // 2. Hook XMLHttpRequest for AJAX media segment and manifest loaders
  try {
    if (window.XMLHttpRequest && window.XMLHttpRequest.prototype) {
      const originalXhrOpen = window.XMLHttpRequest.prototype.open;
      window.XMLHttpRequest.prototype.open = function(method, url) {
        try {
          if (url && typeof url === 'string' && isProbableMediaUrl(url)) {
            reportMedia(url, {
              title: document.title,
              poster: getOgImage()
            });
          }
        } catch (e) {}
        return originalXhrOpen.apply(this, arguments);
      };
    }
  } catch (e) {}

  // 3. Hook HTMLMediaElement.prototype.play and load for instant detection on play
  try {
    if (window.HTMLMediaElement && window.HTMLMediaElement.prototype) {
      const origPlay = window.HTMLMediaElement.prototype.play;
      window.HTMLMediaElement.prototype.play = function() {
        try {
          scanElement(this);
        } catch (e) {}
        return origPlay.apply(this, arguments);
      };

      const originalSrcDesc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'src');
      if (originalSrcDesc && originalSrcDesc.set) {
        Object.defineProperty(HTMLMediaElement.prototype, 'src', {
          set: function(val) {
            try {
              scanElement(this);
              if (val) {
                reportMedia(val, {
                  mimeType: this.tagName === 'VIDEO' ? 'video/mp4' : 'audio/mp3',
                  poster: this.poster || getOgImage(),
                  videoWidth: this.videoWidth || 0,
                  videoHeight: this.videoHeight || 0,
                  title: document.title
                });
              }
            } catch (_) {}
            return originalSrcDesc.set.call(this, val);
          },
          get: originalSrcDesc.get,
          configurable: true
        });
      }
    }
  } catch (e) {}

  // 4. Initial scan & MutationObserver to track dynamically added players
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', scanAllMedia);
  } else {
    scanAllMedia();
  }

  try {
    const observer = new MutationObserver(mutations => {
      for (const m of mutations) {
        if (m.type === 'childList') {
          m.addedNodes.forEach(node => {
            if (node.nodeType === 1) { // ELEMENT_NODE
              scanElement(node);
              node.querySelectorAll && node.querySelectorAll('video, audio, source').forEach(scanElement);
            }
          });
        } else if (m.type === 'attributes') {
          if (m.attributeName === 'src' || m.attributeName === 'currentSrc') {
            scanElement(m.target);
          }
        }
      }
    });

    observer.observe(document.documentElement, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['src', 'currentSrc']
    });
  } catch (e) {}

  // 5. Capture playback and metadata lifecycle events on capture phase
  ['play', 'playing', 'loadedmetadata', 'loadeddata', 'canplay'].forEach(evt => {
    document.addEventListener(evt, e => scanElement(e.target), true);
  });
})();
''';

    return UserScript(
      source: scriptSource,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      forMainFrameOnly: false,
    );
  }

  String _inferMimeType(String? ext, {required bool isVideo, required bool isStream}) {
    if (isStream) {
      if (ext == 'mpd') return 'application/dash+xml';
      return 'application/x-mpegurl';
    }

    switch (ext) {
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'webm':
        return isVideo ? 'video/webm' : 'audio/webm';
      case 'mkv':
        return 'video/x-matroska';
      case 'flv':
        return 'video/x-flv';
      case 'mov':
        return 'video/quicktime';
      case '3gp':
        return 'video/3gpp';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
      case 'aac':
        return 'audio/aac';
      case 'ogg':
      case 'opus':
        return 'audio/ogg';
      case 'wav':
        return 'audio/wav';
      case 'flac':
        return 'audio/flac';
      default:
        return isVideo ? 'video/mp4' : 'audio/mpeg';
    }
  }
}
