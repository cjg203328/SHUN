import 'dart:async';

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../services/chat_socket_service.dart';
import '../services/push_notification_service.dart';
import 'notification_center_provider.dart';
import '../utils/permission_manager.dart';
import '../core/network/api_exception.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  String? _phone;
  String? _token;
  String? _uid;
  bool _isLoggedIn = false;
  bool _isInitialized = false;
  String? _pendingOtpRequestId;
  String? _lastError;
  String? _pendingEntryHintSource;
  int _pendingEntryHintVersion = 0;

  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;
  String? get phone => _phone;
  String? get uid => _uid;
  String? get lastError => _lastError;
  int get pendingEntryHintVersion => _pendingEntryHintVersion;

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

    notifyListeners();
  }

  // 更新手机号
  Future<void> updatePhone(String phone) async {
    _phone = phone;
    await _authService.updatePhone(phone, uid: _uid);
    notifyListeners();
  }

  Future<bool> sendOtp(String phone) async {
    try {
      final result = await _authService.sendOtp(phone);
      _pendingOtpRequestId = result.requestId;
      _lastError = null;
      notifyListeners();
      return true;
    } catch (error) {
      _lastError = _mapError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String phone, String code) async {
    // Don't auto-send OTP during login - user should explicitly request it
    if (_pendingOtpRequestId == null) {
      _lastError = '请先获取验证码';
      notifyListeners();
      return false;
    }

    try {
      final result = await _authService.login(
        phone: phone,
        code: code,
        requestId: _pendingOtpRequestId!,
      );

      _phone = result.phone;
      _token = result.accessToken;
      _uid = result.uid;
      _isLoggedIn = true;
      _pendingOtpRequestId = null;
      _lastError = null;

      await _authService.saveLogin(
        phone: result.phone,
        token: result.accessToken,
        uid: result.uid,
        refreshToken: result.refreshToken,
        deviceId: result.deviceId,
      );

      await NotificationCenterProvider.instance.reloadFromStorage();
      _pendingEntryHintSource = 'login';
      _pendingEntryHintVersion++;
      notifyListeners();
      unawaited(_runPostLoginWarmup(result));
      return true;
    } catch (error) {
      await AnalyticsService.instance.track(
        'login_failed',
        level: 'warn',
        properties: {'reason': error.toString()},
      );
      _lastError = _mapError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    _phone = null;
    _token = null;
    _uid = null;
    _isLoggedIn = false;
    _pendingOtpRequestId = null;
    _lastError = null;
    _pendingEntryHintSource = null;
    notifyListeners();
    ChatSocketService.instance.disconnect();

    try {
      await _authService.deleteAccount();
    } catch (_) {}
    await NotificationCenterProvider.instance.clearSession();
    await PushNotificationService.instance.clearSession();
    await AnalyticsService.instance.track('account_deleted');
    await AnalyticsService.instance.clearSession();
    PermissionManager.clearSessionCache();
    return true;
  }

  Future<void> logout() async {
    _phone = null;
    _token = null;
    _uid = null;
    _isLoggedIn = false;
    _pendingOtpRequestId = null;
    _lastError = null;
    _pendingEntryHintSource = null;

    notifyListeners();

    ChatSocketService.instance.disconnect();
    await _authService.clearLoginState();
    await NotificationCenterProvider.instance.clearSession();
    await PushNotificationService.instance.clearSession();
    await AnalyticsService.instance.track('logout');
    await AnalyticsService.instance.clearSession();

    // 清除位置权限缓存
    PermissionManager.clearSessionCache();

    notifyListeners();
  }

  String _mapError(Object error) {
    if (error is ApiException) {
      return error.userMessage;
    }
    return '操作失败，请重试';
  }

  String? consumePendingEntryHintSource() {
    final source = _pendingEntryHintSource;
    _pendingEntryHintSource = null;
    return source;
  }

  @visibleForTesting
  void debugPrimePendingEntryHintSource(String source) {
    _pendingEntryHintSource = source;
    _pendingEntryHintVersion++;
  }

  Future<void> _runPostLoginWarmup(LoginResult result) async {
    try {
      await PushNotificationService.instance.initialize(
        notificationsEnabled: true,
      );
    } catch (error, stackTrace) {
      await AnalyticsService.instance.captureError(
        error,
        stackTrace,
        hint: 'auth_login_push_initialize',
      );
    }

    await AnalyticsService.instance.track(
      'login_success',
      properties: {
        'uid': result.uid,
        'phoneTail': result.phone.length >= 4
            ? result.phone.substring(result.phone.length - 4)
            : result.phone,
      },
    );
  }
}
