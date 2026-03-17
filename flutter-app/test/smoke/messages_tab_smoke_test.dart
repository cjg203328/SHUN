import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
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
      expiresAt: DateTime.now().add(const Duration(hours: 2, minutes: 15)),
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

    expect(find.text('鏈夋柊娑堟伅'), findsOneWidget);
    expect(find.text('鍗冲皢鍒版湡'), findsOneWidget);

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
}
