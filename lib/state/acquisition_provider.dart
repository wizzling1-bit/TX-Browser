import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/acquisition_service/acquisition_service.dart';
import '../services/acquisition_service/deferred_navigation_model.dart';

/// Provider for the AcquisitionService singleton.
final acquisitionServiceProvider = Provider<AcquisitionService>((ref) {
  final service = AcquisitionService();
  ref.onDispose(service.dispose);
  return service;
});

/// Holds the deferred navigation payload detected on first launch (if any).
final deferredNavigationPayloadProvider =
    NotifierProvider<DeferredNavigationNotifier, DeferredNavigationPayload?>(
  DeferredNavigationNotifier.new,
);

class DeferredNavigationNotifier extends Notifier<DeferredNavigationPayload?> {
  @override
  DeferredNavigationPayload? build() => null;

  void setPayload(DeferredNavigationPayload? payload) {
    state = payload;
  }

  void markProcessed() {
    if (state != null) {
      state = state!.copyWith(processed: true);
    }
  }

  void clear() {
    state = null;
  }
}
