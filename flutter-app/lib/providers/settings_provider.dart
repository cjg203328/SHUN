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
  bool _pendingNotificationPermissionRecovery = false;
  bool _notificationPermissionRecoveryInFlight = false;

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
    final didChangeLocalState = _applyState(_settingsService.loadState());
    final didChangePushRuntime = _syncPushRuntimeState();
    _notifyIfChanged(didChangeLocalState || didChangePushRuntime);

    if (!enableRemoteHydration) {
      return;
    }

    try {
      final state = await _settingsService.refreshState();
      final didChangeRemoteState = _applyState(state);
      final didChangeRemotePushRuntime = _syncPushRuntimeState();
      _notifyIfChanged(didChangeRemoteState || didChangeRemotePushRuntime);
    } catch (_) {}
  }

  Future<void> refreshFromRemote() async {
    final state = await _settingsService.refreshState();
    final didChangeState = _applyState(state);
    final didChangePushRuntime = _syncPushRuntimeState();
    _notifyIfChanged(didChangeState || didChangePushRuntime);
  }

  bool _applyState(SettingsStateSnapshot state) {
    final didChange = _invisibleMode != state.invisibleMode ||
        _notificationEnabled != state.notificationEnabled ||
        _vibrationEnabled != state.vibrationEnabled;
    _invisibleMode = state.invisibleMode;
    _notificationEnabled = state.notificationEnabled;
    _vibrationEnabled = state.vibrationEnabled;
    return didChange;
  }

  Future<void> updateInvisibleMode(bool enabled) async {
    final state = await _settingsService.saveInvisibleMode(enabled);
    _notifyIfChanged(_applyState(state));
  }

  Future<void> updateNotificationEnabled(bool enabled) async {
    final state = await _settingsService.saveNotificationEnabled(enabled);
    final didChangeState = _applyState(state);
    await _pushNotificationService.syncSettings(
      notificationsEnabled: state.notificationEnabled,
    );
    final didChangePushRuntime = _syncPushRuntimeState();
    if (didChangeState) {
      await AnalyticsService.instance.track(
        'notification_setting_updated',
        properties: {'enabled': state.notificationEnabled},
      );
    }
    _notifyIfChanged(didChangeState || didChangePushRuntime);
  }

  Future<void> updateVibrationEnabled(bool enabled) async {
    final state = await _settingsService.saveVibrationEnabled(enabled);
    _notifyIfChanged(_applyState(state));
  }

  Future<void> applyExperiencePreset(SettingsExperiencePreset preset) async {
    if (activeExperiencePreset == preset) {
      return;
    }

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
    final didChangeState = _applyState(state);
    var didChangePushRuntime = false;

    if (didChangeNotification) {
      await _pushNotificationService.syncSettings(
        notificationsEnabled: state.notificationEnabled,
      );
      didChangePushRuntime = _syncPushRuntimeState();
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
    _notifyIfChanged(didChangeState || didChangePushRuntime);
  }

  Future<bool> refreshPushRuntimeState() async {
    await _pushNotificationService.refreshPermissionState();
    final didChange = _syncPushRuntimeState();
    _notifyIfChanged(didChange);
    return didChange;
  }

  void markNotificationPermissionRecoveryPending() {
    _pendingNotificationPermissionRecovery = true;
  }

  Future<bool> refreshPushRuntimeStateAfterSystemSettingsReturn() async {
    if (!_pendingNotificationPermissionRecovery ||
        _notificationPermissionRecoveryInFlight) {
      return false;
    }
    _pendingNotificationPermissionRecovery = false;
    _notificationPermissionRecoveryInFlight = true;
    try {
      return await refreshPushRuntimeState();
    } finally {
      _notificationPermissionRecoveryInFlight = false;
    }
  }

  bool _syncPushRuntimeState() {
    final nextState = _pushNotificationService.state;
    final didChange = _pushRuntimeState.notificationsEnabled !=
            nextState.notificationsEnabled ||
        _pushRuntimeState.permissionGranted != nextState.permissionGranted ||
        _pushRuntimeState.deviceToken != nextState.deviceToken;
    _pushRuntimeState = nextState;
    return didChange;
  }

  void _notifyIfChanged(bool didChange) {
    if (didChange) {
      notifyListeners();
    }
  }
}
