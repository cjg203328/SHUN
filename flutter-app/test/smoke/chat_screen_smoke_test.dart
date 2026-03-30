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

User _buildUser(String id, {String? nickname}) {
  return User(
    id: id,
    uid: 'SN$id',
    nickname: nickname ?? 'User-$id',
    avatar: '🙂',
    distance: '2km',
    status: 'available',
    isOnline: true,
  );
}

ChatThread _buildThread(String id, {String? nickname}) {
  final now = DateTime.now();
  return ChatThread(
    id: id,
    otherUser: _buildUser(id, nickname: nickname),
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

Future<void> _disposeHost(
  WidgetTester tester,
  ChatProvider chatProvider,
  FriendProvider friendProvider,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  chatProvider.dispose();
  friendProvider.dispose();
  await NotificationCenterProvider.instance.clearSession();
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

  testWidgets(
      'chat screen should switch active thread when widget thread changes',
      (tester) async {
    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();

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
          content: '旧会话应该累加未读',
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
          content: '当前会话不应累加未读',
          isMe: false,
          timestamp: DateTime.parse('2026-03-12T16:20:10.000'),
          status: MessageStatus.sent,
        ),
      ),
    );
    await tester.pump();

    expect(chatProvider.getThread(firstThread.id)?.unreadCount, 1);
    expect(chatProvider.getThread(secondThread.id)?.unreadCount, 0);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'chat screen should restore per-thread draft when widget thread changes',
      (tester) async {
    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();

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

    await tester.enterText(find.byType(TextField).first, '第一段会话草稿');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.local_fire_department).first);
    await tester.pump();

    var textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(textField.controller?.text, '第一段会话草稿');

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: secondThread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(textField.controller?.text ?? '', isEmpty);

    await tester.enterText(find.byType(TextField).first, '第二段会话草稿');
    await tester.pump();

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: firstThread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(textField.controller?.text, '第一段会话草稿');
    expect(find.text('第二段会话草稿'), findsNothing);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('chat screen should render remote avatar image in header',
      (tester) async {
    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();

    final thread = ChatThread(
      id: 'u_chat_remote_avatar',
      otherUser: User(
        id: 'u_chat_remote_avatar',
        uid: 'SNCHATAVATAR',
        nickname: 'Remote Header Avatar',
        avatar: 'avatar/u_chat_remote_avatar/profile.jpg',
        distance: '2km',
        status: 'available',
        isOnline: true,
      ),
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      intimacyPoints: 60,
    );
    chatProvider.addThread(thread);

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: thread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('chat-header-avatar')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );

    await _disposeHost(tester, chatProvider, friendProvider);
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
          content: '升级后仍然可以继续聊天',
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

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('chat screen should show inline delivery cards for my messages',
      (tester) async {
    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();

    final thread = _buildThread('u_chat_screen_delivery_states');
    chatProvider.addThread(thread);
    chatProvider.getMessages(thread.id).addAll([
      Message(
        id: 'sending-message',
        content: '这条消息还在发送中',
        isMe: true,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
      ),
      Message(
        id: 'failed-message',
        content: '这条消息发送失败了',
        isMe: true,
        timestamp: DateTime.now().add(const Duration(seconds: 1)),
        status: MessageStatus.failed,
      ),
    ]);

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: thread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发送中'), findsOneWidget);
    expect(find.text('正在投递给对方'), findsOneWidget);
    expect(find.text('发送失败'), findsOneWidget);
    expect(find.text('点击重试后继续发送'), findsOneWidget);
    expect(find.text('立即重试'), findsOneWidget);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'chat screen should show reselect guide for failed original image',
      (tester) async {
    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();

    final thread = _buildThread('u_chat_screen_failed_original_image');
    chatProvider.addThread(thread);
    chatProvider.getMessages(thread.id).add(
          Message(
            id: 'failed-original-image',
            content: '',
            isMe: true,
            timestamp: DateTime.now(),
            status: MessageStatus.failed,
            type: MessageType.image,
            imageQuality: ImageQuality.original,
          ),
        );

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: thread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('重选图片'), findsOneWidget);
    expect(find.text('原图失效，请重选图片'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('chat-delivery-status-action:showGuide'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('chat-delivery-status-action:showGuide'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('图片需要重选'), findsOneWidget);
    expect(find.text('重新选图'), findsOneWidget);
    expect(find.byIcon(Icons.compress_outlined), findsOneWidget);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('chat screen should keep failure guide stable on tight size',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();

    final thread = _buildThread('u_chat_screen_failed_image_tight');
    chatProvider.addThread(thread);
    chatProvider.getMessages(thread.id).add(
          Message(
            id: 'failed-tight-image',
            content: '',
            isMe: true,
            timestamp: DateTime.now(),
            status: MessageStatus.failed,
            type: MessageType.image,
            imageQuality: ImageQuality.original,
          ),
        );

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: thread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey<String>('chat-delivery-status-action:showGuide'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('chat-image-failure-guide-sheet')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.compress_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);

    final sheetRect =
        tester.getRect(find.byKey(const Key('chat-image-failure-guide-sheet')));
    expect(sheetRect.height, lessThanOrEqualTo(568));

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'chat screen should rely on inline delivery status without success toast',
      (tester) async {
    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();

    final thread = _buildThread('u_chat_screen_delivery_feedback');
    chatProvider.addThread(thread);
    chatProvider.getMessages(thread.id).add(
          Message(
            id: 'delivery-feedback-message',
            content: '这条消息刚刚送达',
            isMe: true,
            timestamp: DateTime.now(),
            status: MessageStatus.sending,
          ),
        );

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: thread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    final messages = chatProvider.getMessages(thread.id);
    messages[0] = messages[0].copyWith(status: MessageStatus.sent);
    chatProvider.notifyListeners();
    await tester.pump();
    await tester.pump();

    expect(find.text('消息已送达'), findsNothing);
    expect(find.text('已送达'), findsOneWidget);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('chat screen should show composer capability chips',
      (tester) async {
    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();

    final lockedThread = ChatThread(
      id: 'u_chat_screen_locked_image',
      otherUser: _buildUser('u_chat_screen_locked_image'),
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      intimacyPoints: 0,
    );
    chatProvider.addThread(lockedThread);

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: lockedThread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('chat-composer-capability-row')),
      findsOneWidget,
    );
    expect(find.text('文字可发送'), findsOneWidget);
    expect(find.text('图片待解锁'), findsOneWidget);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('chat screen should keep unfollow banner stable on tight size',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    final thread = ChatThread(
      id: 'u_chat_screen_unfollow_tight',
      otherUser: _buildUser(
        'u_chat_screen_unfollow_tight',
        nickname: 'A very long contact name for unfollow banner verification',
      ),
      createdAt: now.subtract(const Duration(minutes: 10)),
      expiresAt: now.add(const Duration(hours: 24)),
      intimacyPoints: 60,
      isUnfollowed: true,
      messagesSinceUnfollow: 3,
    );
    chatProvider.addThread(thread);

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: thread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat-unfollow-banner')), findsOneWidget);
    expect(
      find.byKey(const Key('chat-unfollow-banner-remind-action')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    final bannerRect =
        tester.getRect(find.byKey(const Key('chat-unfollow-banner')));
    final actionRect = tester.getRect(
      find.byKey(const Key('chat-unfollow-banner-remind-action')),
    );
    final composerRect =
        tester.getRect(find.byKey(const Key('chat-composer-shell')));

    expect(bannerRect.bottom, lessThanOrEqualTo(composerRect.top));
    expect(actionRect.bottom, lessThanOrEqualTo(composerRect.top));

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'chat screen should keep composer actions visible on compact size',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final thread = _buildThread('u_chat_screen_compact_composer');
    chatProvider.addThread(thread);

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: thread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat-composer-shell')), findsOneWidget);
    expect(find.byKey(const Key('chat-composer-send-button')), findsOneWidget);
    expect(find.byKey(const Key('chat-header-avatar')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('chat-composer-input')),
      List<String>.generate(12, (index) => 'compact line $index').join('\n'),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final sendRect =
        tester.getRect(find.byKey(const Key('chat-composer-send-button')));
    expect(sendRect.bottom, lessThanOrEqualTo(640));

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'chat screen should keep header and composer stable on tight size',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final thread = _buildThread(
      'u_chat_screen_tight_layout',
      nickname: 'A very long contact name for tight layout verification',
    );
    chatProvider.addThread(thread);

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: thread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('chat-composer-input')),
      List<String>.generate(10, (index) => 'tight line $index').join('\n'),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('chat-header-title')), findsOneWidget);

    final avatarRect =
        tester.getRect(find.byKey(const Key('chat-header-avatar')));
    final titleRect =
        tester.getRect(find.byKey(const Key('chat-header-title')));
    final menuRect = tester.getRect(find.byIcon(Icons.more_horiz));
    final sendRect =
        tester.getRect(find.byKey(const Key('chat-composer-send-button')));

    expect(avatarRect.right, lessThan(titleRect.right));
    expect(titleRect.right, lessThanOrEqualTo(menuRect.left));
    expect(sendRect.bottom, lessThanOrEqualTo(568));

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets('chat screen should open user profile sheet from action menu',
      (tester) async {
    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final thread = _buildThread('u_chat_screen_profile_sheet');
    chatProvider.addThread(thread);

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: thread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat-action-menu-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat-action-menu-profile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat-user-profile-sheet')), findsOneWidget);
    expect(
      find.byKey(const Key('chat-user-profile-primary-action')),
      findsOneWidget,
    );

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'chat screen should update retry success inline without success toast',
      (tester) async {
    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();

    final thread = _buildThread('u_chat_screen_retry_feedback');
    chatProvider.addThread(thread);
    chatProvider.getMessages(thread.id).add(
          Message(
            id: 'retry-feedback-message',
            content: '这条消息需要重试',
            isMe: true,
            timestamp: DateTime.now(),
            status: MessageStatus.failed,
          ),
        );

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: thread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('立即重试'));
    await tester.pump();

    final messages = chatProvider.getMessages(thread.id);
    messages[0] = messages[0].copyWith(status: MessageStatus.sending);
    chatProvider.notifyListeners();
    await tester.pump();

    messages[0] = messages[0].copyWith(status: MessageStatus.sent);
    chatProvider.notifyListeners();
    await tester.pump();
    await tester.pump();

    expect(find.text('重试成功，已送达'), findsNothing);
    expect(find.text('已送达'), findsOneWidget);

    await _disposeHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'chat screen should show retry failure feedback after retried message fails again',
      (tester) async {
    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();

    final thread = _buildThread('u_chat_screen_retry_failure_feedback');
    chatProvider.addThread(thread);
    chatProvider.getMessages(thread.id).add(
          Message(
            id: 'retry-failure-feedback-message',
            content: '这条消息重试后仍然失败',
            isMe: true,
            timestamp: DateTime.now(),
            status: MessageStatus.failed,
          ),
        );

    await tester.pumpWidget(
      _ChatScreenHost(
        threadId: thread.id,
        chatProvider: chatProvider,
        friendProvider: friendProvider,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('立即重试'));
    await tester.tap(find.text('立即重试'), warnIfMissed: false);
    await tester.pump();

    final messages = chatProvider.getMessages(thread.id);
    messages[0] = messages[0].copyWith(status: MessageStatus.sending);
    chatProvider.notifyListeners();
    await tester.pump();

    messages[0] = messages[0].copyWith(status: MessageStatus.failed);
    chatProvider.notifyListeners();
    await tester.pump();
    await tester.pump();

    expect(find.text('重试失败，请重试'), findsOneWidget);

    await _disposeHost(tester, chatProvider, friendProvider);
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

    await _disposeHost(tester, chatProvider, friendProvider);
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
