import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/providers/auth_provider.dart';
import 'package:sunliao/screens/splash_screen.dart';

import '../helpers/test_bootstrap.dart';

class _RouterTestAuthProvider extends AuthProvider {
  _RouterTestAuthProvider({
    required bool initialized,
    required bool loggedIn,
  })  : _initialized = initialized,
        _loggedIn = loggedIn,
        super();

  bool _initialized;
  bool _loggedIn;

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isLoggedIn => _loggedIn;

  void completeInitialization({required bool loggedIn}) {
    _initialized = true;
    _loggedIn = loggedIn;
    notifyListeners();
  }
}

Widget _buildHarness(_RouterTestAuthProvider authProvider) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(
          displayDuration: Duration(milliseconds: 10),
          animationDuration: Duration(milliseconds: 10),
          authPollInterval: Duration(milliseconds: 10),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('login-route')),
      ),
      GoRoute(
        path: '/main',
        builder: (_, __) => const Scaffold(body: Text('main-route')),
      ),
    ],
  );

  return ChangeNotifierProvider<AuthProvider>.value(
    value: authProvider,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() async {
    await initTestAppStorage();
  });

  testWidgets('splash screen should route unauthenticated user to login',
      (tester) async {
    final authProvider = _RouterTestAuthProvider(
      initialized: true,
      loggedIn: false,
    );
    addTearDown(authProvider.dispose);

    await tester.pumpWidget(_buildHarness(authProvider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpAndSettle();

    expect(find.text('login-route'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('splash screen should route authenticated user to main',
      (tester) async {
    final authProvider = _RouterTestAuthProvider(
      initialized: true,
      loggedIn: true,
    );
    addTearDown(authProvider.dispose);

    await tester.pumpWidget(_buildHarness(authProvider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpAndSettle();

    expect(find.text('main-route'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets(
      'splash screen should wait for auth initialization before routing',
      (tester) async {
    final authProvider = _RouterTestAuthProvider(
      initialized: false,
      loggedIn: false,
    );
    addTearDown(authProvider.dispose);

    await tester.pumpWidget(_buildHarness(authProvider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('login-route'), findsNothing);
    expect(find.text('main-route'), findsNothing);

    authProvider.completeInitialization(loggedIn: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpAndSettle();

    expect(find.text('login-route'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });
}
