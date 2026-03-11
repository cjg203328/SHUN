import '../services/storage_service.dart';

class AuthStateSnapshot {
  final String? phone;
  final String? token;
  final String? uid;
  final String? refreshToken;
  final String? deviceId;

  const AuthStateSnapshot({
    required this.phone,
    required this.token,
    required this.uid,
    this.refreshToken,
    this.deviceId,
  });
}

class ProfileStateSnapshot {
  final String nickname;
  final String avatar;
  final String status;
  final String signature;
  final bool transparentHomepage;
  final bool portraitFullscreenBackground;

  const ProfileStateSnapshot({
    required this.nickname,
    required this.avatar,
    required this.status,
    required this.signature,
    required this.transparentHomepage,
    required this.portraitFullscreenBackground,
  });
}

class MatchStateSnapshot {
  final int matchCount;
  final DateTime? lastResetDate;

  const MatchStateSnapshot({
    required this.matchCount,
    required this.lastResetDate,
  });
}

class SettingsStateSnapshot {
  final bool invisibleMode;
  final bool notificationEnabled;
  final bool vibrationEnabled;
  final bool dayThemeEnabled;

  const SettingsStateSnapshot({
    required this.invisibleMode,
    required this.notificationEnabled,
    required this.vibrationEnabled,
    required this.dayThemeEnabled,
  });
}

class AppDataRepository {
  AppDataRepository._();

  static final AppDataRepository instance = AppDataRepository._();

  static const int _currentSchemaVersion = 3;
  static const String _defaultSignature = '这个人很神秘，什么都没留下';

  Future<void> bootstrap() async {
    final current = StorageService.getDataSchemaVersion() ?? 1;
    if (current < _currentSchemaVersion) {
      await _migrate(current);
      await StorageService.saveDataSchemaVersion(_currentSchemaVersion);
    }
  }

  Future<void> _migrate(int fromVersion) async {
    if (fromVersion < 2) {
      final signature = StorageService.getSignature();
      if (signature == null || signature.trim().isEmpty) {
        await StorageService.saveSignature(_defaultSignature);
      }

      final chatState = StorageService.getChatState();
      if (chatState != null && chatState['version'] == null) {
        chatState['version'] = 1;
        await StorageService.saveChatState(chatState);
      }
    }

    if (fromVersion < 3) {
      final fullscreen = StorageService.getPortraitFullscreenBackground();
      if (!fullscreen && StorageService.getTransparentHomepage()) {
        await StorageService.saveTransparentHomepage(false);
      }
    }
  }

  AuthStateSnapshot loadAuthState() {
    return AuthStateSnapshot(
      phone: StorageService.getPhone(),
      token: StorageService.getToken(),
      uid: StorageService.getUid(),
      refreshToken: StorageService.getRefreshToken(),
      deviceId: StorageService.getDeviceId(),
    );
  }

  Future<void> saveAuthState({
    required String phone,
    required String token,
    required String uid,
    String? refreshToken,
    String? deviceId,
  }) async {
    await StorageService.savePhone(phone);
    await StorageService.saveToken(token);
    await StorageService.saveUid(uid);
    if (refreshToken != null) {
      await StorageService.saveRefreshToken(refreshToken);
    }
    if (deviceId != null) {
      await StorageService.saveDeviceId(deviceId);
    }
  }

  Future<void> savePhone(String phone, {String? uid}) async {
    await StorageService.savePhone(phone);
    if (uid != null) {
      await StorageService.saveUid(uid);
    }
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    await StorageService.saveRefreshToken(refreshToken);
  }

  Future<void> saveDeviceId(String deviceId) async {
    await StorageService.saveDeviceId(deviceId);
  }

  Future<void> clearAuthState() async {
    await StorageService.clearAuth();
  }

  Future<void> clearSessionState({bool preserveDeviceId = true}) async {
    await StorageService.clearSessionData(preserveDeviceId: preserveDeviceId);
  }

  ProfileStateSnapshot loadProfileState() {
    return ProfileStateSnapshot(
      nickname: StorageService.getNickname() ?? '神秘人',
      avatar: StorageService.getAvatar() ?? '👤',
      status: StorageService.getStatus() ?? '想找人聊聊',
      signature: StorageService.getSignature() ?? _defaultSignature,
      transparentHomepage: StorageService.getTransparentHomepage(),
      portraitFullscreenBackground:
          StorageService.getPortraitFullscreenBackground(),
    );
  }

  Future<void> saveNickname(String nickname) async {
    await StorageService.saveNickname(nickname);
  }

  Future<void> saveAvatar(String avatar) async {
    await StorageService.saveAvatar(avatar);
  }

  Future<void> saveStatus(String status) async {
    await StorageService.saveStatus(status);
  }

  Future<void> saveSignature(String signature) async {
    await StorageService.saveSignature(signature);
  }

  Future<void> saveTransparentHomepage(bool enabled) async {
    await StorageService.saveTransparentHomepage(enabled);
  }

  Future<void> savePortraitFullscreenBackground(bool enabled) async {
    await StorageService.savePortraitFullscreenBackground(enabled);
  }

  MatchStateSnapshot loadMatchState() {
    return MatchStateSnapshot(
      matchCount: StorageService.getMatchCount(),
      lastResetDate: StorageService.getLastResetDate(),
    );
  }

  Future<void> saveMatchCount(int count) async {
    await StorageService.saveMatchCount(count);
  }

  Future<void> saveLastResetDate(DateTime date) async {
    await StorageService.saveLastResetDate(date);
  }

  SettingsStateSnapshot loadSettingsState() {
    return SettingsStateSnapshot(
      invisibleMode: StorageService.getInvisibleMode(),
      notificationEnabled: StorageService.getNotificationEnabled(),
      vibrationEnabled: StorageService.getVibrationEnabled(),
      dayThemeEnabled: StorageService.getDayThemeEnabled(),
    );
  }

  Future<void> saveInvisibleMode(bool enabled) async {
    await StorageService.saveInvisibleMode(enabled);
  }

  Future<void> saveNotificationEnabled(bool enabled) async {
    await StorageService.saveNotificationEnabled(enabled);
  }

  Future<void> saveVibrationEnabled(bool enabled) async {
    await StorageService.saveVibrationEnabled(enabled);
  }

  Future<void> saveDayThemeEnabled(bool enabled) async {
    await StorageService.saveDayThemeEnabled(enabled);
  }

  Map<String, dynamic>? loadChatState() {
    return StorageService.getChatState();
  }

  Future<void> saveChatState(Map<String, dynamic> snapshot) async {
    snapshot['version'] = 2;
    await StorageService.saveChatState(snapshot);
  }

  Future<void> clearChatState() async {
    await StorageService.clearChatState();
  }
}
