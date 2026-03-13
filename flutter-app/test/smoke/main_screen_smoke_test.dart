import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/providers/auth_provider.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/match_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/providers/profile_provider.dart';
import 'package:sunliao/providers/settings_provider.dart';
import 'package:sunliao/screens/main_screen.dart';

import '../helpers/test_bootstrap.dart';

void main() {
  setUp(() async {
    await initTestAppStorage();
  });

  Widget buildApp({String initialLocation = '/main'}) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/main',
          builder: (context, state) {
            final index =
                int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
            return MainScreen(initialIndex: index);
          },
        ),
      ],
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider<NotificationCenterProvider>.value(
          value: NotificationCenterProvider.instance,
        ),
        ChangeNotifierProvider(create: (_) => MatchProvider()),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(
            enableRealtime: false,
            enableRemoteHydration: false,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => FriendProvider(enableRemoteHydration: false),
        ),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(enableRemoteHydration: false),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('main screen should render core content on default size',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(IndexedStack), findsOneWidget);
    expect(find.byKey(const Key('match-guide-card')), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  testWidgets(
      'main screen should keep profile quick actions visible on compact size',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildApp(initialLocation: '/main?tab=3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('profile-quick-actions-card')), findsOneWidget);
    expect(find.byKey(const Key('profile-readiness-chip')), findsOneWidget);
    expect(
        find.byKey(const Key('profile-completion-checklist')), findsOneWidget);
    expect(find.byKey(const Key('profile-check-background')), findsOneWidget);
    expect(find.byKey(const Key('profile-check-signature')), findsOneWidget);
    expect(find.byKey(const Key('profile-check-status')), findsOneWidget);
    expect(find.byKey(const Key('profile-quick-signature')), findsOneWidget);
    expect(
      find.byKey(const Key('profile-quick-background-mode')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('profile-quick-settings')), findsOneWidget);
  });

  testWidgets('profile tab should open premium-style editor sheets',
      (tester) async {
    await tester.pumpWidget(buildApp(initialLocation: '/main?tab=3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('profile-signature-trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('profile-signature-sheet')), findsOneWidget);
    expect(find.byKey(const Key('profile-editor-input')), findsOneWidget);
    expect(find.byKey(const Key('profile-editor-save')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-editor-cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('profile-signature-sheet')), findsNothing);
  });
}
