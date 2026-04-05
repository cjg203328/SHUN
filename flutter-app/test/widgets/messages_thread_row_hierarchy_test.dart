import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';

import 'helpers/messages_thread_test_host.dart';

class _RowHierarchyFinders {
  const _RowHierarchyFinders({
    required this.thread,
    required this.titleRow,
    required this.previewRow,
    required this.priorityRow,
    required this.metaRow,
  });

  final Finder thread;
  final Finder titleRow;
  final Finder previewRow;
  final Finder priorityRow;
  final Finder metaRow;
}

_RowHierarchyFinders _findRowHierarchyState(String threadId) {
  return _RowHierarchyFinders(
    thread: find.byKey(Key('messages-thread-item-$threadId')),
    titleRow: find.byKey(Key('messages-thread-title-row-$threadId')),
    previewRow: find.byKey(Key('messages-thread-preview-row-$threadId')),
    priorityRow: find.byKey(Key('messages-thread-priority-row-$threadId')),
    metaRow: find.byKey(Key('messages-thread-meta-row-$threadId')),
  );
}

void _expectBaseRowHierarchyState(
  WidgetTester tester,
  _RowHierarchyFinders finders,
) {
  expect(finders.thread, findsOneWidget);
  expect(finders.titleRow, findsOneWidget);
  expect(finders.previewRow, findsOneWidget);
  expect(finders.priorityRow, findsOneWidget);
  expect(finders.metaRow, findsOneWidget);
  expect(find.text('发送失败'), findsNWidgets(2));
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
      'messages thread keeps title preview priority and meta rows ordered on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_row_hierarchy_compact';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(
        threadId,
        nickname: 'Hierarchy Compact User',
      ),
      unreadCount: 4,
      createdAgo: const Duration(hours: 20),
      expiresIn: const Duration(hours: 1, minutes: 15),
      intimacyPoints: 52,
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
          content: '这条失败消息需要保持四层行顺序稳定。',
          isMe: true,
          timestamp: now,
          status: MessageStatus.failed,
        ),
      ],
    );

    final finders = _findRowHierarchyState(threadId);
    _expectBaseRowHierarchyState(tester, finders);

    final threadRect = tester.getRect(finders.thread);
    final titleRect = tester.getRect(finders.titleRow);
    final previewRect = tester.getRect(finders.previewRow);
    final priorityRect = tester.getRect(finders.priorityRow);
    final metaRect = tester.getRect(finders.metaRow);

    expect(titleRect.right, lessThanOrEqualTo(threadRect.right));
    expect(previewRect.right, lessThanOrEqualTo(threadRect.right));
    expect(priorityRect.right, lessThanOrEqualTo(threadRect.right));
    expect(metaRect.right, lessThanOrEqualTo(threadRect.right));
    expect(titleRect.bottom, lessThanOrEqualTo(previewRect.top));
    expect(previewRect.bottom, lessThanOrEqualTo(priorityRect.top));
    expect(priorityRect.bottom, lessThanOrEqualTo(metaRect.top));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });
}
