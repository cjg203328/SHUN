import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/permission_manager.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  String? _phone;
  String? _token;
  String? _uid;
  bool _isLoggedIn = false;
  bool _isInitialized = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;
  String? get phone => _phone;
  String? get uid => _uid;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _loadAuth();
  }

  Future<void> _loadAuth() async {
    final state = _authService.loadAuthState();
    _phone = state.phone;
    _token = state.token;
    _uid = state.uid;
    _isLoggedIn = _phone != null && _token != null;
    _isInitialized = true;

    if (_isLoggedIn && (_uid == null || _uid!.isEmpty)) {
      _uid = _generateUidFromPhone(_phone!);
      await _authService.updatePhone(_phone!, uid: _uid);
    }

    notifyListeners();
  }

  // 更新手机号
  Future<void> updatePhone(String phone) async {
    _phone = phone;
    _uid ??= _generateUidFromPhone(phone);
    await _authService.updatePhone(phone, uid: _uid);
    notifyListeners();
  }

  Future<bool> login(String phone, String code) async {
    if (!_authService.validateCode(code)) {
      return false;
    }

    _phone = phone;
    _token = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
    _uid ??= _generateUidFromPhone(phone);
    _isLoggedIn = true;

    await _authService.saveLogin(phone: phone, token: _token!, uid: _uid!);

    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _phone = null;
    _token = null;
    _uid = null;
    _isLoggedIn = false;

    await _authService.clearLoginState();

    // 清除位置权限缓存
    PermissionManager.clearSessionCache();

    notifyListeners();
  }

  String _generateUidFromPhone(String phone) {
    var hash = 0;
    for (final codeUnit in phone.codeUnits) {
      hash = (hash * 131 + codeUnit) & 0x7fffffff;
    }
    final base = hash.toRadixString(36).toUpperCase().padLeft(6, '0');
    final tail = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
    return 'SN${base.substring(base.length - 6)}$tail';
  }
}
