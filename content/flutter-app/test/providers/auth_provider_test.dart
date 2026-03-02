import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/providers/auth_provider.dart';
import 'package:sunliao/services/storage_service.dart';
import 'package:sunliao/utils/permission_manager.dart';

import '../helpers/test_bootstrap.dart';

void main() {
  setUp(() async {
    await initTestAppStorage();
  });

  test('login should persist phone and uid', () async {
    final provider = AuthProvider();
    await Future<void>.delayed(Duration.zero);

    final ok = await provider.login('13800138000', '123456');

    expect(ok, isTrue);
    expect(provider.isLoggedIn, isTrue);
    expect(provider.phone, '13800138000');
    expect(provider.uid, isNotNull);
    expect(provider.uid, startsWith('SN'));
    expect(provider.uid, endsWith('8000'));
    expect(StorageService.getUid(), provider.uid);
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
}
