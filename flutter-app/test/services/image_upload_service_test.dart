import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/services/image_upload_service.dart';

import '../helpers/test_bootstrap.dart';

void main() {
  setUp(() async {
    await initTestAppStorage();
    ImageUploadService.debugResetOverrides();
  });

  tearDown(() {
    ImageUploadService.debugResetOverrides();
  });

  testWidgets('pickAvatar should prefer debug override when present', (
    tester,
  ) async {
    late BuildContext testContext;
    ImageUploadService.debugAvatarPickOverride = (_) async {
      await ImageUploadService.saveAvatarReference('avatar/debug_uploaded.png');
      return File(r'C:\mock\avatar_debug.jpg');
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            testContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final picked = await ImageUploadService.pickAvatar(testContext);

    expect(picked, isNotNull);
    expect(picked!.path, r'C:\mock\avatar_debug.jpg');
    expect(
      await ImageUploadService.getAvatarPath(),
      'avatar/debug_uploaded.png',
    );
  });

  testWidgets('pickBackground should prefer debug override when present', (
    tester,
  ) async {
    late BuildContext testContext;
    ImageUploadService.debugBackgroundPickOverride = (_) async {
      await ImageUploadService.saveBackgroundReference(
        'background/debug_uploaded.png',
      );
      return File(r'C:\mock\background_debug.jpg');
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            testContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final picked = await ImageUploadService.pickBackground(testContext);

    expect(picked, isNotNull);
    expect(picked!.path, r'C:\mock\background_debug.jpg');
    expect(
      await ImageUploadService.getBackgroundPath(),
      'background/debug_uploaded.png',
    );
  });

  test('debugResetOverrides should clear image pick overrides', () {
    ImageUploadService.debugAvatarPickOverride =
        (_) async => File(r'C:\mock\avatar.jpg');
    ImageUploadService.debugBackgroundPickOverride =
        (_) async => File(r'C:\mock\background.jpg');

    ImageUploadService.debugResetOverrides();

    expect(ImageUploadService.debugAvatarPickOverride, isNull);
    expect(ImageUploadService.debugBackgroundPickOverride, isNull);
  });
}
