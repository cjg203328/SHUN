import 'package:flutter/material.dart';
import '../repositories/app_data_repository.dart';
import '../services/analytics_service.dart';
import '../services/push_notification_service.dart';
import '../services/settings_service.dart';

enum SettingsExperiencePreset {
  responsive,
  balanced,
  quietObserve,
}

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    SettingsService? settingsService,
    PushNotificationService? pushNotificationService,
    bool enableRemoteHydration = true,
  })  : _settingsService = settingsService ?? SettingsService(),
        _pushNotificationService =
            pushNotificationService ?? PushNotificationService.instance,
        _pushRuntimeState =
            (pushNotificationService ?? PushNotificationService.instance)
                .state {
    _load(enableRemoteHydration: enableRemoteHydration);
  }

  final SettingsService _settingsService;
  final PushNotificationService _pushNotificationService;

  bool _invisibleMode = false;
  bool _notificationEnabled = true;
  bool _vibrationEnabled = true;
  PushRuntimeState _pushRuntimeState;

  bool get invisibleMode => _invisibleMode;
  bool get notificationEnabled => _notificationEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  PushRuntimeState get pushRuntimeState => _pushRuntimeState;

  SettingsExperiencePreset? get activeExperiencePreset {
    if (_notificationEnabled && _vibrationEnabled && !_invisibleMode) {
      return SettingsExperiencePreset.responsive;
    }

    if (_notificationEnabled && !_vibrationEnabled && !_invisibleMode) {
      return SettingsExperiencePreset.balanced;
    }

    if (!_notificationEnabled && !_vibrationEnabled && _invisibleMode) {
      return SettingsExperiencePreset.quietObserve;
    }

    return null;
  }

  Future<void> _load({required bool enableRemoteHydration}) async {
    _applyState(_settingsService.loadState());
    _syncPushRuntimeState();
    notifyListeners();

    if (!enableRemoteHydration) {
      return;
    }

    try {
      final state = await _settingsService.refreshState();
      _applyState(state);
      _syncPushRuntimeState();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshFromRemote() async {
    final state = await _settingsService.refreshState();
    _applyState(state);
    _syncPushRuntimeState();
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
    await _pushNotificationService.syncSettings(
      notificationsEnabled: state.notificationEnabled,
    );
    _syncPushRuntimeState();
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

  Future<void> applyExperiencePreset(SettingsExperiencePreset preset) async {
    final nextState = switch (preset) {
      SettingsExperiencePreset.responsive => (
          invisibleMode: false,
          notificationEnabled: true,
          vibrationEnabled: true,
        ),
      SettingsExperiencePreset.balanced => (
          invisibleMode: false,
          notificationEnabled: true,
          vibrationEnabled: false,
        ),
      SettingsExperiencePreset.quietObserve => (
          invisibleMode: true,
          notificationEnabled: false,
          vibrationEnabled: false,
        ),
    };

    final didChangeNotification =
        _notificationEnabled != nextState.notificationEnabled;
    final state = await _settingsService.saveState(
      invisibleMode: nextState.invisibleMode,
      notificationEnabled: nextState.notificationEnabled,
      vibrationEnabled: nextState.vibrationEnabled,
    );
    _applyState(state);

    if (didChangeNotification) {
      await _pushNotificationService.syncSettings(
        notificationsEnabled: state.notificationEnabled,
      );
      _syncPushRuntimeState();
      await AnalyticsService.instance.track(
        'notification_setting_updated',
        properties: {'enabled': state.notificationEnabled},
      );
    }

    await AnalyticsService.instance.track(
      'settings_experience_preset_applied',
      properties: {
        'preset': preset.name,
        'notificationEnabled': state.notificationEnabled,
        'vibrationEnabled': state.vibrationEnabled,
        'invisibleMode': state.invisibleMode,
      },
    );
    notifyListeners();
  }

  Future<void> refreshPushRuntimeState() async {
    await _pushNotificationService.refreshPermissionState();
    _syncPushRuntimeState();
    notifyListeners();
  }

  void _syncPushRuntimeState() {
    _pushRuntimeState = _pushNotificationService.state;
  }
}
