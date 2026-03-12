import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/screens/chat_screen.dart';
import 'package:sunliao/services/chat_service.dart';
import 'package:sunliao/services/chat_socket_service.dart';

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

class _ChatScreenHost extends StatelessWidget {
  const _ChatScreenHost({
    required this.threadId,
    required this.chatProvider,
    required this.friendProvider,
  });

  final String threadId;
  final ChatProvider chatProvider;
  final FriendProvider friendProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationCenterProvider>.value(
          value: NotificationCenterProvider.instance,
        ),
        ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
        ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
      ],
      child: MaterialApp(
        home: ChatScreen(threadId: threadId),
      ),
    );
  }
}

void main() {
  setUp(() async {
    await initTestAppStorage();
    await NotificationCenterProvider.instance.clearSession();
  });

  tearDown(() async {
    await NotificationCenterProvider.instance.clearSession();
  });

  testWidgets('chat screen should switch active thread when widget thread changes',
      (tester) async {
    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    addTearDown(chatProvider.dispose);
    addTearDown(friendProvider.dispose);

    final firstThread = _buildThread('u_chat_screen_a');
    final secondThread = _buildThread('u_chat_screen_b');
    chatProvider.addThread(firstThread);
    chatProvider.addThread(secondThread);

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: firstThread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: secondThread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    ChatSocketService.instance.onMessageNew?.call(
      IncomingMessageEvent(
        threadId: firstThread.id,
        message: Message(
          id: 'screen-switch-old-thread',
          content: '旧会话不应再算活跃',
          isMe: false,
          timestamp: DateTime.parse('2026-03-12T16:20:00.000'),
          status: MessageStatus.sent,
        ),
      ),
    );
    ChatSocketService.instance.onMessageNew?.call(
      IncomingMessageEvent(
        threadId: secondThread.id,
        message: Message(
          id: 'screen-switch-new-thread',
          content: '新会话仍应保持活跃',
          isMe: false,
          timestamp: DateTime.parse('2026-03-12T16:20:10.000'),
          status: MessageStatus.sent,
        ),
      ),
    );
    await tester.pump();

    expect(chatProvider.getThread(firstThread.id)?.unreadCount, 1);
    expect(chatProvider.getThread(secondThread.id)?.unreadCount, 0);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('chat screen should reset composer state when widget thread changes',
      (tester) async {
    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    addTearDown(chatProvider.dispose);
    addTearDown(friendProvider.dispose);

    final firstThread = _buildThread('u_chat_screen_reset_a');
    final secondThread = _buildThread('u_chat_screen_reset_b');
    chatProvider.addThread(firstThread);
    chatProvider.addThread(secondThread);

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: firstThread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '上一段会话的输入');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.local_fire_department).first);
    await tester.pump();

    expect(find.text('已开启闪图，仅下一张图片生效'), findsOneWidget);
    expect(find.text('上一段会话的输入'), findsOneWidget);

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: secondThread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    expect(find.text('已开启闪图，仅下一张图片生效'), findsNothing);
    expect(find.text('上一段会话的输入'), findsNothing);

    final textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(textField.controller?.text ?? '', isEmpty);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('chat screen should stay usable after local thread upgrades',
      (tester) async {
    final localThread = _buildThread('u_chat_screen_upgrade_local');
    final remoteThread = ChatThread(
      id: 'th_chat_screen_upgrade_remote',
      otherUser: localThread.otherUser,
      createdAt: localThread.createdAt,
      expiresAt: localThread.expiresAt,
      intimacyPoints: localThread.intimacyPoints,
    );
    final chatProvider = ChatProvider(
      chatService: _FakeScreenChatService(
        directThreadsByUserId: {localThread.otherUser.id: remoteThread},
        hasSessionOverride: true,
      ),
    );
    final friendProvider = FriendProvider();
    addTearDown(chatProvider.dispose);
    addTearDown(friendProvider.dispose);

    chatProvider.addThread(localThread);

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: localThread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    await chatProvider.ensureDirectThreadForUser(localThread.otherUser);
    await tester.pump();

    ChatSocketService.instance.onMessageNew?.call(
      IncomingMessageEvent(
        threadId: remoteThread.id,
        message: Message(
          id: 'screen-upgrade-remote-message',
          content: '升级后旧路由仍应保持会话激活',
          isMe: false,
          timestamp: DateTime.parse('2026-03-12T16:30:00.000'),
          status: MessageStatus.sent,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(chatProvider.getThread(localThread.id)?.id, remoteThread.id);
    expect(chatProvider.getThread(remoteThread.id)?.unreadCount, 0);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('chat screen should replace route with canonical thread id',
      (tester) async {
    final localThread = _buildThread('u_chat_screen_route_local');
    final remoteThread = ChatThread(
      id: 'th_chat_screen_route_remote',
      otherUser: localThread.otherUser,
      createdAt: localThread.createdAt,
      expiresAt: localThread.expiresAt,
      intimacyPoints: localThread.intimacyPoints,
    );
    final chatProvider = ChatProvider(
      chatService: _FakeScreenChatService(
        directThreadsByUserId: {localThread.otherUser.id: remoteThread},
        hasSessionOverride: true,
      ),
    );
    final friendProvider = FriendProvider();
    addTearDown(chatProvider.dispose);
    addTearDown(friendProvider.dispose);

    chatProvider.addThread(localThread);

    final router = GoRouter(
      initialLocation: '/chat/${localThread.id}',
      routes: [
        GoRoute(
          path: '/chat/:threadId',
          builder: (context, state) => MultiProvider(
            providers: [
              ChangeNotifierProvider<NotificationCenterProvider>.value(
                value: NotificationCenterProvider.instance,
              ),
              ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
              ChangeNotifierProvider<FriendProvider>.value(
                value: friendProvider,
              ),
            ],
            child: ChatScreen(threadId: state.pathParameters['threadId']!),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
      ),
    );
    await tester.pump();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/chat/${localThread.id}',
    );

    await chatProvider.ensureDirectThreadForUser(localThread.otherUser);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
    expect(chatScreen.threadId, remoteThread.id);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _FakeScreenChatService extends ChatService {
  _FakeScreenChatService({
    this.directThreadsByUserId = const <String, ChatThread>{},
    this.hasSessionOverride = false,
  });

  final Map<String, ChatThread> directThreadsByUserId;
  final bool hasSessionOverride;

  @override
  bool get hasSession => hasSessionOverride;

  @override
  Future<ChatThread?> createDirectThread(User user) async {
    return directThreadsByUserId[user.id];
  }
}
