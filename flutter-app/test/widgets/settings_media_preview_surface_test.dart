import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/widgets/settings_media_preview_surface.dart';

Widget _buildHost({
  required String? mediaPath,
  required IconData fallbackIcon,
  bool isCircular = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SettingsMediaPreviewSurface(
          mediaPath: mediaPath,
          width: 48,
          height: 48,
          iconSize: 18,
          fallbackIcon: fallbackIcon,
          isCircular: isCircular,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'settings media preview surface should fallback for missing local media',
      (tester) async {
    final missingFile =
        '${Directory.systemTemp.path}\\settings_preview_missing_${DateTime.now().microsecondsSinceEpoch}.png';

    await tester.pumpWidget(
      _buildHost(
        mediaPath: missingFile,
        fallbackIcon: Icons.person_rounded,
        isCircular: true,
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'settings media preview surface should build image for remote media',
      (tester) async {
    await tester.pumpWidget(
      _buildHost(
        mediaPath: 'avatar/u_widget_remote/profile.jpg',
        fallbackIcon: Icons.wallpaper_rounded,
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
  });
}
