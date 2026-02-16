import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AppLockService extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isLocked = false;
  bool _isEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isAuthenticated = false;

  bool get isLocked => _isLocked;
  bool get isEnabled => _isEnabled;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isAuthenticated => _isAuthenticated;

  AppLockService() {
    _init();
  }

  Future<void> _init() async {
    String? enabled = await _storage.read(key: 'app_lock_enabled');
    String? bioEnabled = await _storage.read(key: 'biometric_enabled');
    
    _isEnabled = enabled == 'true';
    _isBiometricEnabled = bioEnabled == 'true';
    
    // If lock is enabled, we start in a locked state until authenticated
    if (_isEnabled) {
      _isLocked = true;
    }
    notifyListeners();
  }

  // Called when app resumes or starts
  void lockApp() {
    if (_isEnabled && !_isLocked) {
      _isLocked = true;
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  // Called when user successfully enters PIN or Biometrics
  void unlockApp() {
    _isLocked = false;
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<bool> validatePin(String inputPin) async {
    String? storedPin = await _storage.read(key: 'app_lock_pin');
    return storedPin == inputPin;
  }

  Future<void> setPin(String newPin) async {
    await _storage.write(key: 'app_lock_pin', value: newPin);
    await _storage.write(key: 'app_lock_enabled', value: 'true');
    _isEnabled = true;
    notifyListeners();
  }
  
  Future<void> disableLock() async {
    await _storage.delete(key: 'app_lock_pin');
    await _storage.write(key: 'app_lock_enabled', value: 'false');
    await _storage.write(key: 'biometric_enabled', value: 'false');
    _isEnabled = false;
    _isBiometricEnabled = false;
    _isLocked = false;
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: 'biometric_enabled', value: enabled.toString());
    _isBiometricEnabled = enabled;
    notifyListeners();
  }

  Future<bool> authenticateWithBiometrics() async {
  try {
    final bool isDeviceSupported = await _localAuth.isDeviceSupported();
    if (!isDeviceSupported) return false;

    final bool didAuthenticate = await _localAuth.authenticate(
      localizedReason: 'Please authenticate to unlock the app',
    );

    if (didAuthenticate) {
      unlockApp();
    }

    return didAuthenticate;
  } catch (e) {
    debugPrint('Biometric Error: $e');
    return false;
  }
}


  
  // Helper to check blindly if biometrics are available directly
  Future<bool> get canCheckBiometrics async {
    try {
        return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (e) {
        return false;
    }
  }
}
