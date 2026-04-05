import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';

import 'helpers/messages_thread_test_host.dart';

class _OnlinePriorityFinders {
  const _OnlinePriorityFinders({
    required this.thread,
    required this.previewRow,
    required this.priorityRow,
    required this.metaRow,
  });

  final Finder thread;
  final Finder previewRow;
  final Finder priorityRow;
  final Finder metaRow;
}

_OnlinePriorityFinders _findOnlinePriorityState(String threadId) {
  return _OnlinePriorityFinders(
    thread: find.byKey(Key('messages-thread-item-$threadId')),
    previewRow: find.byKey(Key('messages-thread-preview-row-$threadId')),
    priorityRow: find.byKey(Key('messages-thread-priority-row-$threadId')),
    metaRow: find.byKey(Key('messages-thread-meta-row-$threadId')),
  );
}

void _expectBaseOnlinePriorityState(
  WidgetTester tester,
  _OnlinePriorityFinders finders,
) {
  expect(finders.thread, findsOneWidget);
  expect(finders.previewRow, findsOneWidget);
  expect(finders.priorityRow, findsOneWidget);
  expect(finders.metaRow, findsOneWidget);
  expect(tester.takeException(), isNull);
}

void _expectSuppressedOnlinePriorityState(
  WidgetTester tester,
  _OnlinePriorityFinders finders,
) {
  expect(finders.thread, findsOneWidget);
  expect(finders.previewRow, findsOneWidget);
  expect(finders.priorityRow, findsNothing);
  expect(finders.metaRow, findsOneWidget);
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
      'messages thread keeps online priority tag above meta row on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_online_priority_compact';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId, isOnline: true),
      unreadCount: 0,
      createdAgo: const Duration(hours: 1),
      expiresIn: const Duration(hours: 5),
      intimacyPoints: 40,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: 'online-priority-message',
          content: '在线状态下应显示可聊优先标签。',
          isMe: false,
          timestamp: now,
          status: MessageStatus.sent,
        ),
      ],
    );

    final finders = _findOnlinePriorityState(threadId);
    _expectBaseOnlinePriorityState(tester, finders);
    expect(find.text('对方在线可聊'), findsOneWidget);
    expect(find.text('即将到期'), findsNothing);

    final threadRect = tester.getRect(finders.thread);
    final previewRect = tester.getRect(finders.previewRow);
    final priorityRect = tester.getRect(finders.priorityRow);
    final metaRect = tester.getRect(finders.metaRow);

    expect(priorityRect.right, lessThanOrEqualTo(threadRect.right));
    expect(previewRect.bottom, lessThanOrEqualTo(priorityRect.top));
    expect(priorityRect.bottom, lessThanOrEqualTo(metaRect.top));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread prefers expiring hint over online priority when near expiry on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_online_expiring_compact';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId, isOnline: true),
      unreadCount: 0,
      createdAgo: const Duration(hours: 3),
      expiresIn: const Duration(hours: 1, minutes: 10),
      intimacyPoints: 32,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: 'online-expiring-message',
          content: '临近过期时应优先显示即将到期提示。',
          isMe: false,
          timestamp: now,
          status: MessageStatus.sent,
        ),
      ],
    );

    final finders = _findOnlinePriorityState(threadId);
    _expectBaseOnlinePriorityState(tester, finders);
    expect(find.text('即将到期'), findsOneWidget);
    expect(find.text('对方在线可聊'), findsNothing);

    final threadRect = tester.getRect(finders.thread);
    final previewRect = tester.getRect(finders.previewRow);
    final priorityRect = tester.getRect(finders.priorityRow);
    final metaRect = tester.getRect(finders.metaRow);

    expect(priorityRect.right, lessThanOrEqualTo(threadRect.right));
    expect(previewRect.bottom, lessThanOrEqualTo(priorityRect.top));
    expect(priorityRect.bottom, lessThanOrEqualTo(metaRect.top));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread suppresses online priority when unread badge is present on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_online_unread_compact';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId, isOnline: true),
      unreadCount: 5,
      createdAgo: const Duration(hours: 2),
      expiresIn: const Duration(hours: 6),
      intimacyPoints: 28,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: 'online-unread-message',
          content: '有未读时不应再显示在线可聊优先标签。',
          isMe: false,
          timestamp: now,
          status: MessageStatus.sent,
        ),
      ],
    );

    final finders = _findOnlinePriorityState(threadId);
    _expectSuppressedOnlinePriorityState(tester, finders);
    expect(find.text('对方在线可聊'), findsNothing);
    expect(find.text('即将到期'), findsNothing);
    expect(find.byKey(Key('messages-thread-unread-$threadId')), findsOneWidget);

    final threadRect = tester.getRect(finders.thread);
    final previewRect = tester.getRect(finders.previewRow);
    final metaRect = tester.getRect(finders.metaRow);
    final unreadRect =
        tester.getRect(find.byKey(Key('messages-thread-unread-$threadId')));

    expect(previewRect.right, lessThanOrEqualTo(threadRect.right));
    expect(metaRect.right, lessThanOrEqualTo(threadRect.right));
    expect(previewRect.bottom, lessThanOrEqualTo(metaRect.top));
    expect(unreadRect.right, lessThanOrEqualTo(metaRect.right));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread suppresses online priority when draft preview is present on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_online_draft_compact';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId, isOnline: true),
      unreadCount: 0,
      createdAgo: const Duration(hours: 2),
      expiresIn: const Duration(hours: 6),
      intimacyPoints: 28,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: 'online-draft-message',
          content: '有草稿时在线可聊优先标签不应再显示。',
          isMe: false,
          timestamp: now,
          status: MessageStatus.sent,
        ),
      ],
      draft: '这是一条待发送草稿',
    );

    final finders = _findOnlinePriorityState(threadId);
    _expectBaseOnlinePriorityState(tester, finders);
    expect(find.text('对方在线可聊'), findsNothing);
    expect(find.text('草稿待发送'), findsOneWidget);
    expect(find.byKey(Key('messages-thread-draft-slot-$threadId')),
        findsOneWidget);

    final threadRect = tester.getRect(finders.thread);
    final previewRect = tester.getRect(finders.previewRow);
    final priorityRect = tester.getRect(finders.priorityRow);
    final metaRect = tester.getRect(finders.metaRow);

    expect(priorityRect.right, lessThanOrEqualTo(threadRect.right));
    expect(previewRect.bottom, lessThanOrEqualTo(priorityRect.top));
    expect(priorityRect.bottom, lessThanOrEqualTo(metaRect.top));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread suppresses online priority when failure priority is present on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_online_failed_compact';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId, isOnline: true),
      unreadCount: 0,
      createdAgo: const Duration(hours: 2),
      expiresIn: const Duration(hours: 6),
      intimacyPoints: 28,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: 'online-failed-message',
          content: '发送失败时在线可聊优先标签不应再显示。',
          isMe: true,
          timestamp: now,
          status: MessageStatus.failed,
        ),
      ],
    );

    final finders = _findOnlinePriorityState(threadId);
    _expectBaseOnlinePriorityState(tester, finders);
    expect(find.text('对方在线可聊'), findsNothing);
    expect(find.text('发送失败'), findsNWidgets(2));
    expect(
      find.byKey(Key('messages-thread-delivery-badge-slot-$threadId')),
      findsOneWidget,
    );

    final threadRect = tester.getRect(finders.thread);
    final previewRect = tester.getRect(finders.previewRow);
    final priorityRect = tester.getRect(finders.priorityRow);
    final metaRect = tester.getRect(finders.metaRow);

    expect(priorityRect.right, lessThanOrEqualTo(threadRect.right));
    expect(previewRect.bottom, lessThanOrEqualTo(priorityRect.top));
    expect(priorityRect.bottom, lessThanOrEqualTo(metaRect.top));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });
}
