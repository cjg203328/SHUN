import '../repositories/app_data_repository.dart';
import 'api_client.dart';
import 'storage_service.dart';

class ProfileService {
  ProfileService({AppDataRepository? repository, ApiClient? apiClient})
      : _repository = repository ?? AppDataRepository.instance,
        _apiClient = apiClient ?? ApiClient.instance;

  final AppDataRepository _repository;
  final ApiClient _apiClient;

  static const String defaultSignature = '这个人很神秘，什么都没留下';

  ProfileStateSnapshot loadProfile() {
    return _repository.loadProfileState();
  }

  Future<ProfileStateSnapshot> refreshProfile() async {
    if (!_hasSession) return loadProfile();

    try {
      final user = await _apiClient.get<Map<String, dynamic>>('/users/me');
      final settings = await _apiClient.get<Map<String, dynamic>>('/settings/me');

      final nickname = user['nickname']?.toString().trim();
      final status = user['status']?.toString().trim();
      final signature = user['signature']?.toString().trim();

      await _repository.saveNickname(
        nickname == null || nickname.isEmpty ? '神秘人' : nickname,
      );
      await _repository.saveStatus(
        status == null || status.isEmpty ? '想找人聊聊' : status,
      );
      await _repository.saveSignature(
        signature == null || signature.isEmpty ? defaultSignature : signature,
      );
      await _repository.saveTransparentHomepage(
        settings['transparentHomepage'] == true,
      );
      await _repository.savePortraitFullscreenBackground(
        settings['portraitFullscreenBackground'] == true,
      );
    } catch (_) {}

    return loadProfile();
  }

  Future<ProfileStateSnapshot> saveNickname(String nickname) async {
    final normalized = nickname.trim().isEmpty ? '神秘人' : nickname.trim();
    if (_hasSession) {
      try {
        final user = await _apiClient.patch<Map<String, dynamic>>(
          '/users/me',
          data: {'nickname': normalized},
        );
        await _repository.saveNickname(
          user['nickname']?.toString().trim().isNotEmpty == true
              ? user['nickname'].toString().trim()
              : normalized,
        );
        return loadProfile();
      } catch (_) {}
    }

    await _repository.saveNickname(normalized);
    return loadProfile();
  }

  Future<void> saveAvatar(String avatar) async {
    await _repository.saveAvatar(avatar);
  }

  Future<ProfileStateSnapshot> saveStatus(String status) async {
    final normalized = status.trim().isEmpty ? '想找人聊聊' : status.trim();
    if (_hasSession) {
      try {
        final user = await _apiClient.patch<Map<String, dynamic>>(
          '/users/me',
          data: {'status': normalized},
        );
        await _repository.saveStatus(
          user['status']?.toString().trim().isNotEmpty == true
              ? user['status'].toString().trim()
              : normalized,
        );
        return loadProfile();
      } catch (_) {}
    }

    await _repository.saveStatus(normalized);
    return loadProfile();
  }

  Future<ProfileStateSnapshot> saveSignature(String signature) async {
    final normalized =
        signature.trim().isEmpty ? defaultSignature : signature.trim();

    if (_hasSession) {
      try {
        final user = await _apiClient.patch<Map<String, dynamic>>(
          '/users/me',
          data: {'signature': normalized},
        );
        await _repository.saveSignature(
          user['signature']?.toString().trim().isNotEmpty == true
              ? user['signature'].toString().trim()
              : normalized,
        );
        return loadProfile();
      } catch (_) {}
    }

    await _repository.saveSignature(normalized);
    return loadProfile();
  }

  Future<ProfileStateSnapshot> saveTransparentHomepage(bool enabled) async {
    if (_hasSession) {
      try {
        final settings = await _apiClient.patch<Map<String, dynamic>>(
          '/settings/me',
          data: {'transparentHomepage': enabled},
        );
        await _persistSettings(settings);
        return loadProfile();
      } catch (_) {}
    }

    await _repository.saveTransparentHomepage(enabled);
    return loadProfile();
  }

  Future<ProfileStateSnapshot> savePortraitFullscreenBackground(bool enabled) async {
    if (_hasSession) {
      try {
        final settings = await _apiClient.patch<Map<String, dynamic>>(
          '/settings/me',
          data: {'portraitFullscreenBackground': enabled},
        );
        await _persistSettings(settings);
        return loadProfile();
      } catch (_) {}
    }

    await _repository.savePortraitFullscreenBackground(enabled);
    return loadProfile();
  }

  bool get _hasSession {
    final token = StorageService.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> _persistSettings(Map<String, dynamic> settings) async {
    await _repository.saveTransparentHomepage(
      settings['transparentHomepage'] == true,
    );
    await _repository.savePortraitFullscreenBackground(
      settings['portraitFullscreenBackground'] == true,
    );
  }
}
