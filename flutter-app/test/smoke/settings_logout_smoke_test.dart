import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/config/routes.dart';
import 'package:sunliao/providers/auth_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/providers/settings_provider.dart';
import 'package:sunliao/repositories/app_data_repository.dart';
import 'package:sunliao/screens/login_screen.dart';
import 'package:sunliao/screens/settings_screen.dart';
import 'package:sunliao/services/image_upload_service.dart';
import 'package:sunliao/services/push_notification_service.dart';
import 'package:sunliao/services/storage_service.dart';

import '../helpers/test_bootstrap.dart';

Widget _buildHarness({
  required GoRouter router,
  required AuthProvider authProvider,
  required SettingsProvider settingsProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<NotificationCenterProvider>.value(
        value: NotificationCenterProvider.instance,
      ),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() async {
    await initTestAppStorage();
    ImageUploadService.debugResetOverrides();
    await NotificationCenterProvider.instance.clearSession();
    PushNotificationService.instance.debugSetState(
      const PushRuntimeState(
        notificationsEnabled: true,
        permissionGranted: true,
        deviceToken: 'stub_push_test_device',
      ),
    );
  });

  tearDown(() async {
    ImageUploadService.debugResetOverrides();
    PushNotificationService.instance.debugSetState(
      const PushRuntimeState(
        notificationsEnabled: true,
        permissionGranted: true,
        deviceToken: 'stub_push_test_device',
      ),
    );
    await NotificationCenterProvider.instance.clearSession();
  });

  Future<(GoRouter, AuthProvider, SettingsProvider)>
      buildLoggedInHarness() async {
    await AppDataRepository.instance.saveAuthState(
      phone: '13800138000',
      token: 'logout_test_token',
      uid: 'SNLOGT8000',
      refreshToken: 'logout_test_refresh',
      deviceId: 'logout_test_device',
    );

    final authProvider = AuthProvider();

    final router = AppRouter.createRouter(
      authProvider,
      initialLocation: '/settings',
    );
    final settingsProvider = SettingsProvider(enableRemoteHydration: false);

    addTearDown(authProvider.dispose);
    addTearDown(settingsProvider.dispose);

    return (router, authProvider, settingsProvider);
  }

  testWidgets(
    'settings logout should clear auth state and redirect back to login',
    (tester) async {
      final (router, authProvider, settingsProvider) =
          await buildLoggedInHarness();

      await tester.pumpWidget(
        _buildHarness(
          router: router,
          authProvider: authProvider,
          settingsProvider: settingsProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/settings',
      );
      expect(authProvider.isLoggedIn, isTrue);
      expect(StorageService.getToken(), isNotNull);

      final logoutButton = find.byKey(const Key('settings-logout-button'));
      await tester.scrollUntilVisible(
        logoutButton,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.byKey(const Key('settings-account-actions-card')),
          findsOneWidget);
      expect(find.byKey(const Key('settings-logout-card')), findsOneWidget);
      expect(find.byKey(const Key('settings-delete-account-card')),
          findsOneWidget);
      await tester.tap(logoutButton, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('app-dialog-confirm')), findsOneWidget);
      expect(
        find.textContaining('这只会退出当前设备上的登录状态。'),
        findsOneWidget,
      );
      expect(
        find.textContaining('你的账号资料、好友关系和聊天记录仍会保留'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('app-dialog-confirm')),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(authProvider.isLoggedIn, isFalse);
      expect(authProvider.phone, isNull);
      expect(authProvider.uid, isNull);
      expect(StorageService.getPhone(), isNull);
      expect(StorageService.getToken(), isNull);
      expect(StorageService.getUid(), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byKey(const Key('login-submit-button')), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/login',
      );

      router.go('/main?tab=0');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/login',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'settings delete account should clear session data and redirect back to login',
    (tester) async {
      final (router, authProvider, settingsProvider) =
          await buildLoggedInHarness();
      await StorageService.saveNickname('待清理昵称');
      await StorageService.saveChatState(<String, dynamic>{
        'threads': <String, dynamic>{
          'thread_1': <String, dynamic>{'id': 'thread_1'}
        },
      });
      await StorageService.saveNotificationCenterState(
          '{"items":[{"id":"notice_1"}]}');

      await tester.pumpWidget(
        _buildHarness(
          router: router,
          authProvider: authProvider,
          settingsProvider: settingsProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/settings',
      );
      expect(StorageService.getNickname(), '待清理昵称');
      expect(StorageService.getChatState(), isNotNull);
      expect(StorageService.getNotificationCenterState(), isNotNull);

      final deleteAccountButton = find.byKey(
        const Key('settings-delete-account-button'),
      );
      await tester.scrollUntilVisible(
        deleteAccountButton,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(deleteAccountButton, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('app-dialog-confirm')), findsOneWidget);
      expect(
        find.textContaining('注销后将清除账号资料与会话数据'),
        findsOneWidget,
      );
      expect(
        find.textContaining('如果只是暂时离开，建议使用“退出登录”'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('app-dialog-confirm')),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(authProvider.isLoggedIn, isFalse);
      expect(authProvider.phone, isNull);
      expect(authProvider.uid, isNull);
      expect(StorageService.getPhone(), isNull);
      expect(StorageService.getToken(), isNull);
      expect(StorageService.getUid(), isNull);
      expect(StorageService.getNickname(), isNull);
      expect(StorageService.getChatState(), isNull);
      expect(StorageService.getNotificationCenterState(), isNull);
      expect(StorageService.getDeviceId(), 'logout_test_device');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byKey(const Key('login-submit-button')), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/login',
      );

      router.go('/settings');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/login',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
