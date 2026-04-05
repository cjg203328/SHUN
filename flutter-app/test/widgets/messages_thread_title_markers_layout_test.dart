import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/friend_provider.dart';

import 'helpers/messages_thread_test_host.dart';

class _TitleMarkerFinders {
  const _TitleMarkerFinders({
    required this.thread,
    required this.titleRow,
    required this.previewRow,
    required this.friendSlot,
    required this.pinnedSlot,
    required this.time,
  });

  final Finder thread;
  final Finder titleRow;
  final Finder previewRow;
  final Finder friendSlot;
  final Finder pinnedSlot;
  final Finder time;
}

_TitleMarkerFinders _findTitleMarkerState(String threadId) {
  return _TitleMarkerFinders(
    thread: find.byKey(Key('messages-thread-item-$threadId')),
    titleRow: find.byKey(Key('messages-thread-title-row-$threadId')),
    previewRow: find.byKey(Key('messages-thread-preview-row-$threadId')),
    friendSlot: find.byKey(Key('messages-thread-friend-tag-slot-$threadId')),
    pinnedSlot: find.byKey(Key('messages-thread-pinned-icon-slot-$threadId')),
    time: find.byKey(Key('messages-thread-last-time-$threadId')),
  );
}

void _expectBaseTitleMarkerState(
  WidgetTester tester,
  _TitleMarkerFinders finders,
) {
  expect(finders.thread, findsOneWidget);
  expect(finders.titleRow, findsOneWidget);
  expect(finders.previewRow, findsOneWidget);
  expect(finders.friendSlot, findsOneWidget);
  expect(finders.pinnedSlot, findsOneWidget);
  expect(finders.time, findsOneWidget);
  expect(find.text('好友'), findsOneWidget);
  expect(find.byIcon(Icons.push_pin), findsOneWidget);
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
      'messages thread keeps friend tag and pinned icon in title row on regular width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(430, 900));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_title_regular';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(
        threadId,
        nickname: 'Regular Friend Marker User',
      ),
      createdAgo: const Duration(hours: 6),
      expiresIn: const Duration(hours: 12),
      intimacyPoints: 120,
      isFriend: true,
      now: now,
    );
    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      pinThread: true,
      messages: <Message>[
        Message(
          id: 'regular-title-message',
          content: '常规宽度下标题标记应保持在标题行。',
          isMe: false,
          timestamp: now,
          status: MessageStatus.sent,
        ),
      ],
    );

    final finders = _findTitleMarkerState(threadId);
    _expectBaseTitleMarkerState(tester, finders);

    final threadRect = tester.getRect(finders.thread);
    final titleRowRect = tester.getRect(finders.titleRow);
    final previewRowRect = tester.getRect(finders.previewRow);
    final friendRect = tester.getRect(finders.friendSlot);
    final pinRect = tester.getRect(finders.pinnedSlot);
    final timeRect = tester.getRect(finders.time);

    expect(friendRect.right, lessThanOrEqualTo(threadRect.right));
    expect(pinRect.right, lessThanOrEqualTo(timeRect.left));
    expect(friendRect.bottom, lessThanOrEqualTo(titleRowRect.bottom));
    expect(pinRect.bottom, lessThanOrEqualTo(titleRowRect.bottom));
    expect(titleRowRect.bottom, lessThanOrEqualTo(previewRowRect.top));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread keeps friend tag and pinned icon above preview row on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_title_compact';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(
        threadId,
        nickname: 'Compact Friend Marker With Longer Name',
      ),
      createdAgo: const Duration(hours: 5),
      expiresIn: const Duration(hours: 10),
      intimacyPoints: 108,
      isFriend: true,
      now: now,
    );
    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      pinThread: true,
      messages: <Message>[
        Message(
          id: 'compact-title-message',
          content: '紧凑宽度下标题标记仍应稳稳待在预览行上方。',
          isMe: false,
          timestamp: now,
          status: MessageStatus.sent,
        ),
      ],
    );

    final finders = _findTitleMarkerState(threadId);
    _expectBaseTitleMarkerState(tester, finders);

    final threadRect = tester.getRect(finders.thread);
    final titleRowRect = tester.getRect(finders.titleRow);
    final previewRowRect = tester.getRect(finders.previewRow);
    final friendRect = tester.getRect(finders.friendSlot);
    final pinRect = tester.getRect(finders.pinnedSlot);

    expect(friendRect.right, lessThanOrEqualTo(threadRect.right));
    expect(pinRect.right, lessThanOrEqualTo(threadRect.right));
    expect(friendRect.bottom, lessThanOrEqualTo(titleRowRect.bottom));
    expect(pinRect.bottom, lessThanOrEqualTo(titleRowRect.bottom));
    expect(titleRowRect.bottom, lessThanOrEqualTo(previewRowRect.top));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread keeps time visible to the right of title markers on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_title_compact_time';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(
        threadId,
        nickname: 'Compact Friend Marker With Much Longer Title Copy',
      ),
      createdAgo: const Duration(hours: 5),
      expiresIn: const Duration(hours: 10),
      intimacyPoints: 108,
      isFriend: true,
      now: now,
    );
    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      pinThread: true,
      messages: <Message>[
        Message(
          id: 'compact-title-time-message',
          content: '紧凑宽度下时间仍应保持在标题行右侧。',
          isMe: false,
          timestamp: now,
          status: MessageStatus.sent,
        ),
      ],
    );

    final finders = _findTitleMarkerState(threadId);
    _expectBaseTitleMarkerState(tester, finders);

    final threadRect = tester.getRect(finders.thread);
    final titleRowRect = tester.getRect(finders.titleRow);
    final friendRect = tester.getRect(finders.friendSlot);
    final pinRect = tester.getRect(finders.pinnedSlot);
    final timeRect = tester.getRect(finders.time);

    expect(friendRect.right, lessThanOrEqualTo(threadRect.right));
    expect(pinRect.right, lessThanOrEqualTo(timeRect.left));
    expect(timeRect.right, lessThanOrEqualTo(threadRect.right));
    expect(timeRect.bottom, lessThanOrEqualTo(titleRowRect.bottom));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread keeps long day-based time copy to the right of title markers on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_title_compact_day_time';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(
        threadId,
        nickname: 'Compact Friend Marker With Day Based Time Copy',
      ),
      createdAgo: const Duration(hours: 8),
      expiresIn: const Duration(hours: 10),
      intimacyPoints: 108,
      isFriend: true,
      now: now,
    );
    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      pinThread: true,
      messages: <Message>[
        Message(
          id: 'compact-title-day-time-message',
          content: '紧凑宽度下更长的天数时间文案也应留在标题行右侧。',
          isMe: false,
          timestamp: now.subtract(const Duration(days: 12)),
          status: MessageStatus.sent,
        ),
      ],
    );

    final finders = _findTitleMarkerState(threadId);
    _expectBaseTitleMarkerState(tester, finders);
    expect(find.text('12天前'), findsOneWidget);

    final threadRect = tester.getRect(finders.thread);
    final titleRowRect = tester.getRect(finders.titleRow);
    final previewRowRect = tester.getRect(finders.previewRow);
    final friendRect = tester.getRect(finders.friendSlot);
    final pinRect = tester.getRect(finders.pinnedSlot);
    final timeRect = tester.getRect(finders.time);

    expect(friendRect.right, lessThanOrEqualTo(threadRect.right));
    expect(pinRect.right, lessThanOrEqualTo(timeRect.left));
    expect(timeRect.right, lessThanOrEqualTo(threadRect.right));
    expect(timeRect.bottom, lessThanOrEqualTo(titleRowRect.bottom));
    expect(titleRowRect.bottom, lessThanOrEqualTo(previewRowRect.top));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });

  testWidgets(
      'messages thread keeps friend tag and pinned icon stable when no recent message time is shown on compact width',
      (tester) async {
    setMessagesThreadViewport(tester, const Size(360, 640));

    final chatProvider = ChatProvider();
    final friendProvider = FriendProvider();
    final now = DateTime.now();
    const threadId = 'u_messages_title_compact_empty_time';
    final thread = buildMessagesThread(
      id: threadId,
      otherUser: buildMessagesThreadUser(
        threadId,
        nickname: 'Compact Friend Marker Without Recent Message Time',
      ),
      createdAgo: const Duration(hours: 6),
      expiresIn: const Duration(hours: 10),
      intimacyPoints: 108,
      isFriend: true,
      now: now,
    );
    await pumpMessagesThreadScene(
      tester,
      chatProvider: chatProvider,
      friendProvider: friendProvider,
      thread: thread,
      pinThread: true,
    );

    final finders = _findTitleMarkerState(threadId);
    _expectBaseTitleMarkerState(tester, finders);
    expect(tester.widget<Text>(finders.time).data, isEmpty);

    final threadRect = tester.getRect(finders.thread);
    final titleRowRect = tester.getRect(finders.titleRow);
    final previewRowRect = tester.getRect(finders.previewRow);
    final friendRect = tester.getRect(finders.friendSlot);
    final pinRect = tester.getRect(finders.pinnedSlot);
    final timeRect = tester.getRect(finders.time);

    expect(friendRect.right, lessThanOrEqualTo(threadRect.right));
    expect(pinRect.right, lessThanOrEqualTo(threadRect.right));
    expect(timeRect.right, lessThanOrEqualTo(threadRect.right));
    expect(pinRect.left, greaterThanOrEqualTo(friendRect.right));
    expect(titleRowRect.bottom, lessThanOrEqualTo(previewRowRect.top));

    await disposeMessagesThreadHost(tester, chatProvider, friendProvider);
  });
}
