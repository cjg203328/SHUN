import '../repositories/app_data_repository.dart';
import 'api_client.dart';
import 'storage_service.dart';

class SettingsService {
  SettingsService({AppDataRepository? repository, ApiClient? apiClient})
      : _repository = repository ?? AppDataRepository.instance,
        _apiClient = apiClient ?? ApiClient.instance;

  final AppDataRepository _repository;
  final ApiClient _apiClient;

  SettingsStateSnapshot loadState() {
    return _repository.loadSettingsState();
  }

  Future<SettingsStateSnapshot> refreshState() async {
    if (!_hasSession) return loadState();
    try {
      final settings = await _apiClient.get<Map<String, dynamic>>('/settings/me');
      await _persist(settings);
    } catch (_) {}
    return loadState();
  }

  Future<SettingsStateSnapshot> saveInvisibleMode(bool enabled) async {
    if (_hasSession) {
      try {
        final settings = await _apiClient.patch<Map<String, dynamic>>(
          '/settings/me',
          data: {'invisibleMode': enabled},
        );
        await _persist(settings);
        return loadState();
      } catch (_) {}
    }

    await _repository.saveInvisibleMode(enabled);
    return loadState();
  }

  Future<SettingsStateSnapshot> saveNotificationEnabled(bool enabled) async {
    if (_hasSession) {
      try {
        final settings = await _apiClient.patch<Map<String, dynamic>>(
          '/settings/me',
          data: {'notificationEnabled': enabled},
        );
        await _persist(settings);
        return loadState();
      } catch (_) {}
    }

    await _repository.saveNotificationEnabled(enabled);
    return loadState();
  }

  Future<SettingsStateSnapshot> saveVibrationEnabled(bool enabled) async {
    if (_hasSession) {
      try {
        final settings = await _apiClient.patch<Map<String, dynamic>>(
          '/settings/me',
          data: {'vibrationEnabled': enabled},
        );
        await _persist(settings);
        return loadState();
      } catch (_) {}
    }

    await _repository.saveVibrationEnabled(enabled);
    return loadState();
  }

  Future<SettingsStateSnapshot> saveDayThemeEnabled(bool enabled) async {
    if (_hasSession) {
      try {
        final settings = await _apiClient.patch<Map<String, dynamic>>(
          '/settings/me',
          data: {'dayThemeEnabled': false},
        );
        await _persist(settings);
        return loadState();
      } catch (_) {}
    }

    await _repository.saveDayThemeEnabled(false);
    return loadState();
  }

  bool get _hasSession {
    final token = StorageService.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> _persist(Map<String, dynamic> settings) async {
    await _repository.saveInvisibleMode(settings['invisibleMode'] == true);
    await _repository.saveNotificationEnabled(
      settings['notificationEnabled'] != false,
    );
    await _repository.saveVibrationEnabled(
      settings['vibrationEnabled'] != false,
    );
    await _repository.saveDayThemeEnabled(false);
    await _repository.saveTransparentHomepage(
      settings['transparentHomepage'] == true,
    );
    await _repository.savePortraitFullscreenBackground(
      settings['portraitFullscreenBackground'] == true,
    );
  }
}
