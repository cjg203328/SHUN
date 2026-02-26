import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/settings_screen.dart';

class AppRouter {
  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        // 启动态不重定向，避免闪烁；由 Splash 统一处理首跳转
        if (!authProvider.isInitialized) return null;

        final location = state.matchedLocation;
        final isInSplash = location == '/';
        final isInLogin = location == '/login';
        final needsAuth = location == '/main' ||
            location == '/settings' ||
            location.startsWith('/chat/');

        if (authProvider.isLoggedIn) {
          if (isInLogin) return '/main';
          return null;
        }

        if (needsAuth && !isInSplash) {
          return '/login';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/main',
          builder: (context, state) {
            final index =
                int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
            return MainScreen(initialIndex: index);
          },
        ),
        GoRoute(
          path: '/chat/:threadId',
          builder: (context, state) {
            final threadId = state.pathParameters['threadId']!;
            return ChatScreen(threadId: threadId);
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );
  }
}
