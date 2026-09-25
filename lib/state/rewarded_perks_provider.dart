import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State model for rewarded video perks (2x Turbo Download Speed and 10-Minute Ad-Free Pass).
class RewardedPerksState {
  const RewardedPerksState({
    this.adFreeUntil,
    this.turboSpeedUntil,
  });

  final DateTime? adFreeUntil;
  final DateTime? turboSpeedUntil;

  bool get isAdFreeActive =>
      adFreeUntil != null && DateTime.now().isBefore(adFreeUntil!);

  bool get isTurboSpeedActive =>
      turboSpeedUntil != null && DateTime.now().isBefore(turboSpeedUntil!);

  Duration get remainingAdFreeTime {
    if (!isAdFreeActive) return Duration.zero;
    return adFreeUntil!.difference(DateTime.now());
  }

  Duration get remainingTurboSpeedTime {
    if (!isTurboSpeedActive) return Duration.zero;
    return turboSpeedUntil!.difference(DateTime.now());
  }

  String formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  RewardedPerksState copyWith({
    DateTime? adFreeUntil,
    DateTime? turboSpeedUntil,
    bool clearAdFree = false,
    bool clearTurboSpeed = false,
  }) {
    return RewardedPerksState(
      adFreeUntil: clearAdFree ? null : (adFreeUntil ?? this.adFreeUntil),
      turboSpeedUntil:
          clearTurboSpeed ? null : (turboSpeedUntil ?? this.turboSpeedUntil),
    );
  }
}

/// Notifier managing active rewarded perks with an automatic 1-second ticker for accurate countdowns.
class RewardedPerksNotifier extends Notifier<RewardedPerksState> {
  Timer? _ticker;

  @override
  RewardedPerksState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const RewardedPerksState();
  }

  /// Activates the 10-Minute Ad-Free Pass.
  void activateAdFreePass({Duration duration = const Duration(minutes: 10)}) {
    final expires = DateTime.now().add(duration);
    state = state.copyWith(adFreeUntil: expires);
    _startTickerIfNeeded();
  }

  /// Activates 2x Turbo Download Speed (defaults to 2 hours).
  void activateTurboSpeed({Duration duration = const Duration(hours: 2)}) {
    final expires = DateTime.now().add(duration);
    state = state.copyWith(turboSpeedUntil: expires);
    _startTickerIfNeeded();
  }

  void _startTickerIfNeeded() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isAdFreeActive && !state.isTurboSpeedActive) {
        _ticker?.cancel();
        _ticker = null;
      }
      state = state.copyWith();
    });
  }
}

final rewardedPerksProvider =
    NotifierProvider<RewardedPerksNotifier, RewardedPerksState>(
  RewardedPerksNotifier.new,
);
