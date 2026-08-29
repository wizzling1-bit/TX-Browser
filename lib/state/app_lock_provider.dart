import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../services/security_service/app_lock_service.dart';
import 'database_provider.dart';

// ---------------------------------------------------------------------------
// App Lock Keys in Settings Drift table
// ---------------------------------------------------------------------------

class AppLockKeys {
  AppLockKeys._();
  static const isEnabled = 'app_lock_is_enabled';
  static const pinHash = 'app_lock_pin_hash';
  static const biometricsEnabled = 'app_lock_biometrics_enabled';
  static const timeoutPolicy = 'app_lock_timeout_policy';
}

// ---------------------------------------------------------------------------
// App Lock State Model
// ---------------------------------------------------------------------------

class AppLockState {
  const AppLockState({
    this.isEnabled = false,
    this.pinHash = '',
    this.biometricsEnabled = false,
    this.timeoutPolicy = 'immediately',
    this.isCurrentlyLocked = false,
    this.failedAttempts = 0,
    this.lockoutUntil,
    this.lastBackgroundedAt,
  });

  final bool isEnabled;
  final String pinHash;
  final bool biometricsEnabled;
  final String timeoutPolicy; // 'immediately', '1_min', '5_min', '15_min', 'never'
  final bool isCurrentlyLocked;
  final int failedAttempts;
  final DateTime? lockoutUntil;
  final DateTime? lastBackgroundedAt;

  bool get isLockedOut =>
      lockoutUntil != null && DateTime.now().isBefore(lockoutUntil!);

  int get remainingLockoutSeconds {
    if (lockoutUntil == null) return 0;
    final diff = lockoutUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  AppLockState copyWith({
    bool? isEnabled,
    String? pinHash,
    bool? biometricsEnabled,
    String? timeoutPolicy,
    bool? isCurrentlyLocked,
    int? failedAttempts,
    DateTime? lockoutUntil,
    DateTime? lastBackgroundedAt,
  }) {
    return AppLockState(
      isEnabled: isEnabled ?? this.isEnabled,
      pinHash: pinHash ?? this.pinHash,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      timeoutPolicy: timeoutPolicy ?? this.timeoutPolicy,
      isCurrentlyLocked: isCurrentlyLocked ?? this.isCurrentlyLocked,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockoutUntil: lockoutUntil ?? this.lockoutUntil,
      lastBackgroundedAt: lastBackgroundedAt ?? this.lastBackgroundedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// App Lock Notifier (Riverpod 3)
// ---------------------------------------------------------------------------

class AppLockNotifier extends Notifier<AppLockState> {
  final _service = AppLockService();

  @override
  AppLockState build() {
    return const AppLockState();
  }

  AppDatabase get _db => ref.read(databaseProvider);

  /// Load app lock settings from SQLite on startup.
  Future<void> loadSettings() async {
    final enabledStr = await _db.getSetting(AppLockKeys.isEnabled);
    final hash = await _db.getSetting(AppLockKeys.pinHash);
    final bioStr = await _db.getSetting(AppLockKeys.biometricsEnabled);
    final timeout = await _db.getSetting(AppLockKeys.timeoutPolicy);

    final isEnabled = enabledStr == 'true' && hash != null && hash.isNotEmpty;

    state = AppLockState(
      isEnabled: isEnabled,
      pinHash: hash ?? '',
      biometricsEnabled: bioStr == 'true',
      timeoutPolicy: timeout ?? 'immediately',
      isCurrentlyLocked: isEnabled,
    );
  }

  /// Sets or changes 4-digit PIN.
  Future<void> setPin(String pin) async {
    final hash = _service.hashPin(pin);
    await _db.setSetting(AppLockKeys.isEnabled, 'true');
    await _db.setSetting(AppLockKeys.pinHash, hash);

    state = state.copyWith(
      isEnabled: true,
      pinHash: hash,
      isCurrentlyLocked: false,
      failedAttempts: 0,
    );
  }

  /// Disables App Lock.
  Future<void> disableLock() async {
    await _db.setSetting(AppLockKeys.isEnabled, 'false');
    await _db.setSetting(AppLockKeys.pinHash, '');
    await _db.setSetting(AppLockKeys.biometricsEnabled, 'false');

    state = const AppLockState();
  }

  /// Toggle Biometrics (Fingerprint / Face).
  Future<void> setBiometricsEnabled(bool enabled) async {
    await _db.setSetting(AppLockKeys.biometricsEnabled, enabled.toString());
    state = state.copyWith(biometricsEnabled: enabled);
  }

  /// Set Auto-lock Timeout Policy.
  Future<void> setTimeoutPolicy(String policy) async {
    await _db.setSetting(AppLockKeys.timeoutPolicy, policy);
    state = state.copyWith(timeoutPolicy: policy);
  }

  /// Attempt to unlock with PIN.
  bool unlockWithPin(String pin) {
    if (state.isLockedOut) return false;

    final isCorrect = _service.verifyPin(pin, state.pinHash);
    if (isCorrect) {
      state = state.copyWith(
        isCurrentlyLocked: false,
        failedAttempts: 0,
        lockoutUntil: null,
      );
      return true;
    } else {
      final attempts = state.failedAttempts + 1;
      DateTime? lockout;
      if (attempts >= 5) {
        lockout = DateTime.now().add(const Duration(seconds: 30));
      }
      state = state.copyWith(
        failedAttempts: attempts,
        lockoutUntil: lockout,
      );
      return false;
    }
  }

  /// Attempt biometric unlock.
  Future<bool> unlockWithBiometrics() async {
    if (!state.isEnabled || !state.biometricsEnabled || state.isLockedOut) {
      return false;
    }

    final success = await _service.authenticateBiometrics();
    if (success) {
      state = state.copyWith(
        isCurrentlyLocked: false,
        failedAttempts: 0,
        lockoutUntil: null,
      );
      return true;
    }
    return false;
  }

  /// Explicitly locks app.
  void lockApp() {
    if (state.isEnabled) {
      state = state.copyWith(isCurrentlyLocked: true);
    }
  }

  /// Called when app goes into background.
  void onAppPaused() {
    if (state.isEnabled) {
      state = state.copyWith(lastBackgroundedAt: DateTime.now());
    }
  }

  /// Called when app is resumed. Evaluates timeout policy.
  void onAppResumed() {
    if (!state.isEnabled || state.isCurrentlyLocked) return;

    final bgTime = state.lastBackgroundedAt;
    if (bgTime == null) return;

    final elapsed = DateTime.now().difference(bgTime);

    switch (state.timeoutPolicy) {
      case 'immediately':
        state = state.copyWith(isCurrentlyLocked: true);
        break;
      case '1_min':
        if (elapsed >= const Duration(minutes: 1)) {
          state = state.copyWith(isCurrentlyLocked: true);
        }
        break;
      case '5_min':
        if (elapsed >= const Duration(minutes: 5)) {
          state = state.copyWith(isCurrentlyLocked: true);
        }
        break;
      case '15_min':
        if (elapsed >= const Duration(minutes: 15)) {
          state = state.copyWith(isCurrentlyLocked: true);
        }
        break;
      case 'never':
        // No auto-lock on pause/resume
        break;
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final appLockProvider =
    NotifierProvider<AppLockNotifier, AppLockState>(AppLockNotifier.new);
