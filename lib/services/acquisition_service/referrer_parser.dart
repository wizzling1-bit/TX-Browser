import 'referrer_url_validator.dart';

/// Parses raw Google Play Install Referrer strings into structured campaign and target URL payloads.
class ReferrerParser {
  /// Parses a raw [rawReferrer] string.
  ///
  /// Supports standard formats:
  /// - `target_url=https://...&campaign=...`
  /// - `target_url%3Dhttps%3A%2F%2F...%26campaign%3D...`
  /// - `url=https://...`
  /// - Direct valid HTTPS/HTTP URL strings
  static Map<String, String?> parse(String? rawReferrer) {
    if (rawReferrer == null || rawReferrer.trim().isEmpty) {
      return {'targetUrl': null, 'campaign': null};
    }

    final trimmed = rawReferrer.trim();

    // 0. If it contains a referrer parameter (e.g. Play Store URL), extract the inner referrer first
    String toProcess = trimmed;
    if (trimmed.contains('referrer=')) {
      final uri = Uri.tryParse(trimmed);
      final refParam = uri?.queryParameters['referrer'];
      if (refParam != null && refParam.isNotEmpty) {
        toProcess = refParam;
      }
    }

    // 1. Direct valid URL check (only if it does not contain nested target_url / referrer params)
    if (!toProcess.contains('target_url') &&
        !toProcess.contains('targeturl') &&
        !toProcess.contains('targetUrl')) {
      final directValid = ReferrerUrlValidator.sanitizeAndValidate(toProcess);
      if (directValid != null) {
        return {
          'targetUrl': directValid,
          'campaign': null,
        };
      }
    }

    // 2. Decode string if URL-encoded (e.g. target_url%3D...)
    var decoded = toProcess;
    try {
      if (toProcess.contains('%3D') || toProcess.contains('%3d') || toProcess.contains('%26')) {
        decoded = Uri.decodeComponent(toProcess);
      }
    } catch (_) {}

    // Check if after decoding it became a direct URL
    if (!decoded.contains('target_url') &&
        !decoded.contains('targeturl') &&
        !decoded.contains('targetUrl')) {
      final decodedDirect = ReferrerUrlValidator.sanitizeAndValidate(decoded);
      if (decodedDirect != null) {
        return {
          'targetUrl': decodedDirect,
          'campaign': null,
        };
      }
    }

    // 3. Parse query parameters
    final params = _extractQueryParameters(decoded);

    // Extract target URL from known keys
    String? rawTarget = params['target_url'] ??
        params['targeturl'] ??
        params['target'] ??
        params['url'] ??
        params['destination'];

    if (rawTarget != null) {
      // Decode inner target if nested
      try {
        if (rawTarget.contains('%3A') || rawTarget.contains('%3a') || rawTarget.contains('%2F') || rawTarget.contains('%2f')) {
          rawTarget = Uri.decodeComponent(rawTarget);
        }
      } catch (_) {}
    }

    final validatedTarget = ReferrerUrlValidator.sanitizeAndValidate(rawTarget);

    // Extract campaign from known keys
    final campaign = params['campaign'] ??
        params['utm_campaign'] ??
        params['source'] ??
        params['utm_source'];

    return {
      'targetUrl': validatedTarget,
      'campaign': campaign?.isNotEmpty == true ? campaign : null,
    };
  }

  static Map<String, String> _extractQueryParameters(String input) {
    final result = <String, String>{};
    // Strip leading ? or & if present
    var clean = input;
    if (clean.startsWith('?')) clean = clean.substring(1);
    if (clean.startsWith('&')) clean = clean.substring(1);

    final pairs = clean.split('&');
    for (final pair in pairs) {
      if (pair.isEmpty) continue;
      final eqIndex = pair.indexOf('=');
      if (eqIndex != -1) {
        final key = pair.substring(0, eqIndex).trim().toLowerCase();
        final value = pair.substring(eqIndex + 1).trim();
        if (key.isNotEmpty) {
          try {
            result[key] = Uri.decodeComponent(value);
          } catch (_) {
            result[key] = value;
          }
        }
      } else {
        final key = pair.trim().toLowerCase();
        if (key.isNotEmpty) {
          result[key] = '';
        }
      }
    }
    return result;
  }
}
