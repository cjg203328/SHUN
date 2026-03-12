import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/models/app_notification.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/screens/notification_center_screen.dart';
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
    await NotificationCenterProvider.instance.clearSession();
  });

  tearDown(() async {
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
          builder: (context, state) => const NotificationCenterScreen(),
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
}
