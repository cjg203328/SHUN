import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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

  static Future<void> clearAuth() async {
    await _prefs.remove('phone');
    await _prefs.remove('token');
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

  // 本地密码（演示）
  static Future<void> saveLocalPassword(String password) async {
    await _prefs.setString('local_password', password);
  }

  static String getLocalPassword() {
    return _prefs.getString('local_password') ?? '123456';
  }
}
