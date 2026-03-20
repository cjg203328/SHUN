import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/providers/auth_provider.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/match_provider.dart';
import 'package:sunliao/providers/profile_provider.dart';
import 'package:sunliao/providers/settings_provider.dart';
import 'package:sunliao/screens/login_screen.dart';

import '../helpers/test_bootstrap.dart';

void _configureViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
}

Widget _buildHarness({
  required AuthProvider authProvider,
  required ChatProvider chatProvider,
  required FriendProvider friendProvider,
  required MatchProvider matchProvider,
  required ProfileProvider profileProvider,
  required SettingsProvider settingsProvider,
}) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/main',
        builder: (_, __) => const Scaffold(body: Text('main-route')),
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
      ChangeNotifierProvider<MatchProvider>.value(value: matchProvider),
      ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

({Widget app, GoRouter router}) _buildAuthOnlyHarness({
  required AuthProvider authProvider,
}) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/main',
        builder: (_, __) => const Scaffold(body: Text('main-route')),
      ),
    ],
  );

  return (
    app: ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: MaterialApp.router(routerConfig: router),
    ),
    router: router,
  );
}

Future<void> _pumpLoginHost(
  WidgetTester tester, {
  required AuthProvider authProvider,
  required ChatProvider chatProvider,
  required FriendProvider friendProvider,
  required MatchProvider matchProvider,
  required ProfileProvider profileProvider,
  required SettingsProvider settingsProvider,
}) async {
  await tester.pumpWidget(
    _buildHarness(
      authProvider: authProvider,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      matchProvider: matchProvider,
      profileProvider: profileProvider,
      settingsProvider: settingsProvider,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _disposeLoginHost(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1100));
}

void main() {
  setUp(() async {
    await initTestAppStorage();
  });

  Future<
      (
        AuthProvider,
        ChatProvider,
        FriendProvider,
        MatchProvider,
        ProfileProvider,
        SettingsProvider
      )> buildProviders() async {
    final authProvider = AuthProvider();
    final chatProvider = ChatProvider(
      enableRealtime: false,
      enableRemoteHydration: false,
    );
    final friendProvider = FriendProvider(enableRemoteHydration: false);
    final matchProvider = MatchProvider(allowMockFallback: false);
    final profileProvider = ProfileProvider();
    final settingsProvider = SettingsProvider(enableRemoteHydration: false);
    return (
      authProvider,
      chatProvider,
      friendProvider,
      matchProvider,
      profileProvider,
      settingsProvider
    );
  }

  testWidgets('login screen should show error when phone is invalid',
      (tester) async {
    final (
      authProvider,
      chatProvider,
      friendProvider,
      matchProvider,
      profileProvider,
      settingsProvider
    ) = await buildProviders();
    addTearDown(authProvider.dispose);
    addTearDown(chatProvider.dispose);
    addTearDown(friendProvider.dispose);
    addTearDown(matchProvider.dispose);
    addTearDown(profileProvider.dispose);
    addTearDown(settingsProvider.dispose);
    _configureViewport(tester);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpLoginHost(
      tester,
      authProvider: authProvider,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      matchProvider: matchProvider,
      profileProvider: profileProvider,
      settingsProvider: settingsProvider,
    );

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '1380013800',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('login-send-code-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('请输入11位手机号后继续'), findsWidgets);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
      'login screen should require otp request for current phone before enabling login',
      (tester) async {
    final (
      authProvider,
      chatProvider,
      friendProvider,
      matchProvider,
      profileProvider,
      settingsProvider
    ) = await buildProviders();
    addTearDown(authProvider.dispose);
    addTearDown(chatProvider.dispose);
    addTearDown(friendProvider.dispose);
    addTearDown(matchProvider.dispose);
    addTearDown(profileProvider.dispose);
    addTearDown(settingsProvider.dispose);
    _configureViewport(tester);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpLoginHost(
      tester,
      authProvider: authProvider,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      matchProvider: matchProvider,
      profileProvider: profileProvider,
      settingsProvider: settingsProvider,
    );

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '13800138000',
    );
    await tester.enterText(
      find.byKey(const Key('login-code-field')),
      '123456',
    );
    await tester.pump();

    final termsToggle = find.byKey(const Key('login-terms-toggle'));
    await tester.ensureVisible(termsToggle);
    await tester.tap(termsToggle, warnIfMissed: false);
    await tester.pump();

    final loginButtonFinder = find.byKey(const Key('login-submit-button'));
    expect(
      tester.widget<ElevatedButton>(loginButtonFinder).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('login-send-code-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('验证码已发送'), findsWidgets);
    expect(
      tester.widget<ElevatedButton>(loginButtonFinder).onPressed,
      isNotNull,
    );
    expect(find.byKey(const Key('login-otp-inline-hint')), findsOneWidget);
    expect(find.textContaining('138****8000'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '13800138001',
    );
    await tester.pump();

    expect(
      tester.widget<ElevatedButton>(loginButtonFinder).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const Key('login-send-code-button')),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.byKey(const Key('login-otp-inline-hint')), findsNothing);

    await _disposeLoginHost(tester);
  });

  testWidgets(
      'login screen should stay on login when verification code is invalid',
      (tester) async {
    final (
      authProvider,
      chatProvider,
      friendProvider,
      matchProvider,
      profileProvider,
      settingsProvider
    ) = await buildProviders();
    addTearDown(authProvider.dispose);
    addTearDown(chatProvider.dispose);
    addTearDown(friendProvider.dispose);
    addTearDown(matchProvider.dispose);
    addTearDown(profileProvider.dispose);
    addTearDown(settingsProvider.dispose);
    _configureViewport(tester);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpLoginHost(
      tester,
      authProvider: authProvider,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      matchProvider: matchProvider,
      profileProvider: profileProvider,
      settingsProvider: settingsProvider,
    );

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '13800138000',
    );
    await tester.tap(find.byKey(const Key('login-send-code-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    await tester.enterText(
      find.byKey(const Key('login-code-field')),
      '000000',
    );
    final termsToggle = find.byKey(const Key('login-terms-toggle'));
    await tester.ensureVisible(termsToggle);
    await tester.tap(termsToggle, warnIfMissed: false);
    await tester.pump();

    final submitButton = find.byKey(const Key('login-submit-button'));
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('验证码错误'), findsWidgets);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('main-route'), findsNothing);

    await _disposeLoginHost(tester);
  });

  testWidgets(
    'login screen should navigate to main without depending on session providers',
    (tester) async {
      final authProvider = AuthProvider();
      addTearDown(authProvider.dispose);
      _configureViewport(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authOnlyHarness = _buildAuthOnlyHarness(
        authProvider: authProvider,
      );

      await tester.pumpWidget(authOnlyHarness.app);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(
        find.byKey(const Key('login-phone-field')),
        '13800138000',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('login-send-code-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      await tester.enterText(
        find.byKey(const Key('login-code-field')),
        '123456',
      );
      await tester.pump();

      final termsToggle = find.byKey(const Key('login-terms-toggle'));
      await tester.ensureVisible(termsToggle);
      await tester.tap(termsToggle, warnIfMissed: false);
      await tester.pump();

      final submitButton = find.byKey(const Key('login-submit-button'));
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        authOnlyHarness.router.routerDelegate.currentConfiguration.uri
            .toString(),
        '/main?entry=login',
      );
      expect(find.text('main-route'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _disposeLoginHost(tester);
    },
  );
}
