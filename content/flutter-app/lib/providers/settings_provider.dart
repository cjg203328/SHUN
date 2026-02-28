import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({SettingsService? settingsService})
      : _settingsService = settingsService ?? SettingsService() {
    _load();
  }

  final SettingsService _settingsService;

  bool _invisibleMode = false;
  bool _notificationEnabled = true;
  bool _vibrationEnabled = true;

  bool get invisibleMode => _invisibleMode;
  bool get notificationEnabled => _notificationEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  void _load() {
    final state = _settingsService.loadState();
    _invisibleMode = state.invisibleMode;
    _notificationEnabled = state.notificationEnabled;
    _vibrationEnabled = state.vibrationEnabled;
    notifyListeners();
  }

  Future<void> updateInvisibleMode(bool enabled) async {
    _invisibleMode = enabled;
    await _settingsService.saveInvisibleMode(enabled);
    notifyListeners();
  }

  Future<void> updateNotificationEnabled(bool enabled) async {
    _notificationEnabled = enabled;
    await _settingsService.saveNotificationEnabled(enabled);
    notifyListeners();
  }

  Future<void> updateVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    await _settingsService.saveVibrationEnabled(enabled);
    notifyListeners();
  }
}
