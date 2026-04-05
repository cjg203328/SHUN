import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';
import 'package:sunliao/utils/chat_delivery_state.dart';

import 'helpers/messages_thread_test_host.dart';

class _PriorityTagFinders {
  const _PriorityTagFinders({
    required this.thread,
    required this.priority,
    required this.metaRow,
    this.unreadMeta,
  });

  final Finder thread;
  final Finder priority;
  final Finder metaRow;
  final Finder? unreadMeta;
}

_PriorityTagFinders _findPriorityTagState(
  String threadId, {
  bool includeUnreadMeta = false,
}) {
  return _PriorityTagFinders(
    thread: find.byKey(Key('messages-thread-item-$threadId')),
    priority: find.byKey(Key('messages-thread-priority-$threadId')),
    metaRow: find.byKey(Key('messages-thread-meta-row-$threadId')),
    unreadMeta: includeUnreadMeta
        ? find.byKey(Key('messages-thread-unread-slot-meta-$threadId'))
        : null,
  );
}

void _expectBasePriorityTagState(
  WidgetTester tester,
  _PriorityTagFinders finders,
) {
  expect(finders.thread, findsOneWidget);
  expect(finders.priority, findsOneWidget);
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
      'messages thread keeps failure priority tag above meta row on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_priority_compact';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId),
      unreadCount: 5,
      createdAgo: const Duration(hours: 6),
      expiresIn: const Duration(hours: 4),
      intimacyPoints: 48,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: 'priority-message',
          content: '这条失败消息需要在小屏上保持层级稳定。',
          isMe: true,
          timestamp: now,
          status: MessageStatus.failed,
        ),
      ],
    );

    final finders = _findPriorityTagState(threadId, includeUnreadMeta: true);
    _expectBasePriorityTagState(tester, finders);
    expect(finders.unreadMeta, findsOneWidget);
    expect(find.byKey(Key('messages-thread-unread-$threadId')), findsOneWidget);
    expect(find.text('发送失败'), findsOneWidget);

    final threadRect = tester.getRect(finders.thread);
    final priorityRect = tester.getRect(finders.priority);
    final metaRowRect = tester.getRect(finders.metaRow);
    final unreadRect = tester.getRect(finders.unreadMeta!);

    expect(priorityRect.right, lessThanOrEqualTo(threadRect.right));
    expect(priorityRect.bottom, lessThanOrEqualTo(metaRowRect.top));
    expect(unreadRect.right, lessThanOrEqualTo(metaRowRect.right));
    expect(unreadRect.bottom, lessThanOrEqualTo(metaRowRect.bottom));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread keeps expiring tag above meta row on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_expiring_compact';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId),
      createdAgo: const Duration(hours: 22),
      expiresIn: const Duration(hours: 1, minutes: 20),
      intimacyPoints: 12,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: 'expiring-message',
          content: '这条消息会触发即将到期提示。',
          isMe: false,
          timestamp: now,
          status: MessageStatus.sent,
        ),
      ],
    );

    final finders = _PriorityTagFinders(
      thread: find.byKey(Key('messages-thread-item-$threadId')),
      priority: find.byKey(Key('messages-thread-expiring-$threadId')),
      metaRow: find.byKey(Key('messages-thread-meta-row-$threadId')),
    );
    _expectBasePriorityTagState(tester, finders);
    expect(find.text('即将到期'), findsOneWidget);

    final threadRect = tester.getRect(finders.thread);
    final expiringRect = tester.getRect(finders.priority);
    final metaRowRect = tester.getRect(finders.metaRow);

    expect(expiringRect.right, lessThanOrEqualTo(threadRect.right));
    expect(expiringRect.bottom, lessThanOrEqualTo(metaRowRect.top));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread keeps network issue priority tag above meta row on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_network_issue_compact';
    const messageId = 'network-issue-message';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId),
      unreadCount: 2,
      createdAgo: const Duration(hours: 5),
      expiresIn: const Duration(hours: 3),
      intimacyPoints: 18,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: messageId,
          content: '弱网失败消息应显示网络波动优先标签。',
          isMe: true,
          timestamp: now,
          status: MessageStatus.failed,
        ),
      ],
    );

    chatProvider.markMessageFailedForTesting(
      threadId,
      messageId,
      failureState: ChatDeliveryFailureState.networkIssue,
    );
    await tester.pump();

    final finders = _findPriorityTagState(threadId, includeUnreadMeta: true);
    _expectBasePriorityTagState(tester, finders);
    expect(finders.unreadMeta, findsOneWidget);
    expect(find.text('网络波动'), findsOneWidget);
    expect(
      find.byKey(Key('messages-thread-delivery-badge-slot-$threadId')),
      findsOneWidget,
    );

    final threadRect = tester.getRect(finders.thread);
    final priorityRect = tester.getRect(finders.priority);
    final metaRowRect = tester.getRect(finders.metaRow);
    final unreadRect = tester.getRect(finders.unreadMeta!);

    expect(priorityRect.right, lessThanOrEqualTo(threadRect.right));
    expect(priorityRect.bottom, lessThanOrEqualTo(metaRowRect.top));
    expect(unreadRect.right, lessThanOrEqualTo(metaRowRect.right));
    expect(unreadRect.bottom, lessThanOrEqualTo(metaRowRect.bottom));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread keeps retry unavailable priority tag above meta row on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_retry_unavailable_compact';
    const messageId = 'retry-unavailable-message';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId),
      unreadCount: 1,
      createdAgo: const Duration(hours: 4),
      expiresIn: const Duration(hours: 3),
      intimacyPoints: 22,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: messageId,
          content: '不可重试失败消息应显示暂不可重试优先标签。',
          isMe: true,
          timestamp: now,
          status: MessageStatus.failed,
        ),
      ],
    );

    chatProvider.markMessageFailedForTesting(
      threadId,
      messageId,
      failureState: ChatDeliveryFailureState.retryUnavailable,
    );
    await tester.pump();

    final finders = _findPriorityTagState(threadId, includeUnreadMeta: true);
    _expectBasePriorityTagState(tester, finders);
    expect(finders.unreadMeta, findsOneWidget);
    expect(find.text('暂不可重试'), findsOneWidget);
    expect(
      find.byKey(Key('messages-thread-delivery-badge-slot-$threadId')),
      findsOneWidget,
    );

    final threadRect = tester.getRect(finders.thread);
    final priorityRect = tester.getRect(finders.priority);
    final metaRowRect = tester.getRect(finders.metaRow);
    final unreadRect = tester.getRect(finders.unreadMeta!);

    expect(priorityRect.right, lessThanOrEqualTo(threadRect.right));
    expect(priorityRect.bottom, lessThanOrEqualTo(metaRowRect.top));
    expect(unreadRect.right, lessThanOrEqualTo(metaRowRect.right));
    expect(unreadRect.bottom, lessThanOrEqualTo(metaRowRect.bottom));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread keeps blocked relation priority tag above meta row on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_blocked_relation_compact';
    const messageId = 'blocked-relation-message';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId),
      unreadCount: 1,
      createdAgo: const Duration(hours: 4),
      expiresIn: const Duration(hours: 3),
      intimacyPoints: 22,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: messageId,
          content: '关系受限失败消息应显示关系受限优先标签。',
          isMe: true,
          timestamp: now,
          status: MessageStatus.failed,
        ),
      ],
    );

    chatProvider.markMessageFailedForTesting(
      threadId,
      messageId,
      failureState: ChatDeliveryFailureState.blockedRelation,
    );
    await tester.pump();

    final finders = _findPriorityTagState(threadId, includeUnreadMeta: true);
    _expectBasePriorityTagState(tester, finders);
    expect(finders.unreadMeta, findsOneWidget);
    expect(find.text('关系受限'), findsOneWidget);
    expect(
      find.byKey(Key('messages-thread-delivery-badge-slot-$threadId')),
      findsOneWidget,
    );

    final threadRect = tester.getRect(finders.thread);
    final priorityRect = tester.getRect(finders.priority);
    final metaRowRect = tester.getRect(finders.metaRow);
    final unreadRect = tester.getRect(finders.unreadMeta!);

    expect(priorityRect.right, lessThanOrEqualTo(threadRect.right));
    expect(priorityRect.bottom, lessThanOrEqualTo(metaRowRect.top));
    expect(unreadRect.right, lessThanOrEqualTo(metaRowRect.right));
    expect(unreadRect.bottom, lessThanOrEqualTo(metaRowRect.bottom));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread keeps upload token invalid priority tag above meta row on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_upload_token_invalid_compact';
    const messageId = 'upload-token-invalid-message';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId),
      unreadCount: 1,
      createdAgo: const Duration(hours: 4),
      expiresIn: const Duration(hours: 3),
      intimacyPoints: 22,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: messageId,
          content: '上传凭证失效消息应显示上传凭证失效优先标签。',
          isMe: true,
          timestamp: now,
          status: MessageStatus.failed,
          type: MessageType.image,
        ),
      ],
    );

    chatProvider.markMessageFailedForTesting(
      threadId,
      messageId,
      failureState: ChatDeliveryFailureState.imageUploadTokenInvalid,
    );
    await tester.pump();

    final finders = _findPriorityTagState(threadId, includeUnreadMeta: true);
    _expectBasePriorityTagState(tester, finders);
    expect(finders.unreadMeta, findsOneWidget);
    expect(find.text('上传凭证失效'), findsOneWidget);
    expect(
      find.byKey(Key('messages-thread-delivery-badge-slot-$threadId')),
      findsOneWidget,
    );

    final threadRect = tester.getRect(finders.thread);
    final priorityRect = tester.getRect(finders.priority);
    final metaRowRect = tester.getRect(finders.metaRow);
    final unreadRect = tester.getRect(finders.unreadMeta!);

    expect(priorityRect.right, lessThanOrEqualTo(threadRect.right));
    expect(priorityRect.bottom, lessThanOrEqualTo(metaRowRect.top));
    expect(unreadRect.right, lessThanOrEqualTo(metaRowRect.right));
    expect(unreadRect.bottom, lessThanOrEqualTo(metaRowRect.bottom));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread keeps upload preparation failure priority tag above meta row on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_upload_prepare_failed_compact';
    const messageId = 'upload-prepare-failed-message';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId),
      unreadCount: 1,
      createdAgo: const Duration(hours: 4),
      expiresIn: const Duration(hours: 3),
      intimacyPoints: 22,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: messageId,
          content: '上传准备失败消息应显示上传准备失败优先标签。',
          isMe: true,
          timestamp: now,
          status: MessageStatus.failed,
          type: MessageType.image,
        ),
      ],
    );

    chatProvider.markMessageFailedForTesting(
      threadId,
      messageId,
      failureState: ChatDeliveryFailureState.imageUploadPreparationFailed,
    );
    await tester.pump();

    final finders = _findPriorityTagState(threadId, includeUnreadMeta: true);
    _expectBasePriorityTagState(tester, finders);
    expect(finders.unreadMeta, findsOneWidget);
    expect(find.text('上传准备失败'), findsOneWidget);
    expect(
      find.byKey(Key('messages-thread-delivery-badge-slot-$threadId')),
      findsOneWidget,
    );

    final threadRect = tester.getRect(finders.thread);
    final priorityRect = tester.getRect(finders.priority);
    final metaRowRect = tester.getRect(finders.metaRow);
    final unreadRect = tester.getRect(finders.unreadMeta!);

    expect(priorityRect.right, lessThanOrEqualTo(threadRect.right));
    expect(priorityRect.bottom, lessThanOrEqualTo(metaRowRect.top));
    expect(unreadRect.right, lessThanOrEqualTo(metaRowRect.right));
    expect(unreadRect.bottom, lessThanOrEqualTo(metaRowRect.bottom));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread keeps upload interrupted priority tag above meta row on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_upload_interrupted_compact';
    const messageId = 'upload-interrupted-message';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId),
      unreadCount: 1,
      createdAgo: const Duration(hours: 4),
      expiresIn: const Duration(hours: 3),
      intimacyPoints: 22,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: messageId,
          content: '上传中断消息应显示上传中断优先标签。',
          isMe: true,
          timestamp: now,
          status: MessageStatus.failed,
          type: MessageType.image,
        ),
      ],
    );

    chatProvider.markMessageFailedForTesting(
      threadId,
      messageId,
      failureState: ChatDeliveryFailureState.imageUploadInterrupted,
    );
    await tester.pump();

    final finders = _findPriorityTagState(threadId, includeUnreadMeta: true);
    _expectBasePriorityTagState(tester, finders);
    expect(finders.unreadMeta, findsOneWidget);
    expect(find.text('上传中断'), findsOneWidget);
    expect(
      find.byKey(Key('messages-thread-delivery-badge-slot-$threadId')),
      findsOneWidget,
    );

    final threadRect = tester.getRect(finders.thread);
    final priorityRect = tester.getRect(finders.priority);
    final metaRowRect = tester.getRect(finders.metaRow);
    final unreadRect = tester.getRect(finders.unreadMeta!);

    expect(priorityRect.right, lessThanOrEqualTo(threadRect.right));
    expect(priorityRect.bottom, lessThanOrEqualTo(metaRowRect.top));
    expect(unreadRect.right, lessThanOrEqualTo(metaRowRect.right));
    expect(unreadRect.bottom, lessThanOrEqualTo(metaRowRect.bottom));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread keeps reselect image priority tag above meta row on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_reselect_image_compact';
    const messageId = 'reselect-image-message';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId),
      unreadCount: 1,
      createdAgo: const Duration(hours: 4),
      expiresIn: const Duration(hours: 3),
      intimacyPoints: 22,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: messageId,
          content: '原图失效消息应显示重选图片优先标签。',
          isMe: true,
          timestamp: now,
          status: MessageStatus.failed,
          type: MessageType.image,
        ),
      ],
    );

    chatProvider.markMessageFailedForTesting(
      threadId,
      messageId,
      failureState: ChatDeliveryFailureState.imageReselectRequired,
    );
    await tester.pump();

    final finders = _findPriorityTagState(threadId, includeUnreadMeta: true);
    _expectBasePriorityTagState(tester, finders);
    expect(finders.unreadMeta, findsOneWidget);
    expect(find.text('重选图片'), findsNWidgets(2));
    expect(
      find.byKey(Key('messages-thread-delivery-badge-slot-$threadId')),
      findsOneWidget,
    );

    final threadRect = tester.getRect(finders.thread);
    final priorityRect = tester.getRect(finders.priority);
    final metaRowRect = tester.getRect(finders.metaRow);
    final unreadRect = tester.getRect(finders.unreadMeta!);

    expect(priorityRect.right, lessThanOrEqualTo(threadRect.right));
    expect(priorityRect.bottom, lessThanOrEqualTo(metaRowRect.top));
    expect(unreadRect.right, lessThanOrEqualTo(metaRowRect.right));
    expect(unreadRect.bottom, lessThanOrEqualTo(metaRowRect.bottom));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });
}
