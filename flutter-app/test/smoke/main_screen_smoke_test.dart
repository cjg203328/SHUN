import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/providers/auth_provider.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/match_provider.dart';
import 'package:sunliao/providers/profile_provider.dart';
import 'package:sunliao/providers/settings_provider.dart';
import 'package:sunliao/screens/main_screen.dart';

import '../helpers/test_bootstrap.dart';

void main() {
  setUp(() async {
    await initTestAppStorage();
  });

  Widget buildApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MatchProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => FriendProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const MaterialApp(
        home: MainScreen(),
      ),
    );
  }

  testWidgets('main screen should render core content on default size',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('瞬间'), findsOneWidget);
    expect(find.text('开始匹配'), findsOneWidget);
    expect(find.text('匹配'), findsOneWidget);
  });

  testWidgets('main screen should keep content visible on compact size',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('开始匹配'), findsOneWidget);
    await tester.tap(find.text('我的'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('背景显示模式'), findsOneWidget);
  });
}
