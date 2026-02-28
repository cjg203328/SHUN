import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/permission_manager.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  String? _phone;
  String? _token;
  bool _isLoggedIn = false;
  bool _isInitialized = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;
  String? get phone => _phone;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _loadAuth();
  }

  Future<void> _loadAuth() async {
    final state = _authService.loadAuthState();
    _phone = state.phone;
    _token = state.token;
    _isLoggedIn = _phone != null && _token != null;
    _isInitialized = true;

    notifyListeners();
  }

  // 更新手机号
  Future<void> updatePhone(String phone) async {
    _phone = phone;
    await _authService.updatePhone(phone);
    notifyListeners();
  }

  Future<bool> login(String phone, String code) async {
    if (!_authService.validateCode(code)) {
      return false;
    }

    _phone = phone;
    _token = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
    _isLoggedIn = true;

    await _authService.saveLogin(phone: phone, token: _token!);

    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _phone = null;
    _token = null;
    _isLoggedIn = false;

    await _authService.clearLoginState();

    // 清除位置权限缓存
    PermissionManager.clearSessionCache();

    notifyListeners();
  }
}
