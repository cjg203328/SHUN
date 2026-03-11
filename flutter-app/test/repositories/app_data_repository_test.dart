import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunliao/repositories/app_data_repository.dart';
import 'package:sunliao/services/storage_service.dart';

void main() {
  test('bootstrap should migrate legacy signature and transparent homepage',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_data_schema_version': 1,
      'signature': '',
      'transparent_homepage': true,
      'portrait_fullscreen_background': false,
      'chat_state_v1': jsonEncode(<String, dynamic>{
        'threads': <String, dynamic>{},
        'messages': <String, dynamic>{},
      }),
    });
    await StorageService.init();

    await AppDataRepository.instance.bootstrap();

    expect(StorageService.getDataSchemaVersion(), 3);
    expect(StorageService.getSignature(), '这个人很神秘，什么都没留下');
    expect(StorageService.getTransparentHomepage(), isFalse);
    expect(StorageService.getChatState()!['version'], 1);
  });

  test('saveAuthState and clearAuthState should round-trip', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();

    await AppDataRepository.instance.saveAuthState(
      phone: '13600136000',
      token: 'token-x',
      uid: 'SNTEST1360',
    );
    final state = AppDataRepository.instance.loadAuthState();
    expect(state.phone, '13600136000');
    expect(state.token, 'token-x');
    expect(state.uid, 'SNTEST1360');

    await AppDataRepository.instance.clearAuthState();
    final cleared = AppDataRepository.instance.loadAuthState();
    expect(cleared.phone, isNull);
    expect(cleared.token, isNull);
    expect(cleared.uid, isNull);
  });

  test('saveDayThemeEnabled should persist in settings snapshot', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();

    await AppDataRepository.instance.saveDayThemeEnabled(true);
    final state = AppDataRepository.instance.loadSettingsState();
    expect(state.dayThemeEnabled, isTrue);
  });
}
