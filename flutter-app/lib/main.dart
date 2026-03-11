import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'providers/match_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/friend_provider.dart';
import 'providers/notification_center_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/settings_provider.dart';
import 'repositories/app_data_repository.dart';
import 'services/analytics_service.dart';
import 'services/push_notification_service.dart';
import 'services/storage_service.dart';
import 'utils/permission_manager.dart';
import 'package:go_router/go_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地存储
  await StorageService.init();
  await AppDataRepository.instance.bootstrap();
  await AnalyticsService.instance.init();
  await PushNotificationService.instance.initialize(
    notificationsEnabled: StorageService.getNotificationEnabled(),
  );

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AnalyticsService.instance.captureError(
      details.exception,
      details.stack ?? StackTrace.current,
      hint: 'FlutterError.onError',
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AnalyticsService.instance.captureError(
      error,
      stack,
      hint: 'PlatformDispatcher.onError',
    );
    return true;
  };

  runApp(const SunliaoApp());
}

class SunliaoApp extends StatefulWidget {
  const SunliaoApp({super.key});

  @override
  State<SunliaoApp> createState() => _SunliaoAppState();
}

class _SunliaoAppState extends State<SunliaoApp> with WidgetsBindingObserver {
  late final AuthProvider _authProvider;
  late final GoRouter _router;

  void _handleAuthChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authProvider = AuthProvider();
    _authProvider.addListener(_handleAuthChanged);
    _router = AppRouter.createRouter(_authProvider);
    AnalyticsService.instance.trackScreenView('main_app');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authProvider.removeListener(_handleAuthChanged);
    _authProvider.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AnalyticsService.instance.track(
      'app_lifecycle_changed',
      properties: {'state': state.name},
    );
    // App 被系统销毁/任务被移除时清除会话级位置权限缓存
    if (state == AppLifecycleState.detached) {
      PermissionManager.clearSessionCache();
    }
    if (state == AppLifecycleState.resumed) {
      PushNotificationService.instance.refreshPermissionState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionKey = '${_authProvider.isLoggedIn}:${_authProvider.uid ?? 'guest'}';

    return ChangeNotifierProvider<AuthProvider>.value(
      value: _authProvider,
      child: KeyedSubtree(
        key: ValueKey<String>(sessionKey),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationCenterProvider>.value(
              value: NotificationCenterProvider.instance,
            ),
            ChangeNotifierProvider(create: (_) => MatchProvider()),
            ChangeNotifierProvider(create: (_) => ChatProvider()),
            ChangeNotifierProvider(create: (_) => FriendProvider()),
            ChangeNotifierProvider(create: (_) => ProfileProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: Builder(
            builder: (context) {
              AppThemeConfig.setDayTheme(false);

              return MaterialApp.router(
                key: const ValueKey<String>('night-theme-only'),
                title: '瞬',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.themeData(isDay: false),
                routerConfig: _router,
              );
            },
          ),
        ),
      ),
    );
  }
}
