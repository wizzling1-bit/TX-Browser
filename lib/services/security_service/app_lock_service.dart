import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:local_auth/local_auth.dart';

/// App Lock & Biometric Service.
///
/// Handles PIN hashing, biometric hardware checks, biometric authentication,
/// and failed attempt lockout logic.
class AppLockService {
  AppLockService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Hashes a 4-digit PIN with a fixed application salt.
  String hashPin(String pin) {
    const salt = 'tx_browser_secure_salt_v1';
    final bytes = utf8.encode('$salt:$pin');
    return crypto.sha256.convert(bytes).toString();
  }

  /// Verifies entered PIN against stored hash.
  bool verifyPin(String enteredPin, String storedHash) {
    return hashPin(enteredPin) == storedHash;
  }

  /// Checks if device supports biometric hardware (Fingerprint / Face ID).
  Future<bool> canCheckBiometrics() async {
    try {
      final isAvailable = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  /// Authenticates user via biometric prompt.
  Future<bool> authenticateBiometrics({
    String reason = 'Authenticate to unlock Tx Browser',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
      );
    } catch (_) {
      return false;
    }
  }
}
