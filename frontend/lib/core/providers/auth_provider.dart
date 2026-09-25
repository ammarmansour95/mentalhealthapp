import 'package:flutter/material.dart';
import 'package:frontend/core/services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  String get role => _user?['role'] ?? 'PATIENT';
  String get status => _user?['status'] ?? 'ACTIVE';

  Future<void> initAuth() async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = await ApiService.getToken();
      if (token != null) {
        final res = await ApiService.get('/auth/me/');
        if (res['success'] == true) {
          _user = res['user'];
        }
      }
    } catch (e) {
      await ApiService.setToken(null);
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _errorMessage = null;

    try {
      final res = await ApiService.post('/auth/login/', {
        'email': email.trim().toLowerCase(),
        'password': password.trim(),
      });

      if (res['success'] == true) {
        await ApiService.setToken(res['token']);
        _user = res['user'];
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = res['message'] ?? 'فشل تسجيل الدخول';
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    required String phoneNumber,
    required int age,
    String? specialty,
  }) async {
    _errorMessage = null;

    try {
      final payload = <String, dynamic>{
        'email': email.trim().toLowerCase(),
        'password': password.trim(),
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'role': role,
        'phone_number': phoneNumber.trim(),
        'age': age,
      };
      if (specialty != null && specialty.isNotEmpty) {
        payload['specialty'] = specialty;
      }

      final res = await ApiService.post('/auth/register/', payload);

      if (res['success'] == true) {
        await ApiService.setToken(res['token']);
        _user = res['user'];
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = res['message'] ?? 'فشل إنشاء الحساب';
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await ApiService.setToken(null);
    _user = null;
    notifyListeners();
  }
}
