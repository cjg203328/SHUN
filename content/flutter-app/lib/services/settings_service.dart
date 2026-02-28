import '../repositories/app_data_repository.dart';

class SettingsService {
  SettingsService({AppDataRepository? repository})
      : _repository = repository ?? AppDataRepository.instance;

  final AppDataRepository _repository;

  SettingsStateSnapshot loadState() {
    return _repository.loadSettingsState();
  }

  Future<void> saveInvisibleMode(bool enabled) async {
    await _repository.saveInvisibleMode(enabled);
  }

  Future<void> saveNotificationEnabled(bool enabled) async {
    await _repository.saveNotificationEnabled(enabled);
  }

  Future<void> saveVibrationEnabled(bool enabled) async {
    await _repository.saveVibrationEnabled(enabled);
  }
}
