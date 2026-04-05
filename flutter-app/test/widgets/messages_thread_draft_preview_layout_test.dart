import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';

import 'helpers/messages_thread_test_host.dart';

class _DraftPreviewFinders {
  const _DraftPreviewFinders({
    required this.draft,
    required this.metaRow,
    required this.unreadMeta,
    this.priority,
  });

  final Finder draft;
  final Finder metaRow;
  final Finder unreadMeta;
  final Finder? priority;
}

_DraftPreviewFinders _findDraftPreviewState(
  String threadId, {
  bool includePriority = false,
}) {
  return _DraftPreviewFinders(
    draft: find.byKey(Key('messages-thread-draft-slot-$threadId')),
    metaRow: find.byKey(Key('messages-thread-meta-row-$threadId')),
    unreadMeta: find.byKey(Key('messages-thread-unread-slot-meta-$threadId')),
    priority: includePriority
        ? find.byKey(Key('messages-thread-priority-$threadId'))
        : null,
  );
}

void _expectBaseDraftPreviewState(
  WidgetTester tester,
  _DraftPreviewFinders finders,
) {
  expect(finders.draft, findsOneWidget);
  expect(finders.metaRow, findsOneWidget);
  expect(finders.unreadMeta, findsOneWidget);
  expect(find.text('草稿'), findsOneWidget);
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
      'messages thread keeps draft preview and hides sending badge on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_draft_sending_compact';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId),
      unreadCount: 4,
      createdAgo: const Duration(hours: 8),
      expiresIn: const Duration(hours: 1, minutes: 45),
      intimacyPoints: 58,
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
          content: '这条发送中消息不该压过草稿预览。',
          isMe: true,
          timestamp: now,
          status: MessageStatus.sending,
        ),
      ],
      draft: '这是一条还没发出去的新草稿',
    );

    final finders = _findDraftPreviewState(threadId);
    _expectBaseDraftPreviewState(tester, finders);
    expect(find.text('这是一条还没发出去的新草稿'), findsOneWidget);
    expect(
      find.byKey(Key('messages-thread-delivery-badge-slot-$threadId')),
      findsNothing,
    );
    expect(find.text('发送中'), findsNothing);

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread keeps draft preview while failure priority remains visible on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_draft_failed_compact';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(threadId),
      unreadCount: 3,
      createdAgo: const Duration(hours: 9),
      expiresIn: const Duration(hours: 1, minutes: 5),
      intimacyPoints: 26,
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
          content: '这条失败消息不该顶掉草稿预览。',
          isMe: true,
          timestamp: now,
          status: MessageStatus.failed,
        ),
      ],
      draft: '这条草稿应继续留在预览行',
    );

    final finders = _findDraftPreviewState(threadId, includePriority: true);
    _expectBaseDraftPreviewState(tester, finders);
    expect(finders.priority, findsOneWidget);
    expect(find.text('这条草稿应继续留在预览行'), findsOneWidget);
    expect(
      find.byKey(Key('messages-thread-delivery-badge-slot-$threadId')),
      findsNothing,
    );
    expect(find.text('发送失败'), findsOneWidget);
    expect(find.text('草稿待发送'), findsNothing);

    final draftRect = tester.getRect(finders.draft);
    final priorityRect = tester.getRect(finders.priority!);
    final metaRowRect = tester.getRect(finders.metaRow);

    expect(draftRect.bottom, lessThanOrEqualTo(priorityRect.top));
    expect(priorityRect.bottom, lessThanOrEqualTo(metaRowRect.top));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });
}
