import '../repositories/app_data_repository.dart';
import '../config/app_env.dart';
import '../core/network/api_exception.dart';
import 'api_client.dart';
import 'storage_service.dart';
import 'package:uuid/uuid.dart';

class OtpSessionResult {
  final String requestId;
  final int expireSeconds;

  const OtpSessionResult({
    required this.requestId,
    required this.expireSeconds,
  });
}

class LoginResult {
  final String accessToken;
  final String refreshToken;
  final String uid;
  final String userId;
  final String phone;
  final String deviceId;

  const LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.uid,
    required this.userId,
    required this.phone,
    required this.deviceId,
  });
}

class AuthService {
  AuthService({AppDataRepository? repository, ApiClient? apiClient})
      : _repository = repository ?? AppDataRepository.instance,
        _apiClient = apiClient ?? ApiClient.instance;

  final AppDataRepository _repository;
  final ApiClient _apiClient;

  AuthStateSnapshot loadAuthState() {
    return _repository.loadAuthState();
  }

  Future<OtpSessionResult> sendOtp(String phone) async {
    try {
      final data = await _apiClient.post<Map<String, dynamic>>(
        '/auth/otp/send',
        authRequired: false,
        data: {'phone': phone},
      );

      return OtpSessionResult(
        requestId: data['requestId']?.toString() ?? '',
        expireSeconds: (data['expireSeconds'] as num?)?.toInt() ?? 60,
      );
    } catch (_) {
      if (!AppEnv.allowLocalAuthFallbacks) {
        rethrow;
      }

      return OtpSessionResult(
        requestId: 'local_otp_${DateTime.now().millisecondsSinceEpoch}',
        expireSeconds: 60,
      );
    }
  }

  Future<LoginResult> login({
    required String phone,
    required String code,
    required String requestId,
  }) async {
    final deviceId = await _getOrCreateDeviceId();
    try {
      final data = await _apiClient.post<Map<String, dynamic>>(
        '/auth/otp/verify',
        authRequired: false,
        data: {
          'phone': phone,
          'code': code,
          'requestId': requestId,
          'deviceId': deviceId,
        },
      );

      final user = data['user'];
      if (user is! Map<String, dynamic>) {
        throw const ApiException(
          code: 'INVALID_USER_DATA',
          message: '登录返回缺少用户信息',
        );
      }

      return LoginResult(
        accessToken: data['accessToken']?.toString() ?? '',
        refreshToken: data['refreshToken']?.toString() ?? '',
        uid: user['uid']?.toString() ?? '',
        userId: user['userId']?.toString() ?? '',
        phone: user['phone']?.toString() ?? phone,
        deviceId: deviceId,
      );
    } catch (_) {
      if (!AppEnv.allowLocalAuthFallbacks) {
        rethrow;
      }

      if (code != '123456') {
        throw const ApiException(code: 'AUTH_OTP_INVALID', message: '验证码错误');
      }

      final uid = _generateUidFromPhone(phone);
      return LoginResult(
        accessToken: 'local_atk_${DateTime.now().millisecondsSinceEpoch}',
        refreshToken: 'local_rtk_${DateTime.now().millisecondsSinceEpoch}',
        uid: uid,
        userId: uid,
        phone: phone,
        deviceId: deviceId,
      );
    }
  }

  Future<void> saveLogin({
    required String phone,
    required String token,
    required String uid,
    required String refreshToken,
    required String deviceId,
  }) async {
    final previousUid = StorageService.getUid();
    if (previousUid != null && previousUid.isNotEmpty && previousUid != uid) {
      await _repository.clearSessionState();
    }

    await _repository.saveAuthState(
      phone: phone,
      token: token,
      uid: uid,
      refreshToken: refreshToken,
      deviceId: deviceId,
    );
  }

  Future<void> updatePhone(String phone, {String? uid}) async {
    await _repository.savePhone(phone, uid: uid);
  }

  Future<void> deleteAccount() async {
    final token = StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      try {
        await _apiClient.delete<Map<String, dynamic>>('/auth/account');
      } catch (_) {}
    }
    await _repository.clearSessionState();
  }

  Future<void> clearLoginState() async {
    final token = StorageService.getToken();
    final deviceId = StorageService.getDeviceId() ?? await _getOrCreateDeviceId();
    if (token != null && token.isNotEmpty) {
      try {
        await _apiClient.post<Map<String, dynamic>>(
          '/auth/logout',
          data: {'deviceId': deviceId},
        );
      } catch (_) {}
    }
    await _repository.clearSessionState();
  }

  Future<String> _getOrCreateDeviceId() async {
    final stored = StorageService.getDeviceId();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    final deviceId = const Uuid().v4();
    await _repository.saveDeviceId(deviceId);
    return deviceId;
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
