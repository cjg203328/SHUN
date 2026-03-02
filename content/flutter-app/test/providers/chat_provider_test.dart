import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';

import '../helpers/test_bootstrap.dart';

User _buildUser(String id) {
  return User(
    id: id,
    uid: 'SN$id',
    nickname: 'User-$id',
    avatar: '😀',
    distance: '2km',
    status: 'available',
    isOnline: true,
  );
}

ChatThread _buildThread(
  String id, {
  bool isFriend = false,
  DateTime? createdAt,
  DateTime? expiresAt,
  int intimacyPoints = 60,
}) {
  final now = DateTime.now();
  return ChatThread(
    id: id,
    otherUser: _buildUser(id),
    createdAt: createdAt ?? now.subtract(const Duration(minutes: 10)),
    expiresAt: expiresAt ?? now.add(const Duration(hours: 24)),
    intimacyPoints: intimacyPoints,
    isFriend: isFriend,
  );
}

void main() {
  setUp(() async {
    await initTestAppStorage();
  });

  test('sendMessage should add outgoing message immediately', () {
    final provider = ChatProvider();
    final thread = _buildThread('u_chat_1');
    provider.addThread(thread);

    provider.sendMessage(thread.id, 'hello');
    final messages = provider.getMessages(thread.id);

    expect(messages.length, 1);
    expect(messages.first.isMe, isTrue);
    expect(messages.first.content, 'hello');
    expect(messages.first.status, MessageStatus.sending);
  });

  test('deleteThread should clear messages and hide thread entry', () {
    final provider = ChatProvider();
    final thread = _buildThread('u_chat_2');
    provider.addThread(thread);
    provider.getMessages(thread.id).add(
          Message(
            id: 'm1',
            content: 'persisted',
            isMe: true,
            timestamp: DateTime.now(),
          ),
        );

    provider.deleteThread(thread.id);

    expect(provider.getMessages(thread.id), isEmpty);
    expect(provider.threads.containsKey(thread.id), isFalse);
  });

  test('restoreConversationAfterUnblock should refresh stranger expiry window',
      () {
    final provider = ChatProvider();
    final oldCreated = DateTime.now().subtract(const Duration(hours: 12));
    final oldExpires = DateTime.now().subtract(const Duration(hours: 1));
    final thread = _buildThread(
      'u_chat_3',
      createdAt: oldCreated,
      expiresAt: oldExpires,
      isFriend: false,
    );
    provider.addThread(thread);
    provider.deleteThread(thread.id);

    provider.restoreConversationAfterUnblock(thread.id);
    final restored = provider.getThread(thread.id)!;

    expect(provider.threads.containsKey(thread.id), isTrue);
    expect(restored.createdAt.isAfter(oldCreated), isTrue);
    expect(restored.expiresAt.isAfter(DateTime.now()), isTrue);
    expect(restored.isUnfollowed, isFalse);
  });

  test('restoreConversationAfterUnblock should keep friend timeline unchanged',
      () {
    final provider = ChatProvider();
    final oldCreated = DateTime.now().subtract(const Duration(hours: 10));
    final oldExpires = DateTime.now().add(const Duration(hours: 10));
    final thread = _buildThread(
      'u_chat_4',
      createdAt: oldCreated,
      expiresAt: oldExpires,
      isFriend: true,
    );
    provider.addThread(thread);
    provider.deleteThread(thread.id);

    provider.restoreConversationAfterUnblock(thread.id);
    final restored = provider.getThread(thread.id)!;

    expect(restored.createdAt, oldCreated);
    expect(restored.expiresAt, oldExpires);
    expect(provider.threads.containsKey(thread.id), isTrue);
  });

  test('restoreConversationAfterUnblock should work when thread id != user id',
      () {
    final provider = ChatProvider();
    final user = _buildUser('u_chat_6');
    final thread = ChatThread(
      id: 'thread_custom_6',
      otherUser: user,
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      expiresAt: DateTime.now().add(const Duration(hours: 8)),
      intimacyPoints: 90,
    );
    provider.addThread(thread);
    provider.deleteThread(thread.id);

    provider.restoreConversationAfterUnblock(user.id);

    expect(provider.threads.containsKey(thread.id), isTrue);
  });

  test('markImageAsRead should mark burn-after-reading image as read', () {
    final provider = ChatProvider();
    final thread = _buildThread('u_chat_5');
    provider.addThread(thread);
    provider.getMessages(thread.id).add(
          Message(
            id: 'burn-1',
            content: '[img]',
            isMe: false,
            timestamp: DateTime.now(),
            type: MessageType.image,
            isBurnAfterReading: true,
            isRead: false,
          ),
        );

    provider.markImageAsRead(thread.id, 'burn-1');

    expect(provider.getMessages(thread.id).first.isRead, isTrue);
  });

  test('sortedThreads should order by latest activity desc', () {
    final provider = ChatProvider();
    final first = _buildThread(
      'u_chat_7',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    );
    final second = _buildThread(
      'u_chat_8',
      createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
    );
    provider.addThread(first);
    provider.addThread(second);

    provider.sendMessage(first.id, 'hello');

    final sorted = provider.sortedThreads;
    expect(sorted.first.id, first.id);
  });
}
