import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gsmvoiceee/models/auth_models.dart';

abstract class AuthApiClient {
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthResult> login({required String email, required String password});

  Future<UserProfile> getMe(String token);

  Future<void> logout(String token);

  void dispose();
}

class HttpAuthApiClient implements AuthApiClient {
  HttpAuthApiClient({String? baseUrl, HttpClient? client})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://10.0.2.2:8080',
          ),
      _client = client ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 10);
  }

  final String baseUrl;
  final HttpClient _client;

  @override
  void dispose() {
    _client.close(force: true);
  }

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final responseData = await _sendJson(
      method: 'POST',
      path: '/auth/register',
      body: {'name': name, 'email': email, 'password': password},
    );
    return AuthResult.fromJson(responseData);
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final responseData = await _sendJson(
      method: 'POST',
      path: '/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthResult.fromJson(responseData);
  }

  @override
  Future<UserProfile> getMe(String token) async {
    final responseData = await _sendJson(
      method: 'GET',
      path: '/auth/me',
      token: token,
    );
    final userMap = responseData['user'] as Map<String, dynamic>?;
    if (userMap == null) {
      throw const ApiException('Dữ liệu tài khoản không hợp lệ.');
    }
    return UserProfile.fromJson(userMap);
  }

  @override
  Future<void> logout(String token) async {
    try {
      await _sendJson(method: 'POST', path: '/auth/logout', token: token);
    } catch (_) {
      // Logout in client should succeed even if network fails
    }
  }

  Future<Map<String, dynamic>> _sendJson({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final request = await _openRequest(method, uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      if (body != null) {
        final payload = utf8.encode(jsonEncode(body));
        request.contentLength = payload.length;
        request.add(payload);
      }

      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 10));

      final statusCode = response.statusCode;
      Map<String, dynamic> jsonMap = <String, dynamic>{};
      if (responseBody.isNotEmpty) {
        try {
          final decoded = jsonDecode(responseBody);
          if (decoded is Map<String, dynamic>) {
            jsonMap = decoded;
          }
        } catch (_) {}
      }

      if (statusCode >= 200 && statusCode < 300) {
        return jsonMap;
      }

      final rawError = jsonMap['error'] as String?;
      final friendlyMessage = _translateError(statusCode, rawError);
      throw ApiException(friendlyMessage, statusCode: statusCode);
    } on SocketException {
      throw const ApiException(
        'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.',
      );
    } on TimeoutException {
      throw const ApiException(
        'Yêu cầu quá thời gian chờ. Vui lòng thử lại sau.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Đã xảy ra lỗi: $e');
    }
  }

  Future<HttpClientRequest> _openRequest(String method, Uri uri) {
    if (method == 'POST') {
      return _client.postUrl(uri);
    }
    return _client.getUrl(uri);
  }

  String _translateError(int statusCode, String? raw) {
    if (raw == null || raw.isEmpty) {
      if (statusCode == 401) {
        return 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.';
      }
      if (statusCode == 404) {
        return 'Không tìm thấy máy chủ xác thực.';
      }
      return 'Lỗi hệ thống ($statusCode). Vui lòng thử lại sau.';
    }

    final lower = raw.toLowerCase();
    if (lower.contains('invalid email or password')) {
      return 'Email hoặc mật khẩu không chính xác.';
    }
    if (lower.contains('already registered')) {
      return 'Email này đã được đăng ký trên hệ thống.';
    }
    if (lower.contains('password must be at least')) {
      return 'Mật khẩu phải có tối thiểu 8 ký tự.';
    }
    if (lower.contains('invalid email address')) {
      return 'Địa chỉ email không đúng định dạng.';
    }
    if (lower.contains('unauthorized')) {
      return 'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.';
    }
    return raw;
  }
}
