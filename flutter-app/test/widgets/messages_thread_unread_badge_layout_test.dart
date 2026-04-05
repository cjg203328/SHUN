import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';

import 'helpers/messages_thread_test_host.dart';

class _UnreadBadgeFinders {
  const _UnreadBadgeFinders({
    required this.previewSlot,
    required this.metaSlot,
    required this.badge,
  });

  final Finder previewSlot;
  final Finder metaSlot;
  final Finder badge;
}

_UnreadBadgeFinders _findUnreadBadgeState(String threadId) {
  return _UnreadBadgeFinders(
    previewSlot:
        find.byKey(Key('messages-thread-unread-slot-preview-$threadId')),
    metaSlot: find.byKey(Key('messages-thread-unread-slot-meta-$threadId')),
    badge: find.byKey(Key('messages-thread-unread-$threadId')),
  );
}

void _expectBaseUnreadBadgeState(
  WidgetTester tester,
  _UnreadBadgeFinders finders,
) {
  expect(finders.badge, findsOneWidget);
  expect(tester.takeException(), isNull);
}

void main() {
  setUp(() async {
    await initMessagesThreadTestApp();
  });

  tearDown(() async {
    await clearMessagesThreadTestSession();
  });

  testWidgets(
      'messages thread keeps unread badge in preview row on regular width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(430, 900));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    const threadId = 'u_messages_unread_regular';
    final thread = buildMessagesThread(
      id: threadId,
      unreadCount: 6,
      expiresIn: const Duration(hours: 1, minutes: 35),
      intimacyPoints: 72,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: 'regular-message',
          content: '常规宽度下未读徽标应留在预览行。',
          isMe: false,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        ),
      ],
    );

    final finders = _findUnreadBadgeState(threadId);
    _expectBaseUnreadBadgeState(tester, finders);

    expect(finders.previewSlot, findsOneWidget);
    expect(finders.metaSlot, findsNothing);

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread moves unread badge into meta row on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    const threadId = 'u_messages_unread_compact';
    final thread = buildMessagesThread(
      id: threadId,
      unreadCount: 6,
      expiresIn: const Duration(hours: 1, minutes: 35),
      intimacyPoints: 72,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: 'compact-message',
          content: '紧凑宽度下未读徽标需要下沉到时效行。',
          isMe: false,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        ),
      ],
    );

    final finders = _findUnreadBadgeState(threadId);
    _expectBaseUnreadBadgeState(tester, finders);

    expect(finders.previewSlot, findsNothing);
    expect(finders.metaSlot, findsOneWidget);

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });
}
