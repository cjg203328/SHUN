import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/content/app_legal_content.dart';
import 'package:sunliao/providers/auth_provider.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/providers/settings_provider.dart';
import 'package:sunliao/screens/about_screen.dart';
import 'package:sunliao/screens/legal_document_screen.dart';
import 'package:sunliao/screens/settings_screen.dart';
import 'package:sunliao/services/image_upload_service.dart';
import 'package:sunliao/services/push_notification_service.dart';
import 'package:sunliao/services/storage_service.dart';

import '../helpers/test_bootstrap.dart';

/// 构建带 GoRouter 的完整设置页测试 harness。
/// 路由表只包含 /settings、/about、/legal/:docType，
/// 足够覆盖「关于与协议」三个跳转。
Widget _buildHarness({
  required AuthProvider authProvider,
  required ChatProvider chatProvider,
  required FriendProvider friendProvider,
  required SettingsProvider settingsProvider,
}) {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (_, __) => const AboutScreen(),
      ),
      GoRoute(
        path: '/legal/:docType',
        builder: (_, state) {
          final docType = AppLegalContent.fromRouteParam(
            state.pathParameters['docType'] ?? '',
          );
          return LegalDocumentScreen(
            documentType: docType ?? LegalDocumentType.userAgreement,
          );
        },
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ChangeNotifierProvider<NotificationCenterProvider>.value(
        value: NotificationCenterProvider.instance,
      ),
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData' ||
          call.method == 'Clipboard.getData') {
        return null;
      }
      return null;
    });
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<(AuthProvider, ChatProvider, FriendProvider, SettingsProvider)>
      buildProviders(WidgetTester tester) async {
    await StorageService.saveLocalPassword('123456');
    final auth = AuthProvider();
    await auth.updatePhone('13800138000');
    final chat = ChatProvider(
      enableRealtime: false,
      enableRemoteHydration: false,
    );
    final friend = FriendProvider(enableRemoteHydration: false);
    final settings = SettingsProvider(enableRemoteHydration: false);
    await settings.applyExperiencePreset(SettingsExperiencePreset.responsive);
    addTearDown(auth.dispose);
    addTearDown(chat.dispose);
    addTearDown(friend.dispose);
    addTearDown(settings.dispose);
    return (auth, chat, friend, settings);
  }

  testWidgets(
    'settings 关于瞬入口点击后跳转到 AboutScreen',
    (tester) async {
      final (auth, chat, friend, settings) = await buildProviders(tester);

      await tester.pumpWidget(
        _buildHarness(
          authProvider: auth,
          chatProvider: chat,
          friendProvider: friend,
          settingsProvider: settings,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 滚动到「关于与协议」区域
      await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings-about-item')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('about-screen-list')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'settings 隐私政策入口点击后跳转到 LegalDocumentScreen',
    (tester) async {
      final (auth, chat, friend, settings) = await buildProviders(tester);

      await tester.pumpWidget(
        _buildHarness(
          authProvider: auth,
          chatProvider: chat,
          friendProvider: friend,
          settingsProvider: settings,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings-privacy-policy-item')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('legal-document-scroll-view')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('legal-document-summary-card')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'settings 用户协议入口点击后跳转到 LegalDocumentScreen',
    (tester) async {
      final (auth, chat, friend, settings) = await buildProviders(tester);

      await tester.pumpWidget(
        _buildHarness(
          authProvider: auth,
          chatProvider: chat,
          friendProvider: friend,
          settingsProvider: settings,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('settings-user-agreement-item')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('legal-document-scroll-view')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('legal-document-summary-card')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
