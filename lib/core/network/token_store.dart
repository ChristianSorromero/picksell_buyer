import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the Sanctum bearer token in the platform keystore (Android
/// Keystore-backed EncryptedSharedPreferences / iOS Keychain) instead of
/// plain SharedPreferences. Tokens saved by older builds are migrated on
/// first read.
class TokenStore {
  TokenStore._();

  static const _key = 'auth_token';
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  /// In-memory copy so every request doesn't hit the keystore.
  static String? _cached;
  static bool _loaded = false;

  static Future<String?> read() async {
    if (_loaded) return _cached;
    String? token;
    try {
      token = await _secure.read(key: _key);
    } catch (_) {
      token = null; // keystore unavailable (e.g. restored backup) → re-login
    }
    if (token == null) {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_key);
      if (legacy != null && legacy.isNotEmpty) {
        token = legacy;
        await write(legacy);
        await prefs.remove(_key);
      }
    }
    _cached = token;
    _loaded = true;
    return token;
  }

  static Future<void> write(String token) async {
    _cached = token;
    _loaded = true;
    await _secure.write(key: _key, value: token);
  }

  static Future<void> clear() async {
    _cached = null;
    _loaded = true;
    try {
      await _secure.delete(key: _key);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
