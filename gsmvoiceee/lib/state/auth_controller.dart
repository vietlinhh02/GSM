import 'package:flutter/foundation.dart';
import 'package:gsmvoiceee/models/auth_models.dart';
import 'package:gsmvoiceee/services/api_client.dart';

class AuthController extends ChangeNotifier {
  AuthController({required AuthApiClient apiClient}) : _apiClient = apiClient;

  final AuthApiClient _apiClient;

  String? _token;
  UserProfile? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isAuthenticated => _token != null && _currentUser != null;
  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiClient.login(
        email: email.trim(),
        password: password,
      );
      _token = result.token;

      // Backend is authority: fetch verified profile from /auth/me
      final profile = await _apiClient.getMe(_token!);
      _currentUser = profile;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _token = null;
      _currentUser = null;
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _token = null;
      _currentUser = null;
      _errorMessage = 'Đã xảy ra lỗi không xác định. Vui lòng thử lại.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiClient.register(
        name: name.trim(),
        email: email.trim(),
        password: password,
      );
      _token = result.token;

      // Verify with backend authority via /auth/me
      final profile = await _apiClient.getMe(_token!);
      _currentUser = profile;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _token = null;
      _currentUser = null;
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _token = null;
      _currentUser = null;
      _errorMessage = 'Đã xảy ra lỗi không xác định. Vui lòng thử lại.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final activeToken = _token;
    _token = null;
    _currentUser = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();

    if (activeToken != null) {
      await _apiClient.logout(activeToken);
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
