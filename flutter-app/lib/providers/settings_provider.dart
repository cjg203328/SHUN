import 'package:flutter/material.dart';
import '../repositories/app_data_repository.dart';
import '../services/analytics_service.dart';
import '../services/push_notification_service.dart';
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

  Future<void> _load() async {
    _applyState(_settingsService.loadState());
    notifyListeners();

    try {
      final state = await _settingsService.refreshState();
      _applyState(state);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshFromRemote() async {
    final state = await _settingsService.refreshState();
    _applyState(state);
    notifyListeners();
  }

  void _applyState(SettingsStateSnapshot state) {
    _invisibleMode = state.invisibleMode;
    _notificationEnabled = state.notificationEnabled;
    _vibrationEnabled = state.vibrationEnabled;
  }

  Future<void> updateInvisibleMode(bool enabled) async {
    final state = await _settingsService.saveInvisibleMode(enabled);
    _applyState(state);
    notifyListeners();
  }

  Future<void> updateNotificationEnabled(bool enabled) async {
    final state = await _settingsService.saveNotificationEnabled(enabled);
    _applyState(state);
    await PushNotificationService.instance.syncSettings(
      notificationsEnabled: state.notificationEnabled,
    );
    await AnalyticsService.instance.track(
      'notification_setting_updated',
      properties: {'enabled': state.notificationEnabled},
    );
    notifyListeners();
  }

  Future<void> updateVibrationEnabled(bool enabled) async {
    final state = await _settingsService.saveVibrationEnabled(enabled);
    _applyState(state);
    notifyListeners();
  }
}
