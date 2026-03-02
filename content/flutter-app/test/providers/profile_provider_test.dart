import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/providers/profile_provider.dart';
import 'package:sunliao/services/profile_service.dart';

import '../helpers/test_bootstrap.dart';

void main() {
  setUp(() async {
    await initTestAppStorage();
  });

  test('blank signature should fallback to default signature', () async {
    final provider = ProfileProvider();
    await provider.updateSignature('   ');

    expect(provider.signature, ProfileService.defaultSignature);
  });

  test('transparent homepage should require portrait fullscreen enabled',
      () async {
    final provider = ProfileProvider();

    await provider.updateTransparentHomepage(true);
    expect(provider.transparentHomepage, isFalse);

    await provider.updatePortraitFullscreenBackground(true);
    await provider.updateTransparentHomepage(true);
    expect(provider.transparentHomepage, isTrue);

    await provider.updatePortraitFullscreenBackground(false);
    expect(provider.transparentHomepage, isFalse);
  });

  test('profile updates should persist', () async {
    final provider = ProfileProvider();

    await provider.updateNickname('Tester');
    await provider.updateStatus('Online');
    await provider.updateSignature('Hello world');

    final restored = ProfileProvider();
    expect(restored.nickname, 'Tester');
    expect(restored.status, 'Online');
    expect(restored.signature, 'Hello world');
  });
}
