import 'package:path/path.dart' as p;

/// Pattern matching, extension catalogs, and URL heuristics for media detection.
class MediaPatterns {
  MediaPatterns._();

  /// Known video file extensions (lowercase).
  static const Set<String> videoExtensions = {
    'mp4',
    'webm',
    'mkv',
    'flv',
    'mov',
    'avi',
    'wmv',
    '3gp',
    'm4v',
    'ogv',
  };

  /// Known audio file extensions (lowercase).
  static const Set<String> audioExtensions = {
    'mp3',
    'm4a',
    'aac',
    'ogg',
    'wav',
    'flac',
    'opus',
    'wma',
    'weba',
  };

  /// Adaptive streaming playlist / manifest extensions.
  static const Set<String> streamExtensions = {
    'm3u8',
    'mpd',
    'ts',
  };

  /// All recognized media extensions.
  static final Set<String> allMediaExtensions = {
    ...videoExtensions,
    ...audioExtensions,
    ...streamExtensions,
  };

  /// Domains protected by platform developer policies.
  /// Direct download limitation has been removed to support downloading all videos.
  static const Set<String> policyBlockedHosts = {};

  /// Known media-hosting / streaming CDNs.
  static const Set<String> knownMediaCdns = {
    'vimeocdn.com',
    'dailymotion.com',
    'dmcdn.net',
    'fbcdn.net',
    'cdninstagram.com',
    'twimg.com',
    'tiktokcdn.com',
    'byteoversea.com',
    'ibytedtos.com',
    'v.redd.it',
    'bilibili.com',
    'akamaihd.net',
    'cloudflarestream.com',
  };

  /// Determines if [host] is subject to platform download policies.
  /// Always returns false so all video downloads are supported across all domains.
  static bool isPolicyBlocked(String host) {
    return false;
  }

  /// Determines if [pathOrUrl] ends with a recognized media extension.
  static bool hasMediaExtension(String pathOrUrl) {
    final ext = extractExtension(pathOrUrl);
    return ext != null && allMediaExtensions.contains(ext);
  }

  /// Extracts the lowercase extension without the leading dot.
  static String? extractExtension(String pathOrUrl) {
    try {
      final uri = Uri.tryParse(pathOrUrl);
      final rawPath = uri != null ? uri.path : pathOrUrl;
      final ext = p.extension(rawPath).toLowerCase().replaceAll('.', '').trim();
      if (ext.isNotEmpty && ext.length <= 5) {
        return ext;
      }
    } catch (_) {}
    return null;
  }

  /// Checks if [mimeType] represents playable media.
  static bool isMediaMimeType(String mimeType) {
    final lower = mimeType.toLowerCase().trim();
    return lower.startsWith('video/') ||
        lower.startsWith('audio/') ||
        lower == 'application/x-mpegurl' ||
        lower == 'application/vnd.apple.mpegurl' ||
        lower == 'application/dash+xml';
  }

  /// Detects whether [url] or [mimeType] points to an adaptive stream (HLS / DASH).
  static bool isStream(String url, {String? mimeType}) {
    if (mimeType != null) {
      final lowerMime = mimeType.toLowerCase();
      if (lowerMime.contains('mpegurl') || lowerMime.contains('dash+xml')) {
        return true;
      }
    }
    final ext = extractExtension(url);
    if (ext != null && streamExtensions.contains(ext)) {
      return true;
    }
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('.m3u8') || lowerUrl.contains('.mpd');
  }

  /// Inspects URL or dimensions to determine resolution label (e.g. "1080p", "720p", "4K").
  static String? inferResolution({
    String? url,
    int? width,
    int? height,
    bool isAudio = false,
  }) {
    if (isAudio) return 'Audio';

    // 1. From explicit dimensions if provided by DOM
    if (height != null && height > 0) {
      if (height >= 2160) return '4K (2160p)';
      if (height >= 1440) return '2K (1440p)';
      if (height >= 1080) return '1080p FHD';
      if (height >= 720) return '720p HD';
      if (height >= 480) return '480p SD';
      if (height >= 360) return '360p';
      return '${height}p';
    }

    if (width != null && width > 0) {
      if (width >= 3840) return '4K';
      if (width >= 2560) return '2K';
      if (width >= 1920) return '1080p FHD';
      if (width >= 1280) return '720p HD';
      if (width >= 854) return '480p SD';
    }

    // 2. From URL heuristics
    if (url != null) {
      final lower = url.toLowerCase();
      if (lower.contains('2160p') ||
          lower.contains('_4k') ||
          lower.contains('/4k') ||
          lower.contains('4k_') ||
          lower.contains('-4k') ||
          lower.contains('uhd')) {
        return '4K (2160p)';
      }
      if (lower.contains('1440p') || lower.contains('2k')) {
        return '2K (1440p)';
      }
      if (lower.contains('1080p') || lower.contains('_1080') || lower.contains('fhd')) {
        return '1080p FHD';
      }
      if (lower.contains('720p') || lower.contains('_720') || lower.contains('hd')) {
        return '720p HD';
      }
      if (lower.contains('480p') || lower.contains('_480')) {
        return '480p SD';
      }
      if (lower.contains('360p') || lower.contains('_360')) {
        return '360p';
      }
      if (lower.contains('240p') || lower.contains('_240')) {
        return '240p';
      }
    }

    return null;
  }

  /// Sanitizes a file name for safe filesystem storage on Android.
  static String sanitizeFileName(String input, {String defaultExt = 'mp4'}) {
    var name = input.trim();
    // Replace characters invalid in Android / Unix / Windows filenames:
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    // Normalize consecutive underscores/spaces
    name = name.replaceAll(RegExp(r'[\s_]+'), '_');

    if (name.isEmpty || name == '_') {
      name = 'media_${DateTime.now().millisecondsSinceEpoch}';
    }

    // Ensure has extension
    final ext = p.extension(name).replaceAll('.', '').toLowerCase();
    if (ext.isEmpty || !allMediaExtensions.contains(ext)) {
      name = '$name.$defaultExt';
    }

    return name;
  }

  /// Normalizes media URL by stripping transient range / byte tokens for clean deduplication.
  static String normalizeMediaUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasQuery) return url;

      final queryParams = Map<String, String>.from(uri.queryParameters);

      // Strip byte range, chunk sequences, and transient parameters that vary per chunk
      const transientParams = {
        'range', 'bytestart', 'byteend', 'rn', '_nc_rid', 't',
        'sq', 'chunk', 'part', 'segment', 'seg', 'frag', 'fragment',
        'offset', 'time', 'start', 'end', 'splay', 'ump', 'cmo',
        'c', 'cver', 'alr', 'cpn', 'ns', 'lmt'
      };

      for (final param in transientParams) {
        queryParams.remove(param);
      }

      if (queryParams.isEmpty) {
        final result = uri.replace(query: '').toString();
        return result.endsWith('?') ? result.substring(0, result.length - 1) : result;
      } else {
        return uri.replace(queryParameters: queryParams).toString();
      }
    } catch (_) {
      return url;
    }
  }
}
