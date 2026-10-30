import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/network/token_store.dart';

export '../core/network/api_client.dart' show ApiConfig, ApiResult, ApiException;

class AuthService {
  AuthService({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  // ── Registration: the website's flow ─────────────────────────────────
  // 1. prove the email with a code → registration_token
  // 2. submit the details with a valid ID → pending until an admin approves

  /// Is this email / mobile still free?
  Future<ApiResult> checkContact({
    required String email,
    required String contactNo,
  }) {
    return _api.send('POST', '/register/check-contact', body: {
      'email': email,
      'contact_no': contactNo,
    });
  }

  /// Emails a six-digit code to the address being registered (also used to resend).
  Future<ApiResult> sendRegistrationCode({required String email, String? firstName}) =>
      _api.send('POST', '/register/email-code', body: {'email': email, 'first_name': firstName});

  /// On success `data['registration_token']` lets [register] use this email.
  Future<ApiResult> verifyRegistrationCode({required String email, required String code}) =>
      _api.send('POST', '/register/email-code/verify', body: {'email': email, 'code': code});

  /// Creates the buyer account, pending admin approval (the website's rule).
  /// `contactNo` is 09XXXXXXXXX, `birthday` yyyy-MM-dd, [idPhoto] a picked image path.
  Future<ApiResult> register({
    required String registrationToken,
    required String firstName,
    required String lastName,
    String? middleInitial,
    required String sex,
    required String birthday,
    required String email,
    required String contactNo,
    required String province,
    required String municipality,
    required String barangay,
    String? street,
    String? houseNo,
    required String idPhoto,
    required String password,
    required String passwordConfirmation,
    required bool acceptedTerms,
    required bool confirmedAccurate,
  }) {
    return _api.multipart('/register', fields: {
      'registration_token': registrationToken,
      'first_name': firstName,
      'last_name': lastName,
      if (middleInitial != null) 'middle_initial': middleInitial,
      'sex': sex,
      'birthday': birthday,
      'email': email,
      'contact_no': contactNo,
      'province': province,
      'municipality': municipality,
      'barangay': barangay,
      if (street != null) 'street': street,
      if (houseNo != null) 'house_no': houseNo,
      'password': password,
      'password_confirmation': passwordConfirmation,
      if (acceptedTerms) 'terms': '1',
      if (confirmedAccurate) 'confirmed': '1',
    }, singleFiles: {'id_upload': idPhoto});
  }

  /// A 403 carries `data['status']` (pending, disapproved, suspended) for
  /// accounts that can't sign in yet.
  Future<ApiResult> login({
    required String email,
    required String password,
  }) {
    return _api.send('POST', '/login', body: {'email': email, 'password': password});
  }

  /// Emails a six-digit reset code. The answer is the same whether or not
  /// the email has an account.
  Future<ApiResult> forgotPassword({required String email}) =>
      _api.send('POST', '/password/forgot', body: {'email': email});

  /// Sets a new password with the emailed code; signs out every device.
  Future<ApiResult> resetPassword({
    required String email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) {
    return _api.send('POST', '/password/reset', body: {
      'email': email,
      'code': code,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
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
