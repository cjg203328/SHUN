import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/models/app_notification.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/providers/settings_provider.dart';
import 'package:sunliao/screens/notification_center_screen.dart';
import 'package:sunliao/services/push_notification_service.dart';
import 'package:sunliao/services/storage_service.dart';

import '../helpers/test_bootstrap.dart';

User _buildUser(String id) {
  return User(
    id: id,
    uid: 'SN$id',
    nickname: 'User-$id',
    avatar: '😀',
    distance: '2km',
    status: 'available',
    isOnline: true,
  );
}

ChatThread _buildThread(String id, {required User user}) {
  final now = DateTime.now();
  return ChatThread(
    id: id,
    otherUser: user,
    createdAt: now.subtract(const Duration(minutes: 10)),
    expiresAt: now.add(const Duration(hours: 24)),
    intimacyPoints: 60,
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

  testWidgets('notification message should fall back to user id thread lookup',
      (tester) async {
    final user = _buildUser('u_notify_fallback');
    final remoteThread = _buildThread('th_notify_fallback', user: user);
    final chatProvider = ChatProvider();
    addTearDown(chatProvider.dispose);
    chatProvider.addThread(remoteThread);

    await StorageService.saveNotificationCenterState(
      jsonEncode([
        AppNotification(
          id: 'notif-fallback-1',
          type: AppNotificationType.message,
          title: user.nickname,
          body: '旧线程通知也应跳到当前会话',
          createdAt: DateTime.parse('2026-03-12T17:10:00.000'),
          threadId: user.id,
          userId: user.id,
          sourceKey: 'chat-message:${user.id}:msg-1',
        ).toJson(),
      ]),
    );
    await NotificationCenterProvider.instance.reloadFromStorage();

    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(
          path: '/notifications',
          builder: (context, state) => NotificationCenterScreen(
            initialFilter: NotificationCenterSourceFilter.fromQuery(
              state.uri.queryParameters['source'],
            ),
          ),
        ),
        GoRoute(
          path: '/chat/:threadId',
          builder: (context, state) =>
              Text('chat:${state.pathParameters['threadId']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NotificationCenterProvider>.value(
            value: NotificationCenterProvider.instance,
          ),
          ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(user.nickname));
    await tester.pumpAndSettle();

    expect(find.text('chat:${remoteThread.id}'), findsOneWidget);
  });

  testWidgets(
    'notification center should show permission banner and open settings page',
    (tester) async {
      PushNotificationService.instance.debugSetState(
        const PushRuntimeState(
          notificationsEnabled: true,
          permissionGranted: false,
        ),
      );

      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final settingsProvider = SettingsProvider(
        pushNotificationService: PushNotificationService.instance,
        enableRemoteHydration: false,
      );
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
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
          GoRoute(
            path: '/settings',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('settings-route'))),
          ),
        ],
      );

      addTearDown(chatProvider.dispose);
      addTearDown(settingsProvider.dispose);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('notification-center-permission-banner')),
        findsOneWidget,
      );
      expect(find.text('系统通知未打开'), findsOneWidget);
      expect(
        find.text('新消息会先留在这里，锁屏和后台提醒暂不可用。'),
        findsOneWidget,
      );

      final settingsAction = find.byKey(
        const Key('notification-center-permission-action'),
      );
      await tester.ensureVisible(settingsAction);
      await tester.pumpAndSettle();
      await tester.tap(settingsAction, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('settings-route'), findsOneWidget);
    },
  );

  testWidgets(
    'notification center should honor source filter and allow switching back to all',
    (tester) async {
      await StorageService.saveNotificationCenterState(
        jsonEncode([
          AppNotification(
            id: 'notif-filter-system',
            type: AppNotificationType.system,
            title: '系统提醒',
            body: '今晚有新的活动推荐',
            createdAt: DateTime.parse('2026-03-17T08:30:00.000'),
            userId: 'system',
            sourceKey: 'system:notif-filter-system',
          ).toJson(),
          AppNotification(
            id: 'notif-filter-friend',
            type: AppNotificationType.friendAccepted,
            title: '小满',
            body: '已通过你的好友申请',
            createdAt: DateTime.parse('2026-03-17T08:20:00.000'),
            userId: 'u_notify_filter_friend',
            sourceKey: 'friend-accepted:u_notify_filter_friend',
          ).toJson(),
          AppNotification(
            id: 'notif-filter-message',
            type: AppNotificationType.message,
            title: '阿青',
            body: '周末一起喝咖啡吗？',
            createdAt: DateTime.parse('2026-03-17T08:10:00.000'),
            threadId: 'th_notify_filter',
            userId: 'u_notify_filter_message',
            sourceKey: 'chat-message:th_notify_filter:msg-1',
          ).toJson(),
        ]),
      );
      await NotificationCenterProvider.instance.reloadFromStorage();

      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      addTearDown(chatProvider.dispose);

      final router = GoRouter(
        initialLocation: '/notifications?source=system',
        routes: [
          GoRoute(
            path: '/notifications',
            builder: (context, state) => MultiProvider(
              providers: [
                ChangeNotifierProvider<NotificationCenterProvider>.value(
                  value: NotificationCenterProvider.instance,
                ),
                ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
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
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('系统提醒'), findsOneWidget);
      expect(find.text('小满'), findsNothing);
      expect(find.text('阿青'), findsNothing);

      await tester.tap(
        find.byKey(const Key('notification-center-filter-all')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('系统提醒'), findsOneWidget);
      expect(find.text('小满'), findsOneWidget);
      expect(find.text('阿青'), findsOneWidget);
    },
  );

  testWidgets(
    'notification center should keep permission banner and first item visible on compact size',
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

      await StorageService.saveNotificationCenterState(
        jsonEncode([
          AppNotification(
            id: 'notif-compact-system',
            type: AppNotificationType.system,
            title: '系统提醒',
            body: '紧凑模式下，通知横幅和筛选条也需要保持清晰。',
            createdAt: DateTime.parse('2026-03-17T08:30:00.000'),
            userId: 'system',
            sourceKey: 'system:notif-compact-system',
          ).toJson(),
          AppNotification(
            id: 'notif-compact-message',
            type: AppNotificationType.message,
            title: '阿青',
            body: '新消息到了，别让首屏元素挤在一起。',
            createdAt: DateTime.parse('2026-03-17T08:10:00.000'),
            threadId: 'th_notify_compact',
            userId: 'u_notify_compact_message',
            sourceKey: 'chat-message:th_notify_compact:msg-1',
          ).toJson(),
        ]),
      );
      await NotificationCenterProvider.instance.reloadFromStorage();

      final chatProvider = ChatProvider(
        enableRealtime: false,
        enableRemoteHydration: false,
      );
      final settingsProvider = SettingsProvider(
        pushNotificationService: PushNotificationService.instance,
        enableRemoteHydration: false,
      );
      addTearDown(chatProvider.dispose);
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationCenterProvider>.value(
              value: NotificationCenterProvider.instance,
            ),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: NotificationCenterScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final bannerFinder = find.byKey(
        const Key('notification-center-permission-banner'),
      );
      final actionFinder = find.byKey(
        const Key('notification-center-permission-action'),
      );
      final titleFinder = find.byKey(
        const Key('notification-permission-notice-title'),
      );
      final badgeFinder = find.byKey(
        const Key('notification-permission-notice-badge'),
      );
      final descriptionFinder = find.byKey(
        const Key('notification-permission-notice-description'),
      );
      final filterFinder = find.byKey(
        const Key('notification-center-filter-system'),
      );
      final itemFinder = find.byKey(
        const Key('notification-center-item-notif-compact-system'),
      );

      expect(bannerFinder, findsOneWidget);
      expect(actionFinder, findsOneWidget);
      expect(titleFinder, findsOneWidget);
      expect(badgeFinder, findsOneWidget);
      expect(descriptionFinder, findsOneWidget);
      expect(filterFinder, findsOneWidget);
      expect(itemFinder, findsOneWidget);
      expect(tester.takeException(), isNull);

      final actionRect = tester.getRect(actionFinder);
      final titleRect = tester.getRect(titleFinder);
      final badgeRect = tester.getRect(badgeFinder);
      final descriptionRect = tester.getRect(descriptionFinder);
      final filterRect = tester.getRect(filterFinder);
      final itemRect = tester.getRect(itemFinder);

      expect(badgeRect.top, greaterThan(titleRect.bottom));
      expect(descriptionRect.top, greaterThan(badgeRect.bottom));
      expect(descriptionRect.bottom, lessThan(actionRect.top));
      expect(actionRect.bottom, lessThan(filterRect.top));
      expect(filterRect.bottom, lessThan(itemRect.top));
      expect(itemRect.bottom, lessThanOrEqualTo(640));
    },
  );
}
