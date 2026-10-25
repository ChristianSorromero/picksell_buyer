import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/network/token_store.dart';

export '../core/network/api_client.dart' show ApiConfig, ApiResult, ApiException;

class AuthService {
  AuthService({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// Step 2 of buyer registration: is this email / mobile still free?
  Future<ApiResult> checkContact({
    required String email,
    required String contactNo,
  }) {
    return _api.send('POST', '/register/check-contact', body: {
      'email': email,
      'contact_no': contactNo,
    });
  }

  /// Creates a pending buyer account and emails a six-digit code.
  /// `contactNo` is the local format (09XXXXXXXXX); `birthday` is yyyy-MM-dd.
  Future<ApiResult> register({
    required String firstName,
    required String lastName,
    required String birthday,
    required String email,
    required String contactNo,
    required String password,
    required String passwordConfirmation,
    required bool acceptedTerms,
  }) {
    return _api.send('POST', '/register', body: {
      'first_name': firstName,
      'last_name': lastName,
      'birthday': birthday,
      'email': email,
      'contact_no': contactNo,
      'password': password,
      'password_confirmation': passwordConfirmation,
      if (acceptedTerms) 'terms': '1',
    });
  }

  /// On success `data` holds `token` + `user`, same shape as [login].
  Future<ApiResult> verifyEmail({required String email, required String code}) {
    return _api.send('POST', '/register/verify', body: {'email': email, 'code': code});
  }

  Future<ApiResult> resendCode({required String email}) {
    return _api.send('POST', '/register/resend', body: {'email': email});
  }

  /// A 403 with `data['needs_verification'] == true` means the account
  /// exists but the emailed code was never entered.
  Future<ApiResult> login({
    required String email,
    required String password,
  }) {
    return _api.send('POST', '/login', body: {'email': email, 'password': password});
  }

  /// Revokes the token server-side (best effort) and clears the session.
  Future<void> logout() async {
    await _api.send('POST', '/buyer/logout', body: const {});
    await SessionManager().clear();
  }

  /// Terms of Service / Privacy Policy text managed in the admin panel.
  Future<ApiResult> legal(String document) => _api.send('GET', '/legal/$document');
}

/// -----------------------------------------------------------------------
/// SESSION MANAGER
/// -----------------------------------------------------------------------
/// Persists the Sanctum token + basic user info on-device so the person
/// doesn't have to log in every time they open the app. Swap this out
/// (e.g. for flutter_secure_storage) later without touching AuthService.
class SessionManager {
  static const _kUserIdKey = 'user_id';
  static const _kUserNameKey = 'user_name';
  static const _kUserEmailKey = 'user_email';

  Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserNameKey);
  }

  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserEmailKey);
  }

  Future<void> save({
    required String token,
    required int userId,
    required String name,
    required String email,
  }) async {
    await TokenStore.write(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kUserIdKey, userId);
    await prefs.setString(_kUserNameKey, name);
    await prefs.setString(_kUserEmailKey, email);
  }

  Future<String?> getToken() => TokenStore.read();

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kUserIdKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clear() async {
    await TokenStore.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserIdKey);
    await prefs.remove(_kUserNameKey);
    await prefs.remove(_kUserEmailKey);
  }
}
