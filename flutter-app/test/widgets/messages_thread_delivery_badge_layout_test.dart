import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';

import 'helpers/messages_thread_test_host.dart';

class _DeliveryBadgeFinders {
  const _DeliveryBadgeFinders({
    required this.thread,
    required this.previewRow,
    required this.metaRow,
    required this.badgeSlot,
    required this.unreadMeta,
    this.priority,
  });

  final Finder thread;
  final Finder previewRow;
  final Finder metaRow;
  final Finder badgeSlot;
  final Finder unreadMeta;
  final Finder? priority;
}

_DeliveryBadgeFinders _findDeliveryBadgeState(
  String threadId, {
  bool includePriority = false,
}) {
  return _DeliveryBadgeFinders(
    thread: find.byKey(Key('messages-thread-item-$threadId')),
    previewRow: find.byKey(Key('messages-thread-preview-row-$threadId')),
    metaRow: find.byKey(Key('messages-thread-meta-row-$threadId')),
    badgeSlot: find.byKey(Key('messages-thread-delivery-badge-slot-$threadId')),
    unreadMeta: find.byKey(Key('messages-thread-unread-slot-meta-$threadId')),
    priority: includePriority
        ? find.byKey(Key('messages-thread-priority-$threadId'))
        : null,
  );
}

void _expectBaseDeliveryBadgeState(
  WidgetTester tester,
  _DeliveryBadgeFinders finders,
) {
  expect(finders.thread, findsOneWidget);
  expect(finders.previewRow, findsOneWidget);
  expect(finders.metaRow, findsOneWidget);
  expect(finders.badgeSlot, findsOneWidget);
  expect(finders.unreadMeta, findsOneWidget);
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
      'messages thread keeps sending badge in preview row on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_delivery_sending_compact';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId),
      unreadCount: 4,
      createdAgo: const Duration(hours: 8),
      expiresIn: const Duration(hours: 1, minutes: 40),
      intimacyPoints: 66,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: 'sending-message',
          content: '这条发送中消息在小屏上也要保持层级清楚。',
          isMe: true,
          timestamp: now,
          status: MessageStatus.sending,
        ),
      ],
    );

    final finders = _findDeliveryBadgeState(threadId);
    _expectBaseDeliveryBadgeState(tester, finders);
    expect(find.text('发送中'), findsOneWidget);

    final threadRect = tester.getRect(finders.thread);
    final previewRowRect = tester.getRect(finders.previewRow);
    final metaRowRect = tester.getRect(finders.metaRow);
    final badgeRect = tester.getRect(finders.badgeSlot);

    expect(badgeRect.right, lessThanOrEqualTo(threadRect.right));
    expect(badgeRect.bottom, lessThanOrEqualTo(previewRowRect.bottom));
    expect(badgeRect.bottom, lessThanOrEqualTo(metaRowRect.top));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread keeps failure badge above priority and meta rows on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_delivery_failed_compact';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId),
      unreadCount: 3,
      createdAgo: const Duration(hours: 10),
      expiresIn: const Duration(hours: 1, minutes: 10),
      intimacyPoints: 34,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: 'failed-message',
          content: '这条失败消息在小屏上要保持三层结构。',
          isMe: true,
          timestamp: now,
          status: MessageStatus.failed,
        ),
      ],
    );

    final finders = _findDeliveryBadgeState(threadId, includePriority: true);
    _expectBaseDeliveryBadgeState(tester, finders);
    expect(finders.priority, findsOneWidget);
    expect(find.text('发送失败'), findsNWidgets(2));

    final threadRect = tester.getRect(finders.thread);
    final badgeRect = tester.getRect(finders.badgeSlot);
    final priorityRect = tester.getRect(finders.priority!);
    final metaRowRect = tester.getRect(finders.metaRow);

    expect(badgeRect.right, lessThanOrEqualTo(threadRect.right));
    expect(badgeRect.bottom, lessThanOrEqualTo(priorityRect.top));
    expect(priorityRect.bottom, lessThanOrEqualTo(metaRowRect.top));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });
}
