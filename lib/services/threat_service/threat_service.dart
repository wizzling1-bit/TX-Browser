import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Threat intelligence classification category.
enum ThreatCategory {
  phishing,
  scam,
  malware,
  cryptoDrainer,
  suspicious;

  static ThreatCategory fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'SCAM':
        return ThreatCategory.scam;
      case 'MALWARE':
        return ThreatCategory.malware;
      case 'CRYPTO_DRAINER':
        return ThreatCategory.cryptoDrainer;
      case 'SUSPICIOUS':
        return ThreatCategory.suspicious;
      case 'PHISHING':
      default:
        return ThreatCategory.phishing;
    }
  }

  String get displayName {
    switch (this) {
      case ThreatCategory.phishing:
        return 'Phishing Threat';
      case ThreatCategory.scam:
        return 'Financial Scam';
      case ThreatCategory.malware:
        return 'Malware Dropper';
      case ThreatCategory.cryptoDrainer:
        return 'Crypto Wallet Drainer';
      case ThreatCategory.suspicious:
        return 'Deceptive Website';
    }
  }
}

/// Security threat record cached locally for high-speed offline interception.
class ThreatRecord {
  const ThreatRecord({
    required this.domain,
    required this.category,
    required this.severity,
    required this.reason,
  });

  final String domain;
  final ThreatCategory category;
  final String severity;
  final String reason;

  factory ThreatRecord.fromJson(Map<String, dynamic> json) {
    return ThreatRecord(
      domain: (json['domain'] as String).toLowerCase().trim(),
      category: ThreatCategory.fromString(json['category'] as String?),
      severity: (json['severity'] as String?) ?? 'HIGH',
      reason: (json['reason'] as String?) ?? 'Identified as a high-risk security threat.',
    );
  }
}

/// Outcome of URL inspection against threat intelligence database.
class ThreatCheckResult {
  const ThreatCheckResult({
    required this.isThreat,
    this.threat,
  });

  final bool isThreat;
  final ThreatRecord? threat;

  static const safe = ThreatCheckResult(isThreat: false);
}

/// Service managing cloud sync and instant zero-latency threat interception.
class ThreatService {
  ThreatService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final Map<String, ThreatRecord> _cachedThreats = {};
  final Set<String> _bypassedDomains = {};
  bool _initialized = false;

  // Embedded baseline threat intelligence database for 100% offline protection
  static const List<Map<String, dynamic>> defaultThreats = [
    {
      'domain': 'metamask-restore-wallet.xyz',
      'category': 'CRYPTO_DRAINER',
      'severity': 'CRITICAL',
      'reason': 'Malicious crypto seed-phrase drainer targeting mobile browser wallets.',
    },
    {
      'domain': 'bank-account-security-update.com',
      'category': 'PHISHING',
      'severity': 'HIGH',
      'reason': 'Credential harvesting form imitating commercial banking login portal.',
    },
    {
      'domain': 'claim-iphone16-reward.top',
      'category': 'SCAM',
      'severity': 'HIGH',
      'reason': 'Deceptive sweepstakes lottery fee advance scam.',
    },
    {
      'domain': 'install-flash-player-update.info',
      'category': 'MALWARE',
      'severity': 'CRITICAL',
      'reason': 'Trojanned APK dropper masquerading as media plugin update.',
    },
    {
      'domain': 'binance-verify-auth.net',
      'category': 'PHISHING',
      'severity': 'CRITICAL',
      'reason': 'Exchange 2FA and OTP interception spoof site.',
    },
  ];

  /// Initializes local threat database and asynchronously synchronizes with cloud backend.
  Future<void> initialize({String? backendBaseUrl}) async {
    if (_initialized) return;

    // Load defaults immediately
    for (final item in defaultThreats) {
      final record = ThreatRecord.fromJson(item);
      _cachedThreats[record.domain] = record;
    }
    _initialized = true;

    // Sync from cloud backend asynchronously
    syncFromBackend(backendBaseUrl: backendBaseUrl);
  }

  /// Synchronizes threat intelligence updates from cloud backend and Supabase Cloud.
  Future<void> syncFromBackend({String? backendBaseUrl}) async {
    final baseUrl = backendBaseUrl ?? 'https://txbrowser.com';
    try {
      final uri = Uri.parse('$baseUrl/api/v1/security/threats');
      final response = await _httpClient.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['threats'] is List) {
          final list = data['threats'] as List;
          for (final item in list) {
            final record = ThreatRecord.fromJson(item as Map<String, dynamic>);
            _cachedThreats[record.domain] = record;
          }
          debugPrint('[ThreatService] Successfully synced ${_cachedThreats.length} threat domains.');
          return;
        }
      }
    } catch (_) {}

    // Direct Supabase Cloud Serverless Fallback
    try {
      const anonKey =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpZHJicmt5dmNhamFiZHl5Y21xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMjAzNjEsImV4cCI6MjEwNTg5NjM2MX0.0VyAmmu65b5aiduXDbG4eDAAYYXJGky5S5ooHJ9A0sQ';
      final supabaseUri = Uri.parse(
          'https://vidrbrkyvcajabdyycmq.supabase.co/rest/v1/security_threats?is_active=eq.true');
      final response = await _httpClient.get(supabaseUri, headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        for (final item in list) {
          final record = ThreatRecord.fromJson(item as Map<String, dynamic>);
          _cachedThreats[record.domain] = record;
        }
        debugPrint('[ThreatService] Successfully synced ${_cachedThreats.length} threat domains directly from Supabase Cloud.');
      }
    } catch (e) {
      debugPrint('[ThreatService] Cloud threat sync note (safe fallback active): $e');
    }
  }

  /// Evaluates whether the given URL or host is a classified security threat.
  ThreatCheckResult checkUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return ThreatCheckResult.safe;

    final uri = Uri.tryParse(rawUrl);
    String host = (uri?.host ?? rawUrl).toLowerCase().trim();
    if (host.startsWith('www.')) {
      host = host.substring(4);
    }

    if (host.isEmpty) return ThreatCheckResult.safe;

    // Check if user already chose to bypass warning during this session
    if (_bypassedDomains.contains(host)) {
      return ThreatCheckResult.safe;
    }

    // Direct match
    if (_cachedThreats.containsKey(host)) {
      return ThreatCheckResult(isThreat: true, threat: _cachedThreats[host]);
    }

    // Subdomain wildcard match (e.g. login.phish-bank.com -> phish-bank.com)
    for (final entry in _cachedThreats.entries) {
      if (host.endsWith('.${entry.key}')) {
        return ThreatCheckResult(isThreat: true, threat: entry.value);
      }
    }

    return ThreatCheckResult.safe;
  }

  /// Allows user to proceed past the security warning for this domain during this session.
  void bypassDomainWarning(String urlOrHost) {
    final uri = Uri.tryParse(urlOrHost);
    var host = (uri?.host ?? urlOrHost).toLowerCase().trim();
    if (host.startsWith('www.')) host = host.substring(4);
    if (host.isNotEmpty) {
      _bypassedDomains.add(host);
    }
  }

  /// Clears session bypasses.
  void clearBypasses() {
    _bypassedDomains.clear();
  }
}

final threatServiceProvider = Provider<ThreatService>((ref) {
  final service = ThreatService();
  service.initialize();
  return service;
});
