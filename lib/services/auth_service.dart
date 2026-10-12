import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// -----------------------------------------------------------------------
/// API CONFIG
/// -----------------------------------------------------------------------
/// Central place for the backend base URL. This is the ONLY line you
/// should need to change when moving between devices/environments.
class ApiConfig {
  /// Real Android device + php artisan serve on your PC.
  ///
  /// 1. Make sure your phone and PC are on the SAME WiFi network.
  /// 2. Find your PC's local IP:
  ///      Windows:  ipconfig            -> look for "IPv4 Address"
  ///      Mac/Linux: ifconfig | ip addr -> look for "inet 192.168.x.x"
  /// 3. Start Laravel so it listens on all interfaces, not just localhost:
  ///      php artisan serve --host=0.0.0.0 --port=8000
  /// 4. Replace the IP below with YOUR PC's IP (keep the port :8000).
  static const String baseUrl = 'https://scurvy-scary-bonding.ngrok-free.dev/api';

  // Emulator-only shortcuts, kept for reference:
  //   Android emulator -> 'http://10.0.2.2:8000/api'
  //   iOS simulator     -> 'http://127.0.0.1:8000/api'
}

/// Uniform result wrapper so the UI never has to parse raw http.Response
/// or jsonDecode itself.
class ApiResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? errors; // field-level Laravel validation errors

  ApiResult({
    required this.success,
    required this.message,
    this.data,
    this.errors,
  });

  /// Convenience: first validation error message, if any — handy for a
  /// quick SnackBar without walking the errors map yourself.
  String? get firstError {
    if (errors == null || errors!.isEmpty) return null;
    final firstList = errors!.values.first;
    if (firstList is List && firstList.isNotEmpty) {
      return firstList.first.toString();
    }
    return firstList.toString();
  }
}

class AuthService {
  Future<ApiResult> register({
    required String firstName,
    required String lastName,
    String? middleInitial,
    required String sex,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String contactNo,
    required String birthday,
    required String province,
    required String municipality,
    required String barangay,
    String? street,
    String? houseNo,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/register'),
        headers: {
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: {
          'first_name': firstName,
          'last_name': lastName,
          if (middleInitial != null && middleInitial.isNotEmpty)
            'middle_initial': middleInitial,
          'sex': sex,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'contact_no': contactNo,
          'birthday': birthday,
          'province': province,
          'municipality': municipality,
          'barangay': barangay,
          if (street != null && street.isNotEmpty) 'street': street,
          if (houseNo != null && houseNo.isNotEmpty) 'house_no': houseNo,
        },
      );
      return _parse(response, successCode: 201);
    } catch (e) {
      return ApiResult(success: false, message: 'Network error: $e');
    }
  }

  Future<ApiResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/login'),
        headers: {
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: {'email': email, 'password': password},
      );
      return _parse(response, successCode: 200);
    } catch (e) {
      return ApiResult(success: false, message: 'Network error: $e');
    }
  }

  /// Uploads a valid-ID file (jpg/png/pdf) for the given user using
  /// multipart/form-data, exactly what Laravel's `$request->file(...)`
  /// expects.
  Future<ApiResult> uploadId({
    required int userId,
    required File file,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/upload-id');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Accept'] = 'application/json'
        ..headers['ngrok-skip-browser-warning'] = 'true'
        ..fields['user_id'] = userId.toString()
        ..files.add(await http.MultipartFile.fromPath('id_file', file.path));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return _parse(response, successCode: 200);
    } catch (e) {
      return ApiResult(success: false, message: 'Network error: $e');
    }
  }

  /// Shared JSON-parsing logic for every endpoint above.
  ApiResult _parse(http.Response response, {required int successCode}) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return ApiResult(
        success: false,
        message: 'Unexpected server response (${response.statusCode}).',
      );
    }

    if (response.statusCode == successCode) {
      return ApiResult(
        success: true,
        message: body['message']?.toString() ?? 'Success',
        data: body,
      );
    }

    return ApiResult(
      success: false,
      message: body['message']?.toString() ?? 'Something went wrong.',
      errors: (body['errors'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

/// -----------------------------------------------------------------------
/// SESSION MANAGER
/// -----------------------------------------------------------------------
/// Persists the Sanctum token + basic user info on-device so the person
/// doesn't have to log in every time they open the app. Swap this out
/// (e.g. for flutter_secure_storage) later without touching AuthService.
class SessionManager {
  static const _kTokenKey = 'auth_token';
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
    await prefs.setInt(_kUserIdKey, userId);
    await prefs.setString(_kUserNameKey, name);
    await prefs.setString(_kUserEmailKey, email);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTokenKey);
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kUserIdKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUserIdKey);
    await prefs.remove(_kUserNameKey);
    await prefs.remove(_kUserEmailKey);
  }
}