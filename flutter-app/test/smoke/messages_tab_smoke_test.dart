import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/auth_provider.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/match_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/providers/profile_provider.dart';
import 'package:sunliao/providers/settings_provider.dart';
import 'package:sunliao/screens/chat_screen.dart';
import 'package:sunliao/screens/main_screen.dart';
import 'package:sunliao/widgets/messages_tab.dart';

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

Widget _buildHost({
  required ChatProvider chatProvider,
  required FriendProvider friendProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NotificationCenterProvider>.value(
        value: NotificationCenterProvider.instance,
      ),
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
    ],
    child: const MaterialApp(home: MessagesTab()),
  );
}

Widget _buildShellHost({
  required GoRouter router,
  required AuthProvider authProvider,
  required ChatProvider chatProvider,
  required FriendProvider friendProvider,
  required MatchProvider matchProvider,
  required ProfileProvider profileProvider,
  required SettingsProvider settingsProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<NotificationCenterProvider>.value(
        value: NotificationCenterProvider.instance,
      ),
      ChangeNotifierProvider<MatchProvider>.value(value: matchProvider),
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
      ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _disposeHost(
  WidgetTester tester,
  ChatProvider chatProvider,
  FriendProvider friendProvider,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  chatProvider.dispose();
  friendProvider.dispose();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _disposeShellHost(
  WidgetTester tester, {
  required AuthProvider authProvider,
  required ChatProvider chatProvider,
  required FriendProvider friendProvider,
  required MatchProvider matchProvider,
  required ProfileProvider profileProvider,
  required SettingsProvider settingsProvider,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  authProvider.dispose();
  chatProvider.dispose();
  friendProvider.dispose();
  matchProvider.dispose();
  profileProvider.dispose();
  settingsProvider.dispose();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  setUp(() async {
    await initTestAppStorage();
    await NotificationCenterProvider.instance.clearSession();
  });

  tearDown(() async {
    await NotificationCenterProvider.instance.clearSession();
  });

  testWidgets('messages tab should prefer draft preview over last message',
      (tester) async {
    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();

    final thread = _buildThread('u_messages_draft');
    chatProvider.addThread(thread);
    chatProvider.getMessages(thread.id).add(
          Message(
            id: 'last-message',
            content: '上一条正式消息',
            isMe: false,
            timestamp: DateTime.parse('2026-03-12T20:10:00.000'),
            status: MessageStatus.sent,
          ),
        );
    chatProvider.saveDraft(thread.id, '这条草稿还没发出去');

    await tester.pumpWidget(
      _buildHost(
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    expect(find.text('草稿'), findsOneWidget);
    expect(find.text('这条草稿还没发出去'), findsOneWidget);
    expect(find.text('上一条正式消息'), findsNothing);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('messages tab should show sending summary and badge',
      (tester) async {
    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();

    final thread = _buildThread('u_messages_sending');
    chatProvider.addThread(thread);
    chatProvider.getMessages(thread.id).add(
          Message(
            id: 'sending-message',
            content: '这条消息正在发送',
            isMe: true,
            timestamp: DateTime.parse('2026-03-13T11:00:00.000'),
            status: MessageStatus.sending,
            type: MessageType.text,
          ),
        );

    await tester.pumpWidget(
      _buildHost(
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    expect(find.text('发送中：这条消息正在发送'), findsOneWidget);
    expect(find.text('发送中'), findsOneWidget);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages tab should show reselect state for failed original image',
      (tester) async {
    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();

    final thread = _buildThread('u_messages_original_fail');
    chatProvider.addThread(thread);
    chatProvider.getMessages(thread.id).add(
          Message(
            id: 'failed-image',
            content: '[图片]',
            isMe: true,
            timestamp: DateTime.parse('2026-03-13T11:00:10.000'),
            status: MessageStatus.failed,
            type: MessageType.image,
            imagePath: r'C:\mock\missing-original.jpg',
            imageQuality: ImageQuality.original,
          ),
        );

    await tester.pumpWidget(
      _buildHost(
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    expect(find.text('原图失效，请重选图片'), findsOneWidget);
    expect(find.text('重选图片'), findsNWidgets(2));
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('messages tab should show delivered and read badges',
      (tester) async {
    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();

    final deliveredThread = _buildThread('u_messages_delivered');
    final readThread = _buildThread('u_messages_read');
    chatProvider.addThread(deliveredThread);
    chatProvider.addThread(readThread);

    chatProvider.getMessages(deliveredThread.id).add(
          Message(
            id: 'delivered-message',
            content: '这条消息已经送达',
            isMe: true,
            timestamp: DateTime.parse('2026-03-13T11:01:00.000'),
            status: MessageStatus.sent,
            isRead: false,
          ),
        );
    chatProvider.getMessages(readThread.id).add(
          Message(
            id: 'read-message',
            content: '这条消息对方已读',
            isMe: true,
            timestamp: DateTime.parse('2026-03-13T11:01:10.000'),
            status: MessageStatus.sent,
            isRead: true,
          ),
        );

    await tester.pumpWidget(
      _buildHost(
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    expect(find.text('已送达'), findsOneWidget);
    expect(find.text('已读'), findsOneWidget);
    expect(find.text('这条消息已经送达'), findsOneWidget);
    expect(find.text('这条消息对方已读'), findsOneWidget);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages tab should show priority tags for unread expiring threads',
      (tester) async {
    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();

    final thread = ChatThread(
      id: 'u_messages_priority',
      otherUser: _buildUser('u_messages_priority').copyWith(isOnline: true),
      unreadCount: 3,
      createdAt: DateTime.now().subtract(const Duration(hours: 22)),
      expiresAt: DateTime.now().add(const Duration(hours: 1, minutes: 55)),
      intimacyPoints: 35,
    );
    chatProvider.addThread(thread);
    chatProvider.getMessages(thread.id).add(
          Message(
            id: 'priority-message',
            content: '蹇湅鐪嬭繖鏉℃秷鎭?',
            isMe: false,
            timestamp: DateTime.now(),
            status: MessageStatus.sent,
          ),
        );

    await tester.pumpWidget(
      _buildHost(
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('messages-thread-priority-u_messages_priority')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('messages-thread-expiring-u_messages_priority')),
      findsOneWidget,
    );

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('messages tab should keep thread card visible on compact size',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final thread = _buildThread('u_messages_compact');
    chatProvider.addThread(thread);
    chatProvider.getMessages(thread.id).add(
          Message(
            id: 'compact-message',
            content: '杩欐槸涓€鏉″湪灏忓睆涓婁篃瑕佺湅娓呮鐨勬秷鎭?',
            isMe: false,
            timestamp: DateTime.now(),
            status: MessageStatus.sent,
          ),
        );

    await tester.pumpWidget(
      _buildHost(
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('messages-thread-item-u_messages_compact')),
      findsOneWidget,
    );

    final rect = tester.getRect(
        find.byKey(const Key('messages-thread-item-u_messages_compact')));
    expect(rect.bottom, lessThanOrEqualTo(640));

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages tab should keep unread and intimacy cues readable on compact size',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final thread = ChatThread(
      id: 'u_messages_compact_dense',
      otherUser: _buildUser('u_messages_compact_dense'),
      unreadCount: 4,
      createdAt: DateTime.now().subtract(const Duration(hours: 23)),
      expiresAt: DateTime.now().add(const Duration(hours: 1, minutes: 20)),
      intimacyPoints: 88,
    );
    chatProvider.addThread(thread);
    chatProvider.getMessages(thread.id).add(
          Message(
            id: 'compact-dense-message',
            content: '这条消息正在发送中，也要保证小屏信息层级清楚。',
            isMe: true,
            timestamp: DateTime.now(),
            status: MessageStatus.sending,
          ),
        );

    await tester.pumpWidget(
      _buildHost(
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    final threadFinder = find.byKey(
      const Key('messages-thread-item-u_messages_compact_dense'),
    );
    final unreadFinder = find.byKey(
      const Key('messages-thread-unread-u_messages_compact_dense'),
    );
    final intimacyFinder = find.byKey(
      const Key('messages-thread-intimacy-u_messages_compact_dense'),
    );

    expect(threadFinder, findsOneWidget);
    expect(find.text('发送中'), findsOneWidget);
    expect(unreadFinder, findsOneWidget);
    expect(intimacyFinder, findsOneWidget);
    expect(tester.takeException(), isNull);

    final threadRect = tester.getRect(threadFinder);
    final unreadRect = tester.getRect(unreadFinder);
    final intimacyRect = tester.getRect(intimacyFinder);

    expect(threadRect.bottom, lessThanOrEqualTo(640));
    expect(unreadRect.right, lessThanOrEqualTo(threadRect.right));
    expect(intimacyRect.right, lessThanOrEqualTo(threadRect.right));
    expect(unreadRect.bottom, lessThanOrEqualTo(threadRect.bottom));
    expect(intimacyRect.bottom, lessThanOrEqualTo(threadRect.bottom));

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages tab should return to messages tab after leaving chat screen',
      (tester) async {
    final authProvider = AuthProvider();
    final chatProvider = ChatProvider(
      enableRealtime: false,
      enableRemoteHydration: false,
    );
    final friendProvider = FriendProvider(enableRemoteHydration: false);
    final matchProvider = MatchProvider();
    final profileProvider = ProfileProvider();
    final settingsProvider = SettingsProvider(enableRemoteHydration: false);

    final thread = _buildThread('u_messages_backflow');
    chatProvider.addThread(thread);
    chatProvider.getMessages(thread.id).add(
          Message(
            id: 'backflow-message',
            content: '从消息页点进聊天再返回',
            isMe: false,
            timestamp: DateTime.now(),
            status: MessageStatus.sent,
          ),
        );

    final router = GoRouter(
      initialLocation: '/main?tab=1',
      routes: [
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
          builder: (context, state) => ChatScreen(
            threadId: state.pathParameters['threadId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      _buildShellHost(
        router: router,
        authProvider: authProvider,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
        matchProvider: matchProvider,
        profileProvider: profileProvider,
        settingsProvider: settingsProvider,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('messages-tab-title')), findsOneWidget);
    expect(
      find.byKey(const Key('messages-thread-item-u_messages_backflow')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('messages-thread-item-u_messages_backflow')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('messages-tab-title')), findsOneWidget);
    expect(find.byType(ChatScreen), findsNothing);
    expect(
      find.byKey(const Key('messages-thread-item-u_messages_backflow')),
      findsOneWidget,
    );

    await _disposeShellHost(
      tester,
      authProvider: authProvider,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      matchProvider: matchProvider,
      profileProvider: profileProvider,
      settingsProvider: settingsProvider,
    );
  });
}
