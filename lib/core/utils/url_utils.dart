/// URL validation and formatting utilities.
library;

class UrlUtils {
  UrlUtils._();

  /// Common URL schemes that indicate a navigable URL.
  static const _validSchemes = ['http', 'https', 'ftp', 'file'];

  /// Schemes that should be opened externally (not in WebView).
  static const externalSchemes = ['tel', 'mailto', 'sms', 'geo'];

  /// Intent scheme for Android deep links.
  static const intentScheme = 'intent';

  /// Regex for a valid domain pattern (e.g., "example.com", "sub.example.co.uk").
  static final _domainRegex = RegExp(
    r'^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+$',
  );

  /// Regex for IPv4 addresses.
  static final _ipv4Regex = RegExp(
    r'^(\d{1,3}\.){3}\d{1,3}(:\d+)?$',
  );

  /// Returns `true` if [input] looks like a URL rather than a search query.
  static bool isUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;

    // Has an explicit scheme?
    final uri = Uri.tryParse(trimmed);
    if (uri != null && _validSchemes.contains(uri.scheme.toLowerCase())) {
      return true;
    }

    // Looks like a bare domain (e.g. "google.com")?
    final hostPart = trimmed.split('/').first.split('?').first;
    if (_domainRegex.hasMatch(hostPart) || _ipv4Regex.hasMatch(hostPart)) {
      return true;
    }

    // Contains "localhost"?
    if (trimmed.startsWith('localhost')) return true;

    return false;
  }

  /// Normalizes user input into a proper URL.
  ///
  /// If the input is already a valid URL, returns it. If it's a bare domain,
  /// prepends "https://". Otherwise returns `null` (treat as search query).
  static String? normalizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Already has a valid scheme.
    final uri = Uri.tryParse(trimmed);
    if (uri != null && _validSchemes.contains(uri.scheme.toLowerCase())) {
      return trimmed;
    }

    // Bare domain or IP → prepend https.
    if (isUrl(trimmed)) {
      return 'https://$trimmed';
    }

    return null;
  }

  /// Extracts the display domain from a URL (e.g., "www.example.com" → "example.com").
  static String extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      var host = uri.host;
      if (host.startsWith('www.')) {
        host = host.substring(4);
      }
      return host;
    } catch (_) {
      return url;
    }
  }

  /// Returns `true` if the URL uses HTTPS.
  static bool isSecure(String url) {
    try {
      return Uri.parse(url).scheme == 'https';
    } catch (_) {
      return false;
    }
  }

  /// Checks if [scheme] should be handled externally.
  static bool isExternalScheme(String scheme) {
    return externalSchemes.contains(scheme.toLowerCase()) ||
        scheme.toLowerCase() == intentScheme;
  }
}
