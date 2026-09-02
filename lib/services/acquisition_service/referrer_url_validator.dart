/// Strict URL validation and sanitization for Acquisition & Deferred Deep Links.
///
/// Defends against:
/// - Arbitrary scheme execution (e.g. javascript:, file:, content:, intent:)
/// - Malformed/oversized payloads (>2048 chars)
/// - Control characters & nested injection attempts
///
/// See SECURITY.md §4.
class ReferrerUrlValidator {
  static const int maxUrlLength = 2048;

  static const Set<String> _allowedSchemes = {
    'http',
    'https',
  };

  static const Set<String> _blockedSchemes = {
    'javascript',
    'file',
    'content',
    'intent',
    'data',
    'blob',
    'about',
    'chrome',
    'vbscript',
  };

  /// Validates whether [rawUrl] is a safe, navigable web URL.
  static bool isValid(String? rawUrl) {
    return sanitizeAndValidate(rawUrl) != null;
  }

  /// Sanitizes and validates [rawUrl]. Returns the clean, normalized URL string
  /// if valid, or `null` if the URL is invalid, dangerous, or malformed.
  static String? sanitizeAndValidate(String? rawUrl) {
    if (rawUrl == null) return null;

    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty || trimmed.length > maxUrlLength) {
      return null;
    }

    // Reject control characters / NULL bytes
    if (trimmed.contains('\x00') || trimmed.contains('\r') || trimmed.contains('\n')) {
      return null;
    }

    // Try parsing URI
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return null;
    }

    final scheme = uri.scheme.toLowerCase();
    if (_blockedSchemes.contains(scheme)) {
      return null;
    }

    // Support custom txbrowser:// deep link scheme with url/target_url parameters
    if (scheme == 'txbrowser') {
      final paramUrl = uri.queryParameters['url'] ??
          uri.queryParameters['target_url'] ??
          uri.queryParameters['destination'];
      if (paramUrl != null && paramUrl.isNotEmpty) {
        return sanitizeAndValidate(paramUrl);
      }
      final rawPath = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
      final fullPath = uri.host.isNotEmpty ? '${uri.host}/$rawPath' : rawPath;
      if (fullPath.startsWith('http://') || fullPath.startsWith('https://')) {
        return sanitizeAndValidate(fullPath);
      }
    }

    if (!_allowedSchemes.contains(scheme)) {
      return null;
    }

    // Host must exist and be valid
    final host = uri.host.trim();
    if (host.isEmpty) {
      return null;
    }

    // Host should not contain invalid characters
    if (host.contains(' ') || host.contains('/') || host.contains('\\')) {
      return null;
    }

    // Valid port range if specified
    if (uri.hasPort && (uri.port <= 0 || uri.port > 65535)) {
      return null;
    }

    return uri.toString();
  }
}
