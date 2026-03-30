import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/auth_provider.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/providers/settings_provider.dart';
import 'package:sunliao/screens/chat_screen.dart';
import 'package:sunliao/screens/notification_center_screen.dart';
import 'package:sunliao/screens/settings_screen.dart';
import 'package:sunliao/services/push_notification_service.dart';

import '../helpers/test_bootstrap.dart';

User _buildUser(String id) {
  return User(
    id: id,
    uid: 'SN$id',
    nickname: 'User-$id',
    avatar: '🙂',
    distance: '2km',
    status: 'available',
    isOnline: true,
  );
}

ChatThread _buildThread(String id) {
  final now = DateTime.now();
  return ChatThread(
    id: id,
    otherUser: _buildUser(id),
    createdAt: now.subtract(const Duration(minutes: 10)),
    expiresAt: now.add(const Duration(hours: 24)),
    intimacyPoints: 60,
  );
}

class _TestPushNotificationService implements PushNotificationService {
  _TestPushNotificationService({
    required PushRuntimeState initialState,
    this.refreshedState,
  }) : _state = initialState;

  PushRuntimeState _state;
  final PushRuntimeState? refreshedState;

  @override
  PushRuntimeState get state => _state;

  @override
  Future<void> clearSession() async {}

  @override
  Future<void> initialize({required bool notificationsEnabled}) async {}

  @override
  Future<void> refreshPermissionState() async {
    _state = refreshedState ?? _state;
  }

  @override
  Future<void> syncSettings({required bool notificationsEnabled}) async {
    _state = PushRuntimeState(
      notificationsEnabled: notificationsEnabled,
      permissionGranted: _state.permissionGranted,
      deviceToken: notificationsEnabled ? _state.deviceToken : null,
      lastSyncedAt: _state.lastSyncedAt,
    );
  }

  @override
  void debugSetState(PushRuntimeState state) {
    _state = state;
  }
}

GoRouter _buildRouter({
  required ChatProvider chatProvider,
  required FriendProvider friendProvider,
  required SettingsProvider settingsProvider,
  required String threadId,
  AuthProvider? authProvider,
}) {
  return GoRouter(
    initialLocation: '/chat/$threadId',
    routes: [
      GoRoute(
        path: '/chat/:threadId',
        builder: (context, state) => MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationCenterProvider>.value(
              value: NotificationCenterProvider.instance,
            ),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: ChatScreen(threadId: state.pathParameters['threadId']!),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) {
          if (authProvider == null) {
            return const Scaffold(body: Center(child: Text('settings-route')));
          }
          return MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
              ChangeNotifierProvider<FriendProvider>.value(
                value: friendProvider,
              ),
              ChangeNotifierProvider<NotificationCenterProvider>.value(
                value: NotificationCenterProvider.instance,
              ),
              ChangeNotifierProvider<SettingsProvider>.value(
                value: settingsProvider,
              ),
            ],
            child: const SettingsScreen(),
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationCenterProvider>.value(
              value: NotificationCenterProvider.instance,
            ),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: NotificationCenterScreen(
            initialFilter: NotificationCenterSourceFilter.fromQuery(
              state.uri.queryParameters['source'],
            ),
          ),
        ),
      ),
    ],
  );
}

void main() {
  setUp(() async {
    await initTestAppStorage();
    await PushNotificationService.instance.clearSession();
    await NotificationCenterProvider.instance.clearSession();
  });

  tearDown(() async {
    await PushNotificationService.instance.clearSession();
    await NotificationCenterProvider.instance.clearSession();
  });

  testWidgets(
    'chat screen should show permission banner and open settings page',
    (tester) async {
      PushNotificationService.instance.debugSetState(
        const PushRuntimeState(
          notificationsEnabled: true,
          permissionGranted: false,
        ),
      );

      final thread = _buildThread('u_chat_permission_settings');
      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(
        pushNotificationService: PushNotificationService.instance,
        enableRemoteHydration: false,
      );
      final router = _buildRouter(
        chatProvider: chatProvider,
        friendProvider: friendProvider,
        settingsProvider: settingsProvider,
        threadId: thread.id,
      );
      chatProvider.addThread(thread);

      addTearDown(chatProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('chat-notification-permission-banner')),
        findsOneWidget,
      );
      expect(find.text('系统通知未打开'), findsOneWidget);

      final settingsAction = find.byKey(
        const Key('chat-notification-permission-action'),
      );
      await tester.ensureVisible(settingsAction);
      await tester.tap(settingsAction, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('settings-route'), findsOneWidget);
    },
  );

  testWidgets(
    'chat screen should open notification center from permission banner',
    (tester) async {
      PushNotificationService.instance.debugSetState(
        const PushRuntimeState(
          notificationsEnabled: true,
          permissionGranted: false,
        ),
      );

      final thread = _buildThread('u_chat_permission_center');
      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(
        pushNotificationService: PushNotificationService.instance,
        enableRemoteHydration: false,
      );
      final router = _buildRouter(
        chatProvider: chatProvider,
        friendProvider: friendProvider,
        settingsProvider: settingsProvider,
        threadId: thread.id,
      );
      chatProvider.addThread(thread);

      addTearDown(chatProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('chat-notification-permission-banner')),
        findsOneWidget,
      );

      final notificationCenterAction = find.byKey(
        const Key('chat-notification-center-action'),
      );
      await tester.ensureVisible(notificationCenterAction);
      await tester.tap(notificationCenterAction, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(NotificationCenterScreen), findsOneWidget);
    },
  );

  testWidgets(
    'chat screen should keep permission banner and composer visible on compact size',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      PushNotificationService.instance.debugSetState(
        const PushRuntimeState(
          notificationsEnabled: true,
          permissionGranted: false,
        ),
      );

      final thread = _buildThread('u_chat_permission_compact_banner');
      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(
        pushNotificationService: PushNotificationService.instance,
        enableRemoteHydration: false,
      );
      final router = _buildRouter(
        chatProvider: chatProvider,
        friendProvider: friendProvider,
        settingsProvider: settingsProvider,
        threadId: thread.id,
      );
      chatProvider.addThread(thread);

      addTearDown(chatProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('chat-notification-permission-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat-notification-center-action')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('chat-composer-shell')), findsOneWidget);
      expect(
          find.byKey(const Key('chat-composer-send-button')), findsOneWidget);
      expect(tester.takeException(), isNull);

      final bannerActionRect = tester.getRect(
        find.byKey(const Key('chat-notification-center-action')),
      );
      final composerRect =
          tester.getRect(find.byKey(const Key('chat-composer-shell')));
      final sendRect =
          tester.getRect(find.byKey(const Key('chat-composer-send-button')));

      expect(bannerActionRect.bottom, lessThan(composerRect.top));
      expect(sendRect.bottom, lessThanOrEqualTo(640));
      await tester.pump(const Duration(milliseconds: 700));
    },
  );

  testWidgets(
    'chat screen should hide permission banner after recovering permission in settings',
    (tester) async {
      final pushNotificationService = _TestPushNotificationService(
        initialState: const PushRuntimeState(
          notificationsEnabled: true,
          permissionGranted: false,
        ),
        refreshedState: const PushRuntimeState(
          notificationsEnabled: true,
          permissionGranted: true,
          deviceToken: 'stub_chat_permission_ready',
        ),
      );

      final thread = _buildThread('u_chat_permission_recovered');
      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final authProvider = AuthProvider();
      final friendProvider = FriendProvider(enableRemoteHydration: false);
      final settingsProvider = SettingsProvider(
        pushNotificationService: pushNotificationService,
        enableRemoteHydration: false,
      );
      final router = _buildRouter(
        chatProvider: chatProvider,
        friendProvider: friendProvider,
        settingsProvider: settingsProvider,
        threadId: thread.id,
        authProvider: authProvider,
      );
      chatProvider.addThread(thread);

      addTearDown(chatProvider.dispose);
      addTearDown(authProvider.dispose);
      addTearDown(friendProvider.dispose);
      addTearDown(settingsProvider.dispose);
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('chat-notification-permission-banner')),
        findsOneWidget,
      );

      final settingsAction = find.byKey(
        const Key('chat-notification-permission-action'),
      );
      await tester.ensureVisible(settingsAction);
      await tester.tap(settingsAction, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);

      pushNotificationService.debugSetState(
        const PushRuntimeState(
          notificationsEnabled: true,
          permissionGranted: true,
          deviceToken: 'stub_chat_permission_ready',
        ),
      );
      await settingsProvider.refreshPushRuntimeState();
      await tester.pumpAndSettle();

      expect(settingsProvider.pushRuntimeState.deviceToken, isNotNull);

      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(
        find.byKey(const Key('chat-notification-permission-banner')),
        findsNothing,
      );
    },
  );
}
