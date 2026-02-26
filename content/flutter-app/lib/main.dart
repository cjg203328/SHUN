import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'providers/match_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/friend_provider.dart';
import 'services/storage_service.dart';
import 'utils/permission_manager.dart';
import 'package:go_router/go_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地存储
  await StorageService.init();

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authProvider = AuthProvider();
    _router = AppRouter.createRouter(_authProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authProvider.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App 被系统销毁/任务被移除时清除会话级位置权限缓存
    if (state == AppLifecycleState.detached) {
      PermissionManager.clearSessionCache();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => MatchProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => FriendProvider()),
      ],
      child: MaterialApp.router(
        title: '瞬',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: _router,
      ),
    );
  }
}
