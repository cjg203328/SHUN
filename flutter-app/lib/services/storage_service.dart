import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'app_install_guard.dart';

class StorageService {
  static late SharedPreferences _prefs;
  static const String _firstInstallTimeKey = 'first_install_time_ms';
  static const String _chatStateKey = 'chat_state_v1';
  static const String _notificationCenterKey = 'notification_center_v1';
  static const String _analyticsStateKey = 'analytics_events_v1';
  static const String _pushStateKey = 'push_runtime_state_v1';
  static const String _dataSchemaVersionKey = 'app_data_schema_version';
  static const List<String> _sessionScopedKeys = <String>[
    'phone',
    'token',
    'uid',
    'refresh_token',
    _chatStateKey,
    _notificationCenterKey,
    _analyticsStateKey,
    _pushStateKey,
    'nickname',
    'avatar',
    'status',
    'signature',
    'match_count',
    'last_reset_date',
    'blocked_user_ids',
    'invisible_mode',
    'notification_enabled',
    'vibration_enabled',
    'day_theme_enabled',
    'transparent_homepage',
    'portrait_fullscreen_background',
    'user_avatar_path',
    'user_background_path',
  ];

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _syncInstallState();
  }

  static Future<void> _syncInstallState() async {
    final currentInstallTime = await AppInstallGuard.getFirstInstallTimeMs();
    if (currentInstallTime == null) return;

    final storedInstallTime = _prefs.getInt(_firstInstallTimeKey);
    final isReinstallWithRestoredData =
        storedInstallTime != null && storedInstallTime != currentInstallTime;

    if (isReinstallWithRestoredData) {
      await clearSessionData();
    }

    if (storedInstallTime != currentInstallTime) {
      await _prefs.setInt(_firstInstallTimeKey, currentInstallTime);
    }
  }

  // 用户相关
  static Future<void> savePhone(String phone) async {
    await _prefs.setString('phone', phone);
  }

  static String? getPhone() {
    return _prefs.getString('phone');
  }

  static Future<void> saveToken(String token) async {
    await _prefs.setString('token', token);
  }

  static String? getToken() {
    return _prefs.getString('token');
  }

  static Future<void> saveUid(String uid) async {
    await _prefs.setString('uid', uid);
  }

  static String? getUid() {
    return _prefs.getString('uid');
  }

  static Future<void> saveRefreshToken(String refreshToken) async {
    await _prefs.setString('refresh_token', refreshToken);
  }

  static String? getRefreshToken() {
    return _prefs.getString('refresh_token');
  }

  static Future<void> saveDeviceId(String deviceId) async {
    await _prefs.setString('device_id', deviceId);
  }

  static String? getDeviceId() {
    return _prefs.getString('device_id');
  }

  static Future<void> clearAuth() async {
    await _prefs.remove('phone');
    await _prefs.remove('token');
    await _prefs.remove('uid');
    await _prefs.remove('refresh_token');
  }

  static Future<void> clearSessionData({bool preserveDeviceId = true}) async {
    for (final key in _sessionScopedKeys) {
      await _prefs.remove(key);
    }
    if (!preserveDeviceId) {
      await _prefs.remove('device_id');
    }
  }

  // 聊天数据持久化
  static Future<void> saveChatState(Map<String, dynamic> state) async {
    await _prefs.setString(_chatStateKey, jsonEncode(state));
  }

  static Map<String, dynamic>? getChatState() {
    final raw = _prefs.getString(_chatStateKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {}
    return null;
  }

  static Future<void> clearChatState() async {
    await _prefs.remove(_chatStateKey);
  }

  static Future<void> saveNotificationCenterState(String state) async {
    await _prefs.setString(_notificationCenterKey, state);
  }

  static String? getNotificationCenterState() {
    return _prefs.getString(_notificationCenterKey);
  }

  static Future<void> clearNotificationCenterState() async {
    await _prefs.remove(_notificationCenterKey);
  }

  static Future<void> saveAnalyticsState(String state) async {
    await _prefs.setString(_analyticsStateKey, state);
  }

  static String? getAnalyticsState() {
    return _prefs.getString(_analyticsStateKey);
  }

  static Future<void> clearAnalyticsState() async {
    await _prefs.remove(_analyticsStateKey);
  }

  static Future<void> savePushRuntimeState(String state) async {
    await _prefs.setString(_pushStateKey, state);
  }

  static String? getPushRuntimeState() {
    return _prefs.getString(_pushStateKey);
  }

  static Future<void> clearPushRuntimeState() async {
    await _prefs.remove(_pushStateKey);
  }

  static Future<void> saveDataSchemaVersion(int version) async {
    await _prefs.setInt(_dataSchemaVersionKey, version);
  }

  static int? getDataSchemaVersion() {
    return _prefs.getInt(_dataSchemaVersionKey);
  }

  // 用户资料
  static Future<void> saveNickname(String nickname) async {
    await _prefs.setString('nickname', nickname);
  }

  static String? getNickname() {
    return _prefs.getString('nickname');
  }

  static Future<void> saveAvatar(String avatar) async {
    await _prefs.setString('avatar', avatar);
  }

  static String? getAvatar() {
    return _prefs.getString('avatar');
  }

  static Future<void> saveStatus(String status) async {
    await _prefs.setString('status', status);
  }

  static String? getStatus() {
    return _prefs.getString('status');
  }

  static Future<void> saveSignature(String signature) async {
    await _prefs.setString('signature', signature);
  }

  static String? getSignature() {
    return _prefs.getString('signature');
  }

  // 匹配次数
  static Future<void> saveMatchCount(int count) async {
    await _prefs.setInt('match_count', count);
  }

  static int getMatchCount() {
    return _prefs.getInt('match_count') ?? 20;
  }

  // 最后重置时间
  static Future<void> saveLastResetDate(DateTime date) async {
    await _prefs.setString('last_reset_date', date.toIso8601String());
  }

  static DateTime? getLastResetDate() {
    final dateStr = _prefs.getString('last_reset_date');
    return dateStr != null ? DateTime.parse(dateStr) : null;
  }

  // 黑名单
  static Future<void> saveBlockedUserIds(List<String> userIds) async {
    await _prefs.setStringList('blocked_user_ids', userIds);
  }

  static List<String> getBlockedUserIds() {
    return _prefs.getStringList('blocked_user_ids') ?? <String>[];
  }

  // 设置项
  static Future<void> saveInvisibleMode(bool enabled) async {
    await _prefs.setBool('invisible_mode', enabled);
  }

  static bool getInvisibleMode() {
    return _prefs.getBool('invisible_mode') ?? false;
  }

  static Future<void> saveNotificationEnabled(bool enabled) async {
    await _prefs.setBool('notification_enabled', enabled);
  }

  static bool getNotificationEnabled() {
    return _prefs.getBool('notification_enabled') ?? true;
  }

  static Future<void> saveVibrationEnabled(bool enabled) async {
    await _prefs.setBool('vibration_enabled', enabled);
  }

  static bool getVibrationEnabled() {
    return _prefs.getBool('vibration_enabled') ?? true;
  }

  static Future<void> saveDayThemeEnabled(bool enabled) async {
    await _prefs.setBool('day_theme_enabled', enabled);
  }

  static bool getDayThemeEnabled() {
    return _prefs.getBool('day_theme_enabled') ?? false;
  }

  static Future<void> saveTransparentHomepage(bool enabled) async {
    await _prefs.setBool('transparent_homepage', enabled);
  }

  static bool getTransparentHomepage() {
    return _prefs.getBool('transparent_homepage') ?? false;
  }

  static Future<void> savePortraitFullscreenBackground(bool enabled) async {
    await _prefs.setBool('portrait_fullscreen_background', enabled);
  }

  static bool getPortraitFullscreenBackground() {
    return _prefs.getBool('portrait_fullscreen_background') ?? false;
  }

  // 本地密码（演示）
  static Future<void> saveLocalPassword(String password) async {
    await _prefs.setString('local_password', password);
  }

  static String getLocalPassword() {
    return _prefs.getString('local_password') ?? '123456';
  }
}
