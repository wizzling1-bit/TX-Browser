/// Model representing an acquisition payload / deferred deep-link.
class DeferredNavigationPayload {
  const DeferredNavigationPayload({
    required this.targetUrl,
    this.campaign,
    required this.receivedAt,
    this.processed = false,
    this.isPinnedToQuickAccess = false,
  });

  final String targetUrl;
  final String? campaign;
  final DateTime receivedAt;
  final bool processed;
  final bool isPinnedToQuickAccess;

  DeferredNavigationPayload copyWith({
    String? targetUrl,
    String? campaign,
    DateTime? receivedAt,
    bool? processed,
    bool? isPinnedToQuickAccess,
  }) {
    return DeferredNavigationPayload(
      targetUrl: targetUrl ?? this.targetUrl,
      campaign: campaign ?? this.campaign,
      receivedAt: receivedAt ?? this.receivedAt,
      processed: processed ?? this.processed,
      isPinnedToQuickAccess:
          isPinnedToQuickAccess ?? this.isPinnedToQuickAccess,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'targetUrl': targetUrl,
      'campaign': campaign,
      'receivedAt': receivedAt.toIso8601String(),
      'processed': processed,
      'isPinnedToQuickAccess': isPinnedToQuickAccess,
    };
  }

  factory DeferredNavigationPayload.fromJson(Map<String, dynamic> json) {
    return DeferredNavigationPayload(
      targetUrl: json['targetUrl'] as String,
      campaign: json['campaign'] as String?,
      receivedAt: DateTime.parse(json['receivedAt'] as String),
      processed: json['processed'] as bool? ?? false,
      isPinnedToQuickAccess: json['isPinnedToQuickAccess'] as bool? ?? false,
    );
  }
}
