import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/utils/media_preview_state_resolver.dart';

void main() {
  test('resolveMediaPreviewState should keep remote media references', () {
    final state = resolveMediaPreviewState('avatar/u_test/profile.jpg');

    expect(state.hasMedia, isTrue);
    expect(state.isRemote, isTrue);
    expect(state.mediaPath, contains('avatar/u_test/profile.jpg'));
  });

  test('resolveMediaPreviewState should reject plain text placeholders', () {
    final state = resolveMediaPreviewState('A');

    expect(state.hasMedia, isFalse);
    expect(state.mediaPath, isNull);
  });

  test('resolveMediaPreviewState should reject missing local files', () {
    final state = resolveMediaPreviewState(
      '${Directory.systemTemp.path}\\missing_preview_${DateTime.now().microsecondsSinceEpoch}.png',
    );

    expect(state.hasMedia, isFalse);
    expect(state.mediaPath, isNull);
  });

  test('resolveMediaPreviewState should keep existing local files', () async {
    final localFile = File(
      '${Directory.systemTemp.path}\\preview_state_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await localFile.writeAsString('preview-state');
    addTearDown(() async {
      if (await localFile.exists()) {
        await localFile.delete();
      }
    });

    final state = resolveMediaPreviewState(localFile.path);

    expect(state.hasMedia, isTrue);
    expect(state.isRemote, isFalse);
    expect(state.mediaPath, localFile.path);
  });
}
