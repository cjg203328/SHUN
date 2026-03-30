import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/utils/media_reference_resolver.dart';

void main() {
  test('looksLikeMediaReference should distinguish text from media references',
      () {
    expect(looksLikeMediaReference('A'), isFalse);
    expect(looksLikeMediaReference('avatar/u_test/profile.jpg'), isTrue);
    expect(looksLikeMediaReference('file:///tmp/avatar.png'), isTrue);
  });

  test(
      'resolveRenderableMediaPath should keep remote media reference renderable',
      () {
    final resolved = resolveRenderableMediaPath('avatar/u_test/profile.jpg');

    expect(resolved, isNotNull);
    expect(resolved, contains('avatar/u_test/profile.jpg'));
    expect(isRemoteMediaReference(resolved!), isTrue);
  });

  test('resolveRenderableMediaPath should keep existing local media reference',
      () async {
    final localFile = File(
      '${Directory.systemTemp.path}\\media_ref_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await localFile.writeAsString('temp-local-media');
    addTearDown(() async {
      if (await localFile.exists()) {
        await localFile.delete();
      }
    });

    final resolved = resolveRenderableMediaPath(localFile.path);

    expect(resolved, localFile.path);
    expect(isRemoteMediaReference(resolved!), isFalse);
  });

  test('resolveRenderableMediaPath should reject plain text avatars', () {
    expect(resolveRenderableMediaPath('A'), isNull);
  });

  test('resolveRenderableMediaPath should reject missing local media reference',
      () {
    final missingPath =
        '${Directory.systemTemp.path}\\missing_media_${DateTime.now().microsecondsSinceEpoch}.png';

    expect(resolveRenderableMediaPath(missingPath), isNull);
  });
}
