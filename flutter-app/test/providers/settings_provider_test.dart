import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/providers/settings_provider.dart';
import 'package:sunliao/services/push_notification_service.dart';

import '../helpers/test_bootstrap.dart';

class _TestPushNotificationService implements PushNotificationService {
  _TestPushNotificationService({
    required PushRuntimeState initialState,
    this.refreshedState,
  }) : _state = initialState;

  PushRuntimeState _state;
  final PushRuntimeState? refreshedState;

  @override
  PushRuntimeState get state => _state;

  @override
  Future<void> clearSession() async {}

  @override
  Future<void> initialize({required bool notificationsEnabled}) async {}

  @override
  Future<void> refreshPermissionState() async {
    _state = refreshedState ?? _state;
  }

  @override
  Future<void> syncSettings({required bool notificationsEnabled}) async {
    _state = PushRuntimeState(
      notificationsEnabled: notificationsEnabled,
      permissionGranted: _state.permissionGranted,
      deviceToken: notificationsEnabled ? _state.deviceToken : null,
      lastSyncedAt: _state.lastSyncedAt,
    );
  }

  @override
  void debugSetState(PushRuntimeState state) {
    _state = state;
  }
}

void main() {
  setUp(() async {
    await initTestAppStorage();
  });

  test('should use default settings on first launch', () {
    final provider = SettingsProvider();

    expect(provider.invisibleMode, isFalse);
    expect(provider.notificationEnabled, isTrue);
    expect(provider.vibrationEnabled, isTrue);
  });

  test('should persist updates across provider instances', () async {
    final provider = SettingsProvider();

    await provider.updateInvisibleMode(true);
    await provider.updateNotificationEnabled(false);
    await provider.updateVibrationEnabled(false);

    final restored = SettingsProvider();
    expect(restored.invisibleMode, isTrue);
    expect(restored.notificationEnabled, isFalse);
    expect(restored.vibrationEnabled, isFalse);
  });

  test('should apply bundled experience preset and expose active preset',
      () async {
    final provider = SettingsProvider(enableRemoteHydration: false);

    await provider.applyExperiencePreset(SettingsExperiencePreset.quietObserve);

    expect(provider.invisibleMode, isTrue);
    expect(provider.notificationEnabled, isFalse);
    expect(provider.vibrationEnabled, isFalse);
    expect(
      provider.activeExperiencePreset,
      SettingsExperiencePreset.quietObserve,
    );

    final restored = SettingsProvider(enableRemoteHydration: false);
    expect(
      restored.activeExperiencePreset,
      SettingsExperiencePreset.quietObserve,
    );
  });

  test(
    'should not notify listeners when notification permission return does not change runtime state',
    () async {
      final provider = SettingsProvider(
        pushNotificationService: _TestPushNotificationService(
          initialState: const PushRuntimeState(
            notificationsEnabled: true,
            permissionGranted: false,
          ),
        ),
        enableRemoteHydration: false,
      );
      var notifications = 0;
      provider.addListener(() {
        notifications += 1;
      });

      provider.markNotificationPermissionRecoveryPending();
      final didChange =
          await provider.refreshPushRuntimeStateAfterSystemSettingsReturn();

      expect(didChange, isFalse);
      expect(notifications, 0);
      expect(provider.pushRuntimeState.deviceToken, isNull);
    },
  );

  test(
    'should notify listeners when notification permission return updates runtime state',
    () async {
      final provider = SettingsProvider(
        pushNotificationService: _TestPushNotificationService(
          initialState: const PushRuntimeState(
            notificationsEnabled: true,
            permissionGranted: false,
          ),
          refreshedState: const PushRuntimeState(
            notificationsEnabled: true,
            permissionGranted: true,
            deviceToken: 'stub_ready_device_token',
          ),
        ),
        enableRemoteHydration: false,
      );
      var notifications = 0;
      provider.addListener(() {
        notifications += 1;
      });

      provider.markNotificationPermissionRecoveryPending();
      final didChange =
          await provider.refreshPushRuntimeStateAfterSystemSettingsReturn();

      expect(didChange, isTrue);
      expect(notifications, 1);
      expect(provider.pushRuntimeState.deviceToken, 'stub_ready_device_token');
    },
  );

  test('should skip reapplying current experience preset', () async {
    final provider = SettingsProvider(enableRemoteHydration: false);
    var notifications = 0;
    provider.addListener(() {
      notifications += 1;
    });

    await provider.applyExperiencePreset(SettingsExperiencePreset.responsive);

    expect(
        provider.activeExperiencePreset, SettingsExperiencePreset.responsive);
    expect(notifications, 0);
  });
}
