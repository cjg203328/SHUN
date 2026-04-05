import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';

import 'helpers/messages_thread_test_host.dart';

class _IntimacyChipFinders {
  const _IntimacyChipFinders({
    required this.thread,
    required this.previewSlot,
    required this.metaSlot,
    required this.chip,
    this.metaRow,
    this.unreadMeta,
  });

  final Finder thread;
  final Finder previewSlot;
  final Finder metaSlot;
  final Finder chip;
  final Finder? metaRow;
  final Finder? unreadMeta;
}

_IntimacyChipFinders _findIntimacyChipState(
  String threadId, {
  bool includeMeta = false,
}) {
  return _IntimacyChipFinders(
    thread: find.byKey(Key('messages-thread-item-$threadId')),
    previewSlot:
        find.byKey(Key('messages-thread-intimacy-slot-preview-$threadId')),
    metaSlot: find.byKey(Key('messages-thread-intimacy-slot-meta-$threadId')),
    chip: find.byKey(Key('messages-thread-intimacy-$threadId')),
    metaRow: includeMeta
        ? find.byKey(Key('messages-thread-meta-row-$threadId'))
        : null,
    unreadMeta: includeMeta
        ? find.byKey(Key('messages-thread-unread-slot-meta-$threadId'))
        : null,
  );
}

void _expectBaseIntimacyChipState(
  WidgetTester tester,
  _IntimacyChipFinders finders,
) {
  expect(finders.thread, findsOneWidget);
  expect(finders.chip, findsOneWidget);
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
      'messages thread keeps intimacy chip in preview row on regular width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(430, 900));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_intimacy_regular';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId),
      unreadCount: 2,
      createdAgo: const Duration(hours: 4),
      expiresIn: const Duration(hours: 8),
      intimacyPoints: 91,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: 'regular-message',
          content: '常规宽度下亲密度徽标应留在预览行。',
          isMe: false,
          timestamp: now,
          status: MessageStatus.sent,
        ),
      ],
    );

    final finders = _findIntimacyChipState(threadId);
    _expectBaseIntimacyChipState(tester, finders);
    expect(finders.previewSlot, findsOneWidget);
    expect(finders.metaSlot, findsNothing);
    expect(find.text('91'), findsOneWidget);

    final threadRect = tester.getRect(finders.thread);
    final previewRect = tester.getRect(finders.previewSlot);
    final chipRect = tester.getRect(finders.chip);

    expect(chipRect.right, lessThanOrEqualTo(threadRect.right));
    expect(chipRect.bottom, lessThanOrEqualTo(previewRect.bottom));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread moves intimacy chip into meta row on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_intimacy_compact';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId),
      unreadCount: 4,
      createdAgo: const Duration(hours: 20),
      expiresIn: const Duration(hours: 1, minutes: 15),
      intimacyPoints: 88,
      now: now,
    );

    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      messages: <Message>[
        Message(
          id: 'compact-message',
          content: '紧凑宽度下亲密度徽标应下沉到底部时效行。',
          isMe: false,
          timestamp: now,
          status: MessageStatus.sent,
        ),
      ],
    );

    final finders = _findIntimacyChipState(threadId, includeMeta: true);
    _expectBaseIntimacyChipState(tester, finders);
    expect(finders.previewSlot, findsNothing);
    expect(finders.metaSlot, findsOneWidget);
    expect(finders.metaRow, findsOneWidget);
    expect(finders.unreadMeta, findsOneWidget);
    expect(find.text('88'), findsOneWidget);

    final threadRect = tester.getRect(finders.thread);
    final metaRowRect = tester.getRect(finders.metaRow!);
    final unreadRect = tester.getRect(finders.unreadMeta!);
    final chipRect = tester.getRect(finders.chip);

    expect(chipRect.right, lessThanOrEqualTo(threadRect.right));
    expect(unreadRect.right, lessThanOrEqualTo(chipRect.left));
    expect(chipRect.bottom, lessThanOrEqualTo(metaRowRect.bottom));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });
}
