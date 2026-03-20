import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/providers/auth_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/services/push_notification_service.dart';
import 'package:sunliao/services/storage_service.dart';
import 'package:sunliao/utils/permission_manager.dart';

import '../helpers/test_bootstrap.dart';

void main() {
  setUp(() async {
    await initTestAppStorage();
    await NotificationCenterProvider.instance.clearSession();
    PushNotificationService.instance.debugSetState(
      const PushRuntimeState(
        notificationsEnabled: true,
        permissionGranted: true,
        deviceToken: 'stub_push_test_device',
      ),
    );
  });

  tearDown(() async {
    await NotificationCenterProvider.instance.clearSession();
  });

  test('login should persist phone and uid', () async {
    final provider = AuthProvider();
    await Future<void>.delayed(Duration.zero);
    await provider.sendOtp('13800138000');

    final ok = await provider.login('13800138000', '123456');

    expect(ok, isTrue);
    expect(provider.isLoggedIn, isTrue);
    expect(provider.phone, '13800138000');
    expect(provider.uid, isNotNull);
    expect(provider.uid, startsWith('SN'));
    expect(provider.uid, endsWith('8000'));
    expect(StorageService.getUid(), provider.uid);
  });

  test('login should queue a lightweight main-entry hint for the next shell',
      () async {
    final provider = AuthProvider();
    await Future<void>.delayed(Duration.zero);
    await provider.sendOtp('13800138000');

    final ok = await provider.login('13800138000', '123456');

    expect(ok, isTrue);
    expect(provider.pendingEntryHintVersion, 1);
    expect(provider.consumePendingEntryHintSource(), 'login');
    expect(provider.consumePendingEntryHintSource(), isNull);
  });

  test('invalid code should fail login', () async {
    final provider = AuthProvider();
    await Future<void>.delayed(Duration.zero);

    final ok = await provider.login('13800138000', '000000');

    expect(ok, isFalse);
    expect(provider.isLoggedIn, isFalse);
    expect(StorageService.getPhone(), isNull);
  });

  test('auth state should restore on new provider instance', () async {
    final provider = AuthProvider();
    await Future<void>.delayed(Duration.zero);
    await provider.sendOtp('13900139000');
    await provider.login('13900139000', '123456');
    final firstUid = provider.uid;

    final restored = AuthProvider();
    await Future<void>.delayed(Duration.zero);

    expect(restored.isLoggedIn, isTrue);
    expect(restored.phone, '13900139000');
    expect(restored.uid, firstUid);
  });

  test('logout should clear auth storage and permission session cache',
      () async {
    final provider = AuthProvider();
    await Future<void>.delayed(Duration.zero);
    await provider.sendOtp('13700137000');
    await provider.login('13700137000', '123456');
    PermissionManager.setSessionLocationPermission(true);

    await provider.logout();

    expect(provider.isLoggedIn, isFalse);
    expect(provider.phone, isNull);
    expect(provider.uid, isNull);
    expect(StorageService.getPhone(), isNull);
    expect(StorageService.getToken(), isNull);
    expect(StorageService.getUid(), isNull);
    expect(PermissionManager.getSessionLocationPermission(), isNull);
  });

  test(
      'deleteAccount should clear session scoped storage and preserve device id',
      () async {
    await StorageService.saveDeviceId('device_delete_test');
    final provider = AuthProvider();
    await Future<void>.delayed(Duration.zero);
    await provider.sendOtp('13600136000');
    await provider.login('13600136000', '123456');
    await StorageService.saveNickname('待删除昵称');
    await StorageService.saveChatState(<String, dynamic>{
      'threads': <String, dynamic>{
        'thread_1': <String, dynamic>{'id': 'thread_1'}
      },
    });
    await StorageService.saveNotificationCenterState(
      '{"items":[{"id":"notice_1"}]}',
    );
    PermissionManager.setSessionLocationPermission(true);

    await provider.deleteAccount();

    expect(provider.isLoggedIn, isFalse);
    expect(provider.phone, isNull);
    expect(provider.uid, isNull);
    expect(StorageService.getPhone(), isNull);
    expect(StorageService.getToken(), isNull);
    expect(StorageService.getUid(), isNull);
    expect(StorageService.getNickname(), isNull);
    expect(StorageService.getChatState(), isNull);
    expect(StorageService.getNotificationCenterState(), isNull);
    expect(StorageService.getDeviceId(), 'device_delete_test');
    expect(PermissionManager.getSessionLocationPermission(), isNull);
  });

  test('login with a different account should clear previous session data',
      () async {
    await StorageService.saveDeviceId('device_switch_test');
    final provider = AuthProvider();
    await Future<void>.delayed(Duration.zero);
    await provider.sendOtp('13500135000');
    await provider.login('13500135000', '123456');
    final firstUid = provider.uid;
    await StorageService.saveNickname('第一个账号昵称');
    await StorageService.saveChatState(<String, dynamic>{
      'threads': <String, dynamic>{
        'thread_old': <String, dynamic>{'id': 'thread_old'}
      },
    });
    await StorageService.saveNotificationCenterState(
      '{"items":[{"id":"notice_old"}]}',
    );

    await provider.sendOtp('13400134000');
    final ok = await provider.login('13400134000', '123456');

    expect(ok, isTrue);
    expect(provider.isLoggedIn, isTrue);
    expect(provider.phone, '13400134000');
    expect(provider.uid, isNot(firstUid));
    expect(StorageService.getUid(), provider.uid);
    expect(StorageService.getNickname(), isNull);
    expect(StorageService.getChatState(), isNull);
    expect(StorageService.getNotificationCenterState(), isNull);
    expect(StorageService.getDeviceId(), 'device_switch_test');
  });

  test(
      'logout followed by next login should keep notification center and session payload reset',
      () async {
    final provider = AuthProvider();
    await Future<void>.delayed(Duration.zero);
    await provider.sendOtp('13300133000');
    await provider.login('13300133000', '123456');

    await StorageService.saveNickname('legacy_profile_a');
    await StorageService.saveChatState(<String, dynamic>{
      'threads': <String, dynamic>{
        'thread_legacy_a': <String, dynamic>{'id': 'thread_legacy_a'}
      },
    });
    await NotificationCenterProvider.instance.addSystemNotification(
      title: 'legacy_notice_a',
      body: 'legacy notification body',
      sourceKey: 'legacy-notice-a',
    );

    expect(NotificationCenterProvider.instance.unreadCount, 1);

    await provider.logout();

    expect(provider.isLoggedIn, isFalse);
    expect(StorageService.getNickname(), isNull);
    expect(StorageService.getChatState(), isNull);
    expect(StorageService.getNotificationCenterState(), isNull);
    expect(NotificationCenterProvider.instance.unreadCount, 0);

    await provider.sendOtp('13200132000');
    final ok = await provider.login('13200132000', '123456');

    expect(ok, isTrue);
    expect(provider.phone, '13200132000');
    expect(StorageService.getNickname(), isNull);
    expect(StorageService.getChatState(), isNull);
    expect(StorageService.getNotificationCenterState(), isNull);
    expect(NotificationCenterProvider.instance.unreadCount, 0);
  });
}
