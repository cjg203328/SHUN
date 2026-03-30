import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/widgets/app_user_avatar.dart';

Widget _buildHost({required String? avatar}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 56,
          height: 56,
          child: AppUserAvatar(
            avatar: avatar,
            textStyle: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('app user avatar should render plain text fallback',
      (tester) async {
    await tester.pumpWidget(_buildHost(avatar: 'A'));

    expect(
      find.byKey(const ValueKey<String>('app-user-avatar-text-fallback')),
      findsOneWidget,
    );
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets(
      'app user avatar should keep placeholder visible for remote media',
      (tester) async {
    await tester.pumpWidget(
      _buildHost(avatar: 'avatar/u_widget_remote/profile.jpg'),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('app-user-avatar-loading')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('app-user-avatar-loading-indicator')),
      findsOneWidget,
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets(
      'app user avatar should fallback when local media path is invalid',
      (tester) async {
    final missingFile =
        '${Directory.systemTemp.path}\\missing_avatar_${DateTime.now().microsecondsSinceEpoch}.png';

    await tester.pumpWidget(_buildHost(avatar: missingFile));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('app-user-avatar-error')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('app-user-avatar-error-indicator')),
      findsOneWidget,
    );
    expect(find.text('\u{1F464}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
