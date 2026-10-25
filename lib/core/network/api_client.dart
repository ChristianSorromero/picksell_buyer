import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'token_store.dart';

/// -----------------------------------------------------------------------
/// API CONFIG
/// -----------------------------------------------------------------------
/// Override per environment without editing code:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api
class ApiConfig {
  ApiConfig._();

  /// Defaults to the Android emulator, which reaches the PC's localhost
  /// (php artisan serve) through 10.0.2.2.
  ///   iOS simulator -> http://127.0.0.1:8000/api
  ///   ngrok tunnel  -> https://scurvy-scary-bonding.ngrok-free.dev/api
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Web (Chrome) can't reach 10.0.2.2 — that alias exists only inside
  /// the Android emulator — so browsers use localhost.
  static String get baseUrl => _override.isNotEmpty
      ? _override
      : kIsWeb
          ? 'http://127.0.0.1:8000/api'
          : 'http://10.0.2.2:8000/api';
}

/// Uniform result wrapper so the UI never has to parse raw http.Response
/// or jsonDecode itself.
class ApiResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? errors; // field-level Laravel validation errors

  /// HTTP status, or null when the request never reached the server.
  final int? statusCode;

  ApiResult({
    required this.success,
    required this.message,
    this.data,
    this.errors,
    this.statusCode,
  });

  /// No connection / DNS / timeout — show the offline treatment, not a
  /// validation error.
  bool get isNetworkError => statusCode == null;

  /// Convenience: first validation error message, if any.
  String? get firstError {
    if (errors == null || errors!.isEmpty) return null;
    final firstList = errors!.values.first;
    if (firstList is List && firstList.isNotEmpty) {
      return firstList.first.toString();
    }
    return firstList.toString();
  }

  /// First message for one field, e.g. `fieldError('email')`.
  String? fieldError(String field) {
    final value = errors?[field];
    if (value is List && value.isNotEmpty) return value.first.toString();
    return value?.toString();
  }
}

/// Thrown by [ApiClient] helpers when a request fails. Screens catch it to
/// choose between an inline field error, an error dialog and the offline
/// state.
class ApiException implements Exception {
  ApiException(this.result);

  final ApiResult result;

  String get message => result.message;
  int? get statusCode => result.statusCode;
  bool get isNetworkError => result.isNetworkError;
  bool get isValidation => result.statusCode == 422 && (result.errors?.isNotEmpty ?? false);
  Map<String, dynamic>? get data => result.data;
  String? fieldError(String field) => result.fieldError(field);

  @override
  String toString() => 'ApiException(${result.statusCode}): ${result.message}';
}

/// One HTTP entry point for the whole app: base URL, JSON, bearer token,
/// timeouts and error mapping. Inject a fake [http.Client] in tests.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static ApiClient instance = ApiClient();

  /// Fires when the server rejects the stored token (401) so the app can
  /// send the user back to login.
  static final ValueNotifier<int> sessionExpired = ValueNotifier(0);

  static const Duration _timeout = Duration(seconds: 20);

  final http.Client _client;

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await TokenStore.read();
    return {
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    // Release builds must never send the bearer token over plain HTTP.
    if (kReleaseMode && uri.scheme != 'https') {
      throw StateError('API_BASE_URL must use https:// in release builds.');
    }
    if (query == null || query.isEmpty) return uri;
    final params = <String, dynamic>{};
    query.forEach((k, v) {
      if (v == null) return;
      params[k] = v is List ? v.map((e) => '$e').toList() : '$v';
    });
    return uri.replace(queryParameters: params);
  }

  Future<ApiResult> send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) {
    return _guard(() async {
      final request = http.Request(method, _uri(path, query))
        ..headers.addAll(await _headers(json: body != null));
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client.send(request).timeout(_timeout);
      return http.Response.fromStream(streamed);
    });
  }

  /// multipart/form-data, for evidence photo uploads.
  Future<ApiResult> multipart(
    String path, {
    required Map<String, String> fields,
    Map<String, List<String>> files = const {},
  }) {
    return _guard(() async {
      final request = http.MultipartRequest('POST', _uri(path))
        ..headers.addAll(await _headers())
        ..fields.addAll(fields);
      for (final entry in files.entries) {
        for (final path in entry.value) {
          request.files.add(await http.MultipartFile.fromPath('${entry.key}[]', path));
        }
      }
      final streamed = await _client.send(request).timeout(const Duration(seconds: 60));
      return http.Response.fromStream(streamed);
    });
  }

  Future<ApiResult> _guard(Future<http.Response> Function() run) async {
    try {
      final result = parse(await run());
      if (result.statusCode == 401) sessionExpired.value++;
      return result;
    } on SocketException {
      return ApiResult(success: false, message: 'You’re offline. Check your connection and try again.');
    } on TimeoutException {
      return ApiResult(success: false, message: 'The server took too long to respond. Please try again.');
    } on http.ClientException {
      return ApiResult(success: false, message: 'Couldn’t reach Picksell. Check your connection and try again.');
    }
  }

  /// Any 2xx is success.
  static ApiResult parse(http.Response response) {
    Map<String, dynamic> body;
    try {
      final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
      body = decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    } catch (_) {
      return ApiResult(
        success: false,
        statusCode: response.statusCode,
        message: 'Unexpected server response (${response.statusCode}).',
      );
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    final fallback = switch (response.statusCode) {
      401 => 'Your session has expired. Please log in again.',
      403 => 'You don’t have access to this.',
      404 => 'We couldn’t find what you were looking for.',
      429 => 'Too many attempts. Please wait a moment and try again.',
      >= 500 => 'Something went wrong on our side. Please try again.',
      _ => 'Something went wrong.',
    };

    return ApiResult(
      success: ok,
      statusCode: response.statusCode,
      message: body['message']?.toString() ?? (ok ? 'Success' : fallback),
      data: body,
      errors: ok ? null : (body['errors'] as Map?)?.cast<String, dynamic>(),
    );
  }

  // ── Throwing helpers for services ────────────────────────────────────────

  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) =>
      _unwrap(send('GET', path, query: query));

  Future<Map<String, dynamic>> postJson(String path, [Object? body]) =>
      _unwrap(send('POST', path, body: body ?? const {}));

  Future<Map<String, dynamic>> patchJson(String path, Object body) => _unwrap(send('PATCH', path, body: body));

  Future<Map<String, dynamic>> deleteJson(String path, [Object? body]) => _unwrap(send('DELETE', path, body: body));

  Future<Map<String, dynamic>> multipartJson(
    String path, {
    required Map<String, String> fields,
    Map<String, List<String>> files = const {},
  }) =>
      _unwrap(multipart(path, fields: fields, files: files));

  Future<Map<String, dynamic>> _unwrap(Future<ApiResult> pending) async {
    final result = await pending;
    if (!result.success) throw ApiException(result);
    return result.data ?? const {};
  }
}
