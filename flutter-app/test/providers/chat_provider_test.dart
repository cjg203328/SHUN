import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/models/models.dart';
import 'package:sunliao/providers/chat_provider.dart';
import 'package:sunliao/providers/notification_center_provider.dart';
import 'package:sunliao/repositories/app_data_repository.dart';
import 'package:sunliao/services/chat_service.dart';
import 'package:sunliao/services/chat_socket_service.dart';
import 'package:sunliao/services/media_upload_service.dart';

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

Future<File> _createTestImageFile(String name) async {
  const pixelBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0S8AAAAASUVORK5CYII=';
  final bytes = base64Decode(pixelBase64);
  final file = File('${Directory.systemTemp.path}\\$name.png');
  await file.writeAsBytes(bytes, flush: true);
  return file;
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

  test('draft should be saved, cleared and migrated with upgraded thread',
      () async {
    final localThread = _buildThread('u_chat_draft_local');
    final remoteThread = ChatThread(
      id: 'th_chat_draft_remote',
      otherUser: localThread.otherUser,
      createdAt: localThread.createdAt,
      expiresAt: localThread.expiresAt,
      intimacyPoints: localThread.intimacyPoints,
    );
    final provider = ChatProvider(
      chatService: _FakeChatService(
        directThreadsByUserId: {localThread.otherUser.id: remoteThread},
        hasSessionOverride: true,
      ),
    );
    addTearDown(provider.dispose);

    provider.addThread(localThread);
    provider.saveDraft(localThread.id, '还没发出的草稿');

    expect(provider.draftForThread(localThread.id), '还没发出的草稿');

    await provider.ensureDirectThreadForUser(localThread.otherUser);

    expect(provider.draftForThread(localThread.id), '还没发出的草稿');
    expect(provider.draftForThread(remoteThread.id), '还没发出的草稿');

    provider.clearDraft(remoteThread.id);
    expect(provider.draftForThread(localThread.id), isEmpty);
    expect(provider.draftForThread(remoteThread.id), isEmpty);
  });

  test('sendMessage should ignore rapid duplicate pending text submit', () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_dup_send');
    provider.addThread(thread);

    final firstQueued = provider.sendMessage(thread.id, 'hello again');
    final secondQueued = provider.sendMessage(thread.id, 'hello again');

    expect(firstQueued, isTrue);
    expect(secondQueued, isFalse);
    expect(provider.getMessages(thread.id), hasLength(1));
    expect(provider.getMessages(thread.id).first.content, 'hello again');
  });

  test('sendMessage should allow same text after pending message is resolved',
      () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_dup_send_resolved');
    provider.addThread(thread);

    expect(provider.sendMessage(thread.id, 'same text'), isTrue);
    final firstMessage = provider.getMessages(thread.id).first;
    provider.getMessages(thread.id)[0] = firstMessage.copyWith(
      status: MessageStatus.sent,
    );

    final secondQueued = provider.sendMessage(thread.id, 'same text');

    expect(secondQueued, isTrue);
    expect(provider.getMessages(thread.id), hasLength(2));
  });

  test('sendImageMessage should ignore rapid duplicate image submit', () async {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_dup_image');
    provider.addThread(thread);
    final imageFile = await _createTestImageFile('dup_image_submit');

    final firstQueued = await provider.sendImageMessage(
      thread.id,
      imageFile,
      ImageQuality.compressed,
      false,
    );
    final secondQueued = await provider.sendImageMessage(
      thread.id,
      imageFile,
      ImageQuality.compressed,
      false,
    );

    expect(firstQueued, isTrue);
    expect(secondQueued, isFalse);
    expect(provider.getMessages(thread.id), hasLength(1));
    expect(provider.getMessages(thread.id).first.type, MessageType.image);
  });

  test('sendImageMessage should allow same image after duplicate window',
      () async {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_dup_image_late');
    provider.addThread(thread);
    final imageFile = await _createTestImageFile('dup_image_submit_late');

    expect(
      await provider.sendImageMessage(
        thread.id,
        imageFile,
        ImageQuality.compressed,
        false,
      ),
      isTrue,
    );

    await Future<void>.delayed(const Duration(milliseconds: 900));

    final secondQueued = await provider.sendImageMessage(
      thread.id,
      imageFile,
      ImageQuality.compressed,
      false,
    );

    expect(secondQueued, isTrue);
    expect(provider.getMessages(thread.id), hasLength(2));
  });

  test('sendMessage should reject deleted or expired thread', () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final deletedThread = _buildThread('u_chat_send_deleted');
    final expiredThread = _buildThread(
      'u_chat_send_expired',
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    provider.addThread(deletedThread);
    provider.addThread(expiredThread);

    provider.deleteThread(deletedThread.id);

    expect(provider.sendMessage(deletedThread.id, 'blocked'), isFalse);
    expect(provider.sendMessage(expiredThread.id, 'blocked'), isFalse);
  });

  test('sendImageMessage should reject deleted or expired thread', () async {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final deletedThread = _buildThread('u_chat_image_deleted');
    final expiredThread = _buildThread(
      'u_chat_image_expired',
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    final imageFile = await _createTestImageFile('blocked_image_submit');
    provider.addThread(deletedThread);
    provider.addThread(expiredThread);

    provider.deleteThread(deletedThread.id);

    expect(
      await provider.sendImageMessage(
        deletedThread.id,
        imageFile,
        ImageQuality.compressed,
        false,
      ),
      isFalse,
    );
    expect(
      await provider.sendImageMessage(
        expiredThread.id,
        imageFile,
        ImageQuality.compressed,
        false,
      ),
      isFalse,
    );
  });

  test('sendImageMessage should resolve local thread to remote thread',
      () async {
    final localThread = _buildThread('u_chat_image_local');
    final remoteThread = ChatThread(
      id: 'th_chat_image_remote',
      otherUser: localThread.otherUser,
      createdAt: localThread.createdAt,
      expiresAt: localThread.expiresAt,
      intimacyPoints: localThread.intimacyPoints,
    );
    final fakeChatService = _FakeChatService(
      directThreadsByUserId: {localThread.otherUser.id: remoteThread},
      hasSessionOverride: true,
    );
    final fakeSocketService = _FakeChatSocketService();
    final provider = ChatProvider(
      chatService: fakeChatService,
      chatSocketService: fakeSocketService,
      mediaUploadService: _FakeMediaUploadService(
        preparedUploadBuilder: (threadId, imageFile) =>
            const PreparedChatImageUpload(
          sendKey: 'chat/object-key-1',
          previewPath: 'preview-path',
          isRemotePrepared: true,
        ),
      ),
    );
    addTearDown(provider.dispose);
    provider.addThread(localThread);
    final imageFile = await _createTestImageFile('remote_image_thread');

    final queued = await provider.sendImageMessage(
      localThread.id,
      imageFile,
      ImageQuality.compressed,
      false,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(queued, isTrue);
    expect(fakeSocketService.sendImageCalls[remoteThread.id], 1);
    expect(fakeSocketService.sendImageCalls[localThread.id], isNull);
    expect(provider.threads.containsKey(remoteThread.id), isTrue);
    expect(provider.threads.containsKey(localThread.id), isFalse);
    expect(provider.getMessages(remoteThread.id), hasLength(1));
    expect(provider.getMessages(remoteThread.id).first.type, MessageType.image);
  });

  test('sendImageMessage should fail locally when remote upload prepare fails',
      () async {
    final remoteThread = _buildThread('th_chat_image_prepare_fail');
    final fakeChatService = _FakeChatService(
      threads: [remoteThread],
      hasSessionOverride: true,
    );
    final fakeSocketService = _FakeChatSocketService();
    final provider = ChatProvider(
      chatService: fakeChatService,
      chatSocketService: fakeSocketService,
      mediaUploadService: _FakeMediaUploadService(
        preparedUploadBuilder: (threadId, imageFile) => PreparedChatImageUpload(
          sendKey: imageFile.path,
          previewPath: imageFile.path,
          isRemotePrepared: false,
        ),
      ),
    );
    addTearDown(provider.dispose);
    provider.addThread(remoteThread);
    final imageFile = await _createTestImageFile('image_prepare_fail');

    final queued = await provider.sendImageMessage(
      remoteThread.id,
      imageFile,
      ImageQuality.compressed,
      false,
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(queued, isTrue);
    expect(fakeSocketService.sendImageCalls[remoteThread.id], isNull);
    expect(provider.getMessages(remoteThread.id), hasLength(1));
    expect(
      provider.getMessages(remoteThread.id).first.status,
      MessageStatus.failed,
    );
    expect(
      provider.getMessages(remoteThread.id).first.imagePath,
      isNotEmpty,
    );
  });

  test('upgraded thread should remain accessible from old local thread id',
      () async {
    final localThread = _buildThread('u_chat_alias_local');
    final remoteThread = ChatThread(
      id: 'th_chat_alias_remote',
      otherUser: localThread.otherUser,
      createdAt: localThread.createdAt,
      expiresAt: localThread.expiresAt,
      intimacyPoints: localThread.intimacyPoints,
    );
    final provider = ChatProvider(
      chatService: _FakeChatService(
        directThreadsByUserId: {localThread.otherUser.id: remoteThread},
        hasSessionOverride: true,
      ),
    );
    addTearDown(provider.dispose);
    provider.addThread(localThread);
    provider.getMessages(localThread.id).add(
          Message(
            id: 'alias-message-1',
            content: '升级后旧路由也要能访问',
            isMe: true,
            timestamp: DateTime.now(),
            status: MessageStatus.sent,
          ),
        );

    final ensuredThread = await provider.ensureDirectThreadForUser(
      localThread.otherUser,
    );

    expect(ensuredThread.id, remoteThread.id);
    expect(provider.getThread(localThread.id)?.id, remoteThread.id);
    expect(provider.getMessages(localThread.id), hasLength(1));
    expect(provider.getMessages(localThread.id).first.id, 'alias-message-1');
  });

  test(
      'remote thread should remain accessible by user id after restart-like state',
      () {
    final remoteThread = _buildThread('th_chat_restart_remote');
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    provider.addThread(
      ChatThread(
        id: remoteThread.id,
        otherUser: User(
          id: 'u_chat_restart_user',
          uid: remoteThread.otherUser.uid,
          nickname: remoteThread.otherUser.nickname,
          avatar: remoteThread.otherUser.avatar,
          distance: remoteThread.otherUser.distance,
          status: remoteThread.otherUser.status,
          isOnline: remoteThread.otherUser.isOnline,
        ),
        createdAt: remoteThread.createdAt,
        expiresAt: remoteThread.expiresAt,
        intimacyPoints: remoteThread.intimacyPoints,
      ),
    );

    expect(provider.getThread('u_chat_restart_user')?.id, remoteThread.id);
    expect(provider.canonicalThreadId('u_chat_restart_user'), remoteThread.id);
    expect(
      provider.routeThreadId(userId: 'u_chat_restart_user'),
      remoteThread.id,
    );
  });

  test('routeThreadId should prefer thread id and fall back to user id',
      () async {
    final localThread = _buildThread('u_chat_route_local');
    final remoteThread = ChatThread(
      id: 'th_chat_route_remote',
      otherUser: localThread.otherUser,
      createdAt: localThread.createdAt,
      expiresAt: localThread.expiresAt,
      intimacyPoints: localThread.intimacyPoints,
    );
    final provider = ChatProvider(
      chatService: _FakeChatService(
        directThreadsByUserId: {localThread.otherUser.id: remoteThread},
        hasSessionOverride: true,
      ),
    );
    addTearDown(provider.dispose);
    provider.addThread(localThread);

    await provider.ensureDirectThreadForUser(localThread.otherUser);

    expect(
      provider.routeThreadId(
        threadId: localThread.id,
        userId: localThread.otherUser.id,
      ),
      remoteThread.id,
    );
    expect(
      provider.routeThreadId(userId: localThread.otherUser.id),
      remoteThread.id,
    );
  });

  test('thread state updates should resolve user id to remote thread', () {
    final remoteThread = ChatThread(
      id: 'th_chat_state_remote',
      otherUser: _buildUser('u_chat_state_user'),
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      intimacyPoints: 60,
      isFriend: true,
    );
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    provider.addThread(remoteThread);

    provider.unfollowFriend('u_chat_state_user');

    final updatedThread = provider.getThread(remoteThread.id);
    expect(updatedThread, isNotNull);
    expect(updatedThread!.isUnfollowed, isTrue);
    expect(updatedThread.messagesSinceUnfollow, 0);
  });

  test('handleFriendRemoved should clear friend state without unfollow limit',
      () {
    final remoteThread = ChatThread(
      id: 'th_chat_friend_removed_remote',
      otherUser: _buildUser('u_chat_friend_removed_user'),
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      intimacyPoints: 80,
      isFriend: true,
      isUnfollowed: true,
      messagesSinceUnfollow: 2,
    );
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    provider.addThread(remoteThread);

    provider.handleFriendRemoved('u_chat_friend_removed_user');

    final updatedThread = provider.getThread(remoteThread.id);
    expect(updatedThread, isNotNull);
    expect(updatedThread!.isFriend, isFalse);
    expect(updatedThread.isUnfollowed, isFalse);
    expect(updatedThread.messagesSinceUnfollow, 0);
  });

  test('handleFriendAccepted should promote thread to friend state', () {
    final remoteThread = ChatThread(
      id: 'th_chat_friend_accept_remote',
      otherUser: _buildUser('u_chat_friend_accept_user'),
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      intimacyPoints: 120,
      isFriend: false,
      isUnfollowed: true,
      messagesSinceUnfollow: 2,
    );
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    provider.addThread(remoteThread);

    provider.handleFriendAccepted('u_chat_friend_accept_user');

    final updatedThread = provider.getThread(remoteThread.id);
    expect(updatedThread, isNotNull);
    expect(updatedThread!.isFriend, isTrue);
    expect(updatedThread.isUnfollowed, isFalse);
    expect(updatedThread.messagesSinceUnfollow, 0);
  });

  test('syncFriendRelationships should promote existing thread to friend state',
      () {
    final remoteThread = ChatThread(
      id: 'th_chat_friend_sync_remote',
      otherUser: _buildUser('u_chat_friend_sync_user'),
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      intimacyPoints: 40,
      isFriend: false,
    );
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    provider.addThread(remoteThread);

    provider.syncFriendRelationships({'u_chat_friend_sync_user'});

    final updatedThread = provider.getThread(remoteThread.id);
    expect(updatedThread, isNotNull);
    expect(updatedThread!.isFriend, isTrue);
    expect(updatedThread.isUnfollowed, isFalse);
    expect(updatedThread.messagesSinceUnfollow, 0);
    expect(provider.threads.containsKey(remoteThread.id), isTrue);
  });

  test('syncFriendRelationships should demote stale friend thread', () {
    final remoteThread = ChatThread(
      id: 'th_chat_friend_sync_stale',
      otherUser: _buildUser('u_chat_friend_sync_stale_user'),
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      intimacyPoints: 160,
      isFriend: true,
    );
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    provider.addThread(remoteThread);

    provider.syncFriendRelationships(const <String>{});

    final updatedThread = provider.getThread(remoteThread.id);
    expect(updatedThread, isNotNull);
    expect(updatedThread!.isFriend, isFalse);
    expect(updatedThread.isUnfollowed, isFalse);
    expect(updatedThread.messagesSinceUnfollow, 0);
  });

  test(
      'sendMessage should not send after local thread is deleted mid-resolution',
      () async {
    final localThread = _buildThread('u_chat_text_local');
    final remoteThread = ChatThread(
      id: 'th_chat_text_remote',
      otherUser: localThread.otherUser,
      createdAt: localThread.createdAt,
      expiresAt: localThread.expiresAt,
      intimacyPoints: localThread.intimacyPoints,
    );
    final fakeChatService = _FakeChatService(
      directThreadsByUserId: {localThread.otherUser.id: remoteThread},
      createDirectThreadDelay: const Duration(milliseconds: 40),
      hasSessionOverride: true,
    );
    final fakeSocketService = _FakeChatSocketService();
    final provider = ChatProvider(
      chatService: fakeChatService,
      chatSocketService: fakeSocketService,
    );
    addTearDown(provider.dispose);
    provider.addThread(localThread);

    expect(
        provider.sendMessage(localThread.id, 'delete before resolve'), isTrue);
    provider.deleteThread(localThread.id);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(fakeSocketService.sendTextCalls[remoteThread.id], isNull);
    expect(provider.threads.containsKey(remoteThread.id), isFalse);
    expect(provider.getMessages(remoteThread.id), isEmpty);
  });

  test('deleteThread should clear messages and hide thread entry', () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
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

  test('deleteThread should ignore delayed remote load completion', () async {
    final thread = _buildThread('u_chat_delete_inflight');
    final fakeChatService = _FakeChatService(
      messagesByThread: {
        thread.id: [
          Message(
            id: 'delete-inflight-1',
            content: '这段历史不该在删除后回来',
            isMe: false,
            timestamp: DateTime.parse('2026-03-12T16:00:00.000'),
            status: MessageStatus.sent,
          ),
        ],
      },
      loadMessagesDelay: const Duration(milliseconds: 60),
    );
    final provider = ChatProvider(chatService: fakeChatService);
    addTearDown(provider.dispose);
    provider.addThread(thread);

    provider.setActiveThread(thread.id);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    provider.deleteThread(thread.id);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(provider.threads.containsKey(thread.id), isFalse);
    expect(provider.getMessages(thread.id), isEmpty);
  });

  test('restoring deleted thread should force remote reload after recent sync',
      () async {
    final thread = _buildThread('u_chat_restore_reload');
    final fakeChatService = _FakeChatService(
      threads: [thread],
      messagesByThread: {
        thread.id: [
          Message(
            id: 'restore-reload-1',
            content: '重新进入后要重新拉回来',
            isMe: false,
            timestamp: DateTime.parse('2026-03-12T16:05:00.000'),
            status: MessageStatus.sent,
          ),
        ],
      },
    );
    final provider = ChatProvider(chatService: fakeChatService);
    addTearDown(provider.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(provider.getMessages(thread.id), hasLength(1));

    provider.deleteThread(thread.id);
    await provider.ensureDirectThreadForUser(thread.otherUser);
    provider.setActiveThread(thread.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fakeChatService.loadMessagesCalls[thread.id], 2);
    expect(provider.getMessages(thread.id), hasLength(1));
    expect(provider.getMessages(thread.id).first.id, 'restore-reload-1');
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

  test(
      'restoreConversationAfterUnblock should force remote reload after recent sync',
      () async {
    final thread = _buildThread('u_chat_unblock_reload');
    final fakeChatService = _FakeChatService(
      threads: [thread],
      messagesByThread: {
        thread.id: [
          Message(
            id: 'unblock-reload-1',
            content: '取消拉黑后重新拉远端',
            isMe: false,
            timestamp: DateTime.parse('2026-03-12T16:08:00.000'),
            status: MessageStatus.sent,
          ),
        ],
      },
    );
    final provider = ChatProvider(chatService: fakeChatService);
    addTearDown(provider.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(fakeChatService.loadMessagesCalls[thread.id], 1);

    provider.restoreConversationAfterUnblock(thread.otherUser.id);
    provider.setActiveThread(thread.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fakeChatService.loadMessagesCalls[thread.id], 2);
    expect(provider.getMessages(thread.id), hasLength(1));
  });

  test('markImageAsRead should mark burn-after-reading image as read', () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
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

  test('markAsRead should not auto-sync unread burn-after-reading image',
      () async {
    await NotificationCenterProvider.instance.clearSession();
    final fakeChatService = _FakeChatService(hasSessionOverride: true);
    final fakeSocketService = _FakeChatSocketService();
    final baseThread = _buildThread('u_chat_burn_auto_read');
    final provider = ChatProvider(
      chatService: fakeChatService,
      chatSocketService: fakeSocketService,
    );
    addTearDown(() async {
      provider.dispose();
      await NotificationCenterProvider.instance.clearSession();
    });
    provider.addThread(
      ChatThread(
        id: baseThread.id,
        otherUser: baseThread.otherUser,
        createdAt: baseThread.createdAt,
        expiresAt: baseThread.expiresAt,
        intimacyPoints: baseThread.intimacyPoints,
        unreadCount: 2,
      ),
    );
    provider.getMessages(baseThread.id).addAll([
      Message(
        id: 'safe-1',
        content: '普通消息',
        isMe: false,
        timestamp: DateTime.parse('2026-03-12T15:00:00.000'),
      ),
      Message(
        id: 'burn-1',
        content: '[图片]',
        isMe: false,
        timestamp: DateTime.parse('2026-03-12T15:01:00.000'),
        type: MessageType.image,
        isBurnAfterReading: true,
      ),
    ]);
    await NotificationCenterProvider.instance.addChatMessageNotification(
      thread: provider.getThread(baseThread.id)!,
      message: provider.getMessages(baseThread.id).first,
    );
    await NotificationCenterProvider.instance.addChatMessageNotification(
      thread: provider.getThread(baseThread.id)!,
      message: provider.getMessages(baseThread.id).last,
    );

    provider.markAsRead(baseThread.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fakeSocketService.markReadCalls[baseThread.id], 1);
    expect(
      fakeSocketService.markReadMessageIdsByThread[baseThread.id],
      ['safe-1'],
    );
    expect(provider.getThread(baseThread.id)?.unreadCount, 1);
    final items = NotificationCenterProvider.instance.items
        .where((item) => item.threadId == baseThread.id)
        .toList(growable: false);
    expect(
      items.where((item) => item.isRead).map((item) => item.sourceKey),
      ['chat-message:${baseThread.id}:safe-1'],
    );
    expect(
      items.where((item) => !item.isRead).map((item) => item.sourceKey),
      ['chat-message:${baseThread.id}:burn-1'],
    );
  });

  test('markImageAsRead should sync remote read after burn image is consumed',
      () async {
    await NotificationCenterProvider.instance.clearSession();
    final fakeChatService = _FakeChatService(hasSessionOverride: true);
    final fakeSocketService = _FakeChatSocketService();
    final baseThread = _buildThread('u_chat_burn_consume_read');
    final provider = ChatProvider(
      chatService: fakeChatService,
      chatSocketService: fakeSocketService,
    );
    addTearDown(() async {
      provider.dispose();
      await NotificationCenterProvider.instance.clearSession();
    });
    provider.addThread(
      ChatThread(
        id: baseThread.id,
        otherUser: baseThread.otherUser,
        createdAt: baseThread.createdAt,
        expiresAt: baseThread.expiresAt,
        intimacyPoints: baseThread.intimacyPoints,
        unreadCount: 1,
      ),
    );
    provider.getMessages(baseThread.id).add(
          Message(
            id: 'burn-1',
            content: '[图片]',
            isMe: false,
            timestamp: DateTime.parse('2026-03-12T15:05:00.000'),
            type: MessageType.image,
            isBurnAfterReading: true,
            isRead: false,
          ),
        );
    await NotificationCenterProvider.instance.addChatMessageNotification(
      thread: provider.getThread(baseThread.id)!,
      message: provider.getMessages(baseThread.id).first,
    );

    provider.markAsRead(baseThread.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(fakeSocketService.markReadCalls[baseThread.id], isNull);
    expect(provider.getThread(baseThread.id)?.unreadCount, 1);
    expect(NotificationCenterProvider.instance.unreadCount, 1);

    provider.markImageAsRead(baseThread.id, 'burn-1');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(provider.getMessages(baseThread.id).first.isRead, isTrue);
    expect(provider.getThread(baseThread.id)?.unreadCount, 0);
    expect(NotificationCenterProvider.instance.unreadCount, 0);
    expect(fakeSocketService.markReadCalls[baseThread.id], 1);
    expect(
      fakeSocketService.markReadMessageIdsByThread[baseThread.id],
      ['burn-1'],
    );
  });

  test('recallMessage should remove sent message within 2 minutes', () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_9');
    provider.addThread(thread);
    provider.getMessages(thread.id).add(
          Message(
            id: 'recall-ok',
            content: '撤回我',
            isMe: true,
            timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
            status: MessageStatus.sent,
          ),
        );

    final recalled = provider.recallMessage(thread.id, 'recall-ok');

    expect(recalled, isTrue);
    expect(provider.getMessages(thread.id), isEmpty);
  });

  test('recallMessage should reject messages older than 2 minutes', () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_10');
    provider.addThread(thread);
    provider.getMessages(thread.id).add(
          Message(
            id: 'recall-expired',
            content: '太晚了',
            isMe: true,
            timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
            status: MessageStatus.sent,
          ),
        );

    final recalled = provider.recallMessage(thread.id, 'recall-expired');

    expect(recalled, isFalse);
    expect(provider.getMessages(thread.id), hasLength(1));
  });

  test('recalled message should not be restored by delayed self echo', () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_recall_echo');
    provider.addThread(thread);
    provider.getMessages(thread.id).add(
          Message(
            id: 'recall-echo-1',
            content: '撤回后别回来',
            isMe: true,
            timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
            status: MessageStatus.sent,
          ),
        );

    expect(provider.recallMessage(thread.id, 'recall-echo-1'), isTrue);

    ChatSocketService.instance.onMessageNew?.call(
      IncomingMessageEvent(
        threadId: thread.id,
        message: Message(
          id: 'recall-echo-1',
          content: '撤回后别回来',
          isMe: true,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        ),
      ),
    );

    expect(provider.getMessages(thread.id), isEmpty);
  });

  test('recalled message should stay filtered during remote hydration',
      () async {
    final thread = _buildThread('u_chat_recall_hydrate');
    final fakeChatService = _FakeChatService(
      threads: [thread],
      messagesByThread: {
        thread.id: [
          Message(
            id: 'recall-hydrate-1',
            content: '远端还没来得及清掉',
            isMe: true,
            timestamp: DateTime.parse('2026-03-12T15:40:00.000'),
            status: MessageStatus.sent,
          ),
        ],
      },
    );
    final provider = ChatProvider(chatService: fakeChatService);
    addTearDown(provider.dispose);
    provider.addThread(thread);
    provider.getMessages(thread.id).add(
          Message(
            id: 'recall-hydrate-1',
            content: '远端还没来得及清掉',
            isMe: true,
            timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
            status: MessageStatus.sent,
          ),
        );

    expect(provider.recallMessage(thread.id, 'recall-hydrate-1'), isTrue);

    await provider.refreshFromRemote();

    expect(provider.getMessages(thread.id), isEmpty);
  });

  test('recalled message should stay filtered after local thread upgrades',
      () async {
    final localUser = _buildUser('u_chat_recall_upgrade');
    final remoteThread = ChatThread(
      id: 'th_chat_recall_upgrade',
      otherUser: localUser,
      createdAt: DateTime.parse('2026-03-12T15:41:00.000'),
      expiresAt: DateTime.parse('2026-03-13T15:41:00.000'),
      intimacyPoints: 0,
      isFriend: false,
    );
    final fakeChatService = _FakeChatService(
      threads: [remoteThread],
      directThreadsByUserId: {localUser.id: remoteThread},
      messagesByThread: {
        remoteThread.id: [
          Message(
            id: 'recall-upgrade-1',
            content: '升级线程后也别回来',
            isMe: true,
            timestamp: DateTime.parse('2026-03-12T15:42:00.000'),
            status: MessageStatus.sent,
          ),
        ],
      },
      hasSessionOverride: true,
    );
    final provider = ChatProvider(chatService: fakeChatService);
    addTearDown(provider.dispose);
    final localThread = ChatThread(
      id: localUser.id,
      otherUser: localUser,
      createdAt: DateTime.parse('2026-03-12T15:40:00.000'),
      expiresAt: DateTime.parse('2026-03-13T15:40:00.000'),
      intimacyPoints: 0,
      isFriend: false,
    );
    provider.addThread(localThread);
    provider.getMessages(localThread.id).add(
          Message(
            id: 'recall-upgrade-1',
            content: '升级线程后也别回来',
            isMe: true,
            timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
            status: MessageStatus.sent,
          ),
        );

    expect(provider.recallMessage(localThread.id, 'recall-upgrade-1'), isTrue);

    final ensuredThread = await provider.ensureDirectThreadForUser(localUser);
    await provider.refreshFromRemote();

    expect(ensuredThread.id, remoteThread.id);
    expect(provider.getMessages(remoteThread.id), isEmpty);
  });

  test('thread upgrade should preserve last read sync state', () async {
    final localUser = _buildUser('u_chat_read_upgrade');
    final remoteThread = ChatThread(
      id: 'th_chat_read_upgrade',
      otherUser: localUser,
      createdAt: DateTime.parse('2026-03-12T15:43:00.000'),
      expiresAt: DateTime.parse('2026-03-13T15:43:00.000'),
      intimacyPoints: 0,
      isFriend: false,
    );
    final fakeChatService = _FakeChatService(
      directThreadsByUserId: {localUser.id: remoteThread},
      hasSessionOverride: true,
    );
    final provider = ChatProvider(chatService: fakeChatService);
    addTearDown(provider.dispose);
    final localThread = ChatThread(
      id: localUser.id,
      otherUser: localUser,
      createdAt: DateTime.parse('2026-03-12T15:42:00.000'),
      expiresAt: DateTime.parse('2026-03-13T15:42:00.000'),
      intimacyPoints: 0,
      isFriend: false,
    );
    provider.addThread(localThread);
    provider.getMessages(localThread.id).add(
          Message(
            id: 'read-upgrade-1',
            content: '升级前已经读过',
            isMe: false,
            timestamp: DateTime.parse('2026-03-12T15:44:00.000'),
            status: MessageStatus.sent,
          ),
        );

    provider.markAsRead(localThread.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final ensuredThread = await provider.ensureDirectThreadForUser(localUser);
    provider.markAsRead(ensuredThread.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fakeChatService.markThreadReadCalls[localThread.id], 1);
    expect(fakeChatService.markThreadReadCalls.containsKey(ensuredThread.id),
        isFalse);
  });

  test('thread upgrade should remap chat notifications to remote thread',
      () async {
    await NotificationCenterProvider.instance.clearSession();
    addTearDown(() async {
      await NotificationCenterProvider.instance.clearSession();
    });

    final localUser = _buildUser('u_chat_notify_upgrade');
    final localThread = ChatThread(
      id: localUser.id,
      otherUser: localUser,
      createdAt: DateTime.parse('2026-03-12T15:45:00.000'),
      expiresAt: DateTime.parse('2026-03-13T15:45:00.000'),
      intimacyPoints: 0,
      isFriend: false,
    );
    final remoteThread = ChatThread(
      id: 'th_chat_notify_upgrade',
      otherUser: localUser,
      createdAt: DateTime.parse('2026-03-12T15:46:00.000'),
      expiresAt: DateTime.parse('2026-03-13T15:46:00.000'),
      intimacyPoints: 0,
      isFriend: false,
    );
    final message = Message(
      id: 'notify-upgrade-1',
      content: '线程升级后的同一条通知',
      isMe: false,
      timestamp: DateTime.parse('2026-03-12T15:47:00.000'),
      status: MessageStatus.sent,
    );
    final fakeChatService = _FakeChatService(
      directThreadsByUserId: {localUser.id: remoteThread},
      hasSessionOverride: true,
    );
    final provider = ChatProvider(chatService: fakeChatService);
    addTearDown(provider.dispose);
    provider.addThread(localThread);

    await NotificationCenterProvider.instance.addChatMessageNotification(
      thread: localThread,
      message: message,
    );

    final ensuredThread = await provider.ensureDirectThreadForUser(localUser);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await NotificationCenterProvider.instance.addChatMessageNotification(
      thread: ensuredThread,
      message: message,
    );

    final items = NotificationCenterProvider.instance.items
        .where((item) => item.userId == localUser.id)
        .toList(growable: false);

    expect(items, hasLength(1));
    expect(items.first.threadId, remoteThread.id);
    expect(
        items.first.sourceKey, 'chat-message:${remoteThread.id}:${message.id}');
  });

  test('in-flight local load should not restore old thread after upgrade',
      () async {
    final localUser = _buildUser('u_chat_upgrade_inflight');
    final localThread = ChatThread(
      id: localUser.id,
      otherUser: localUser,
      createdAt: DateTime.parse('2026-03-12T15:48:00.000'),
      expiresAt: DateTime.parse('2026-03-13T15:48:00.000'),
      intimacyPoints: 0,
      isFriend: false,
    );
    final remoteThread = ChatThread(
      id: 'th_chat_upgrade_inflight',
      otherUser: localUser,
      createdAt: DateTime.parse('2026-03-12T15:49:00.000'),
      expiresAt: DateTime.parse('2026-03-13T15:49:00.000'),
      intimacyPoints: 0,
      isFriend: false,
    );
    final fakeChatService = _FakeChatService(
      directThreadsByUserId: {localUser.id: remoteThread},
      messagesByThread: {
        localThread.id: [
          Message(
            id: 'old-local-history-1',
            content: '旧线程的延迟历史',
            isMe: false,
            timestamp: DateTime.parse('2026-03-12T15:50:00.000'),
            status: MessageStatus.sent,
          ),
        ],
      },
      loadMessagesDelay: const Duration(milliseconds: 60),
      hasSessionOverride: true,
    );
    final provider = ChatProvider(chatService: fakeChatService);
    addTearDown(provider.dispose);
    provider.addThread(localThread);

    provider.setActiveThread(localThread.id);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final ensuredThread = await provider.ensureDirectThreadForUser(localUser);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(ensuredThread.id, remoteThread.id);
    expect(provider.getThread(localThread.id)?.id, remoteThread.id);
    expect(provider.getMessages(localThread.id), isEmpty);
    expect(provider.getMessages(remoteThread.id), isEmpty);
  });

  test('sortedThreads should order by latest activity desc', () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
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

  test('incoming duplicate websocket message should not double count unread',
      () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_11');
    provider.addThread(thread);

    final event = IncomingMessageEvent(
      threadId: thread.id,
      message: Message(
        id: 'incoming-dup-1',
        content: '你好',
        isMe: false,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      ),
    );

    ChatSocketService.instance.onMessageNew?.call(event);
    ChatSocketService.instance.onMessageNew?.call(event);

    expect(provider.getMessages(thread.id), hasLength(1));
    expect(provider.getThread(thread.id)?.unreadCount, 1);
  });

  test(
      'active stranger thread should notify listeners for incoming visible message',
      () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_active_stranger', isFriend: false);
    provider.addThread(thread);
    provider.setActiveThread(thread.id);

    var listenerCalls = 0;
    provider.addListener(() {
      listenerCalls += 1;
    });

    ChatSocketService.instance.onMessageNew?.call(
      IncomingMessageEvent(
        threadId: thread.id,
        message: Message(
          id: 'active-stranger-1',
          content: '正在看时收到的新消息',
          isMe: false,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        ),
      ),
    );

    expect(provider.getMessages(thread.id), hasLength(1));
    expect(provider.getThread(thread.id)?.unreadCount, 0);
    expect(listenerCalls, greaterThan(0));
  });

  test('markAsFriend should not notify when thread is already a friend', () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_noop_friend', isFriend: true);
    provider.addThread(thread);

    var listenerCalls = 0;
    provider.addListener(() {
      listenerCalls += 1;
    });

    provider.markAsFriend(thread.id);

    expect(provider.getThread(thread.id)?.isFriend, isTrue);
    expect(listenerCalls, 0);
  });

  test('setActiveThread should not reload same thread repeatedly', () async {
    final thread = _buildThread('u_chat_same_active');
    final fakeChatService = _FakeChatService(
      messagesByThread: {
        thread.id: [
          Message(
            id: 'remote-active-1',
            content: '远端历史',
            isMe: false,
            timestamp: DateTime.parse('2026-03-12T15:00:00.000'),
            status: MessageStatus.sent,
          ),
        ],
      },
    );
    final provider = ChatProvider(chatService: fakeChatService);
    addTearDown(provider.dispose);
    provider.addThread(thread);

    provider.setActiveThread(thread.id);
    provider.setActiveThread(thread.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fakeChatService.loadMessagesCalls[thread.id], 1);
    expect(provider.getMessages(thread.id), hasLength(1));
  });

  test('clearActiveThread should restore previous active thread', () async {
    await NotificationCenterProvider.instance.clearSession();
    addTearDown(() async {
      await NotificationCenterProvider.instance.clearSession();
    });
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final firstThread = _buildThread('u_chat_restore_active_a');
    final secondThread = _buildThread('u_chat_restore_active_b');
    provider.addThread(firstThread);
    provider.addThread(secondThread);

    provider.setActiveThread(firstThread.id);
    provider.setActiveThread(secondThread.id);
    provider.clearActiveThread(secondThread.id);

    ChatSocketService.instance.onMessageNew?.call(
      IncomingMessageEvent(
        threadId: firstThread.id,
        message: Message(
          id: 'restore-active-1',
          content: '返回上一层后仍应视为活跃',
          isMe: false,
          timestamp: DateTime.parse('2026-03-12T16:10:00.000'),
          status: MessageStatus.sent,
        ),
      ),
    );

    expect(provider.getThread(firstThread.id)?.unreadCount, 0);
    expect(NotificationCenterProvider.instance.unreadCount, 0);
  });

  test('duplicate active claims should keep thread active until final clear',
      () async {
    await NotificationCenterProvider.instance.clearSession();
    addTearDown(() async {
      await NotificationCenterProvider.instance.clearSession();
    });
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_duplicate_active');
    provider.addThread(thread);

    provider.setActiveThread(thread.id);
    provider.setActiveThread(thread.id);
    provider.clearActiveThread(thread.id);

    ChatSocketService.instance.onMessageNew?.call(
      IncomingMessageEvent(
        threadId: thread.id,
        message: Message(
          id: 'duplicate-active-1',
          content: '第一次 clear 后仍应算活跃',
          isMe: false,
          timestamp: DateTime.parse('2026-03-12T16:12:00.000'),
          status: MessageStatus.sent,
        ),
      ),
    );

    expect(provider.getThread(thread.id)?.unreadCount, 0);

    provider.clearActiveThread(thread.id);
    ChatSocketService.instance.onMessageNew?.call(
      IncomingMessageEvent(
        threadId: thread.id,
        message: Message(
          id: 'duplicate-active-2',
          content: '最后一次 clear 后应恢复未读',
          isMe: false,
          timestamp: DateTime.parse('2026-03-12T16:12:10.000'),
          status: MessageStatus.sent,
        ),
      ),
    );

    expect(provider.getThread(thread.id)?.unreadCount, 1);
  });

  test('concurrent remote loads should dedupe per thread', () async {
    final thread = _buildThread('u_chat_inflight');
    final fakeChatService = _FakeChatService(
      threads: [thread],
      messagesByThread: {
        thread.id: [
          Message(
            id: 'remote-inflight-1',
            content: '并发拉取只保留一次',
            isMe: false,
            timestamp: DateTime.parse('2026-03-12T15:10:00.000'),
            status: MessageStatus.sent,
          ),
        ],
      },
      loadMessagesDelay: const Duration(milliseconds: 50),
    );
    final provider = ChatProvider(chatService: fakeChatService);
    addTearDown(provider.dispose);

    provider.setActiveThread(thread.id);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(fakeChatService.loadMessagesCalls[thread.id], 1);
    expect(provider.getMessages(thread.id), hasLength(1));
  });

  test('setActiveThread should skip reload right after recent remote sync',
      () async {
    final thread = _buildThread('u_chat_recent_sync');
    final fakeChatService = _FakeChatService(
      threads: [thread],
      messagesByThread: {
        thread.id: [
          Message(
            id: 'recent-sync-1',
            content: '刚同步过的历史',
            isMe: false,
            timestamp: DateTime.parse('2026-03-12T15:30:00.000'),
            status: MessageStatus.sent,
          ),
        ],
      },
    );
    final provider = ChatProvider(chatService: fakeChatService);
    addTearDown(provider.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    provider.setActiveThread(thread.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fakeChatService.loadMessagesCalls[thread.id], 1);
    expect(provider.getMessages(thread.id), hasLength(1));
  });

  test('markAsRead should not resync same last message repeatedly', () async {
    final thread = _buildThread('u_chat_read_sync');
    final fakeChatService = _FakeChatService(hasSessionOverride: true);
    final provider = ChatProvider(chatService: fakeChatService);
    addTearDown(provider.dispose);
    provider.addThread(thread);
    provider.getMessages(thread.id).add(
          Message(
            id: 'read-sync-1',
            content: '最后一条消息',
            isMe: false,
            timestamp: DateTime.parse('2026-03-12T15:20:00.000'),
            status: MessageStatus.sent,
          ),
        );

    provider.markAsRead(thread.id);
    provider.markAsRead(thread.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fakeChatService.markThreadReadCalls[thread.id], 1);

    provider.getMessages(thread.id).add(
          Message(
            id: 'read-sync-2',
            content: '更新了新的最后消息',
            isMe: false,
            timestamp: DateTime.parse('2026-03-12T15:21:00.000'),
            status: MessageStatus.sent,
          ),
        );

    provider.markAsRead(thread.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fakeChatService.markThreadReadCalls[thread.id], 2);
  });

  test('reconnect should rejoin active thread only once', () async {
    final thread = _buildThread('u_chat_rejoin');
    final fakeSocket = _FakeChatSocketService();
    final provider = ChatProvider(chatSocketService: fakeSocket);
    addTearDown(provider.dispose);

    provider.addThread(thread);
    provider.setActiveThread(thread.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fakeSocket.joinCalls[thread.id], 1);

    fakeSocket.emitConnected('user-reconnect');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fakeSocket.joinCalls[thread.id], 2);
  });

  test('peer read should only mark outgoing messages up to lastReadMessageId',
      () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_12');
    provider.addThread(thread);
    provider.getMessages(thread.id).addAll([
      Message(
        id: 'read-1',
        content: '第一条',
        isMe: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
        status: MessageStatus.sent,
        isRead: false,
      ),
      Message(
        id: 'read-2',
        content: '第二条',
        isMe: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        status: MessageStatus.sent,
        isRead: false,
      ),
      Message(
        id: 'read-3',
        content: '第三条',
        isMe: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
        status: MessageStatus.sent,
        isRead: false,
      ),
    ]);

    ChatSocketService.instance.onPeerRead?.call(
      PeerReadEvent(
        threadId: thread.id,
        byUserId: thread.otherUser.id,
        lastReadMessageId: 'read-2',
      ),
    );

    final messages = provider.getMessages(thread.id);
    expect(messages[0].isRead, isTrue);
    expect(messages[1].isRead, isTrue);
    expect(messages[2].isRead, isFalse);
  });

  test(
      'remote hydration should preserve local image preview when remote image is not ready',
      () async {
    final thread = _buildThread('u_chat_13');
    const localPreviewPath = r'C:\mock\preview.jpg';
    await AppDataRepository.instance.saveChatState({
      'threads': {
        thread.id: thread.toJson(),
      },
      'messages': {
        thread.id: [
          Message(
            id: 'img-1',
            content: '[图片]',
            isMe: true,
            timestamp: DateTime.parse('2026-03-12T12:40:00.000'),
            status: MessageStatus.sent,
            type: MessageType.image,
            imagePath: localPreviewPath,
            imageQuality: ImageQuality.compressed,
          ).toJson(),
        ],
      },
      'lastMessageTime': {},
      'deletedThreads': {
        thread.id: false,
      },
    });

    final provider = ChatProvider(
      chatService: _FakeChatService(
        threads: [thread],
        messagesByThread: {
          thread.id: [
            Message(
              id: 'img-1',
              content: '[图片]',
              isMe: true,
              timestamp: DateTime.parse('2026-03-12T12:40:00.000'),
              status: MessageStatus.sent,
              type: MessageType.image,
              imagePath: null,
              imageQuality: ImageQuality.compressed,
            ),
          ],
        },
      ),
    );
    addTearDown(provider.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 20));

    final messages = provider.getMessages(thread.id);
    expect(messages, hasLength(1));
    expect(messages.first.type, MessageType.image);
    expect(messages.first.imagePath, localPreviewPath);
  });

  test(
      'remote hydration should not merge image message into local image with different burn rule',
      () async {
    final thread = _buildThread('u_chat_22');
    final firstLocalAt = DateTime.parse('2026-03-12T12:50:00.000');
    final secondLocalAt = DateTime.parse('2026-03-12T12:50:20.000');
    await AppDataRepository.instance.saveChatState({
      'threads': {
        thread.id: thread.toJson(),
      },
      'messages': {
        thread.id: [
          Message(
            id: 'img-local-normal',
            content: '[图片]',
            isMe: true,
            timestamp: firstLocalAt,
            status: MessageStatus.sending,
            type: MessageType.image,
            imagePath: r'C:\mock\preview-normal.jpg',
            isBurnAfterReading: false,
            imageQuality: ImageQuality.compressed,
          ).toJson(),
          Message(
            id: 'img-local-burn',
            content: '[图片]',
            isMe: true,
            timestamp: secondLocalAt,
            status: MessageStatus.sending,
            type: MessageType.image,
            imagePath: r'C:\mock\preview-burn.jpg',
            isBurnAfterReading: true,
            imageQuality: ImageQuality.compressed,
          ).toJson(),
        ],
      },
      'lastMessageTime': {
        thread.id: secondLocalAt.toIso8601String(),
      },
      'deletedThreads': {
        thread.id: false,
      },
    });

    final provider = ChatProvider(
      chatService: _FakeChatService(
        threads: [thread],
        messagesByThread: {
          thread.id: [
            Message(
              id: 'img-remote-normal',
              content: '[图片]',
              isMe: true,
              timestamp: DateTime.parse('2026-03-12T12:50:15.000'),
              status: MessageStatus.sent,
              type: MessageType.image,
              imagePath: null,
              isBurnAfterReading: false,
              imageQuality: ImageQuality.compressed,
            ),
          ],
        },
      ),
    );
    addTearDown(provider.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 20));

    final messages = provider.getMessages(thread.id);
    expect(messages, hasLength(2));

    final remoteMerged = messages.firstWhere(
      (message) => message.id == 'img-remote-normal',
    );
    final retainedBurnImage = messages.firstWhere(
      (message) => message.id == 'img-local-burn',
    );

    expect(remoteMerged.imagePath, r'C:\mock\preview-normal.jpg');
    expect(remoteMerged.isBurnAfterReading, isFalse);
    expect(retainedBurnImage.imagePath, r'C:\mock\preview-burn.jpg');
    expect(retainedBurnImage.isBurnAfterReading, isTrue);
  });

  test(
      'remote hydration should retain recent sent message while remote history is lagging',
      () async {
    final thread = _buildThread('u_chat_14');
    final recentSentAt = DateTime.now().subtract(const Duration(minutes: 5));
    await AppDataRepository.instance.saveChatState({
      'threads': {
        thread.id: thread.toJson(),
      },
      'messages': {
        thread.id: [
          Message(
            id: 'sent-lagging-1',
            content: '这条消息刚发出',
            isMe: true,
            timestamp: recentSentAt,
            status: MessageStatus.sent,
            type: MessageType.text,
          ).toJson(),
        ],
      },
      'lastMessageTime': {
        thread.id: recentSentAt.toIso8601String(),
      },
      'deletedThreads': {
        thread.id: false,
      },
    });

    final provider = ChatProvider(
      chatService: _FakeChatService(
        threads: [thread],
        messagesByThread: {
          thread.id: const <Message>[],
        },
      ),
    );
    addTearDown(provider.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 20));

    final messages = provider.getMessages(thread.id);
    expect(messages, hasLength(1));
    expect(messages.first.id, 'sent-lagging-1');
    expect(messages.first.content, '这条消息刚发出');
    expect(messages.first.status, MessageStatus.sent);
  });

  test(
      'remote hydration should discard stale sent message after sync grace period',
      () async {
    final thread = _buildThread('u_chat_15');
    final staleSentAt = DateTime.now().subtract(const Duration(minutes: 30));
    await AppDataRepository.instance.saveChatState({
      'threads': {
        thread.id: thread.toJson(),
      },
      'messages': {
        thread.id: [
          Message(
            id: 'sent-stale-1',
            content: '很久之前的本地消息',
            isMe: true,
            timestamp: staleSentAt,
            status: MessageStatus.sent,
            type: MessageType.text,
          ).toJson(),
        ],
      },
      'lastMessageTime': {
        thread.id: staleSentAt.toIso8601String(),
      },
      'deletedThreads': {
        thread.id: false,
      },
    });

    final provider = ChatProvider(
      chatService: _FakeChatService(
        threads: [thread],
        messagesByThread: {
          thread.id: const <Message>[],
        },
      ),
    );
    addTearDown(provider.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(provider.getMessages(thread.id), isEmpty);
  });

  test('resendMessage should retry failed text message only', () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_16');
    provider.addThread(thread);
    provider.getMessages(thread.id).add(
          Message(
            id: 'retry-text-1',
            content: '再试一次',
            isMe: true,
            timestamp: DateTime.now(),
            status: MessageStatus.failed,
            type: MessageType.text,
          ),
        );

    final resent = provider.resendMessage(thread.id, 'retry-text-1');

    expect(resent, isTrue);
    expect(
      provider.getMessages(thread.id).first.status,
      MessageStatus.sending,
    );
  });

  test('resendMessage should resolve local thread to remote thread', () async {
    final localThread = _buildThread('u_chat_retry_local');
    final remoteThread = ChatThread(
      id: 'th_chat_retry_remote',
      otherUser: localThread.otherUser,
      createdAt: localThread.createdAt,
      expiresAt: localThread.expiresAt,
      intimacyPoints: localThread.intimacyPoints,
    );
    final fakeChatService = _FakeChatService(
      directThreadsByUserId: {localThread.otherUser.id: remoteThread},
      hasSessionOverride: true,
    );
    final fakeSocketService = _FakeChatSocketService();
    final provider = ChatProvider(
      chatService: fakeChatService,
      chatSocketService: fakeSocketService,
    );
    addTearDown(provider.dispose);
    provider.addThread(localThread);
    provider.getMessages(localThread.id).add(
          Message(
            id: 'retry-local-thread-1',
            content: '重试也要先升远端线程',
            isMe: true,
            timestamp: DateTime.now(),
            status: MessageStatus.failed,
            type: MessageType.text,
          ),
        );

    final resent =
        provider.resendMessage(localThread.id, 'retry-local-thread-1');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(resent, isTrue);
    expect(fakeSocketService.sendTextCalls[remoteThread.id], 1);
    expect(fakeSocketService.sendTextCalls[localThread.id], isNull);
    expect(provider.threads.containsKey(remoteThread.id), isTrue);
    expect(provider.threads.containsKey(localThread.id), isFalse);
    expect(provider.getMessages(remoteThread.id), hasLength(1));
    expect(
        provider.getMessages(remoteThread.id).first.id, 'retry-local-thread-1');
    expect(
      provider.getMessages(remoteThread.id).first.status,
      MessageStatus.sending,
    );
  });

  test('resendMessage should reject failed image message', () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_17');
    provider.addThread(thread);
    provider.getMessages(thread.id).add(
          Message(
            id: 'retry-image-1',
            content: '[图片]',
            isMe: true,
            timestamp: DateTime.now(),
            status: MessageStatus.failed,
            type: MessageType.image,
            imagePath: r'C:\mock\failed-preview.jpg',
          ),
        );

    final resent = provider.resendMessage(thread.id, 'retry-image-1');

    expect(resent, isFalse);
    expect(
      provider.getMessages(thread.id).first.status,
      MessageStatus.failed,
    );
    expect(
      provider.getMessages(thread.id).first.type,
      MessageType.image,
    );
  });

  test('resendImageMessage should retry failed image message', () async {
    final remoteThread = _buildThread('th_chat_retry_image');
    final fakeSocketService = _FakeChatSocketService();
    final provider = ChatProvider(
      chatService: _FakeChatService(
        threads: [remoteThread],
        hasSessionOverride: true,
      ),
      chatSocketService: fakeSocketService,
      mediaUploadService: _FakeMediaUploadService(
        preparedUploadBuilder: (threadId, imageFile) =>
            const PreparedChatImageUpload(
          sendKey: 'chat/object-key-retry-image',
          previewPath: 'preview-path',
          isRemotePrepared: true,
        ),
      ),
    );
    addTearDown(provider.dispose);
    provider.addThread(remoteThread);
    final imageFile = await _createTestImageFile('retry_image_message');
    provider.getMessages(remoteThread.id).add(
          Message(
            id: 'retry-image-ok-1',
            content: '[图片]',
            isMe: true,
            timestamp: DateTime.now(),
            status: MessageStatus.failed,
            type: MessageType.image,
            imagePath: imageFile.path,
            imageQuality: ImageQuality.compressed,
          ),
        );

    final resent = await provider.resendImageMessage(
      remoteThread.id,
      'retry-image-ok-1',
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(resent, isTrue);
    expect(fakeSocketService.sendImageCalls[remoteThread.id], 1);
    expect(
      provider.getMessages(remoteThread.id).first.status,
      MessageStatus.sending,
    );
  });

  test('resendImageMessage should reject failed image when preview is missing',
      () async {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_retry_image_missing');
    provider.addThread(thread);
    provider.getMessages(thread.id).add(
          Message(
            id: 'retry-image-missing-1',
            content: '[图片]',
            isMe: true,
            timestamp: DateTime.now(),
            status: MessageStatus.failed,
            type: MessageType.image,
            imagePath: r'C:\mock\missing-preview.jpg',
            imageQuality: ImageQuality.compressed,
          ),
        );

    final resent = await provider.resendImageMessage(
      thread.id,
      'retry-image-missing-1',
    );

    expect(resent, isFalse);
    expect(
      provider.getMessages(thread.id).first.status,
      MessageStatus.failed,
    );
  });

  test('restored failed image should remain retryable after remote hydration',
      () async {
    final thread = _buildThread('th_chat_retry_image_restored');
    final imageFile = await _createTestImageFile('retry_image_restored');
    await AppDataRepository.instance.saveChatState({
      'threads': {
        thread.id: thread.toJson(),
      },
      'messages': {
        thread.id: [
          Message(
            id: 'retry-image-restored-1',
            content: '[图片]',
            isMe: true,
            timestamp: DateTime.parse('2026-03-12T17:20:00.000'),
            status: MessageStatus.failed,
            type: MessageType.image,
            imagePath: imageFile.path,
            imageQuality: ImageQuality.compressed,
          ).toJson(),
        ],
      },
      'lastMessageTime': {},
      'deletedThreads': {
        thread.id: false,
      },
    });

    final fakeSocketService = _FakeChatSocketService();
    final provider = ChatProvider(
      chatService: _FakeChatService(
        threads: [thread],
        messagesByThread: {
          thread.id: const <Message>[],
        },
        hasSessionOverride: true,
      ),
      chatSocketService: fakeSocketService,
      mediaUploadService: _FakeMediaUploadService(
        preparedUploadBuilder: (threadId, imageFile) =>
            const PreparedChatImageUpload(
          sendKey: 'chat/object-key-restored-image',
          previewPath: 'preview-path',
          isRemotePrepared: true,
        ),
      ),
    );
    addTearDown(provider.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(provider.getMessages(thread.id), hasLength(1));
    expect(
      provider.getMessages(thread.id).first.imagePath,
      imageFile.path,
    );

    final resent = await provider.resendImageMessage(
      thread.id,
      'retry-image-restored-1',
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(resent, isTrue);
    expect(fakeSocketService.sendImageCalls[thread.id], 1);
    expect(
      provider.getMessages(thread.id).first.status,
      MessageStatus.sending,
    );
  });

  test(
      'remote hydration should merge pending local text with resolved remote message',
      () async {
    final thread = _buildThread('u_chat_18');
    final localSentAt = DateTime.parse('2026-03-12T13:10:00.000');
    await AppDataRepository.instance.saveChatState({
      'threads': {
        thread.id: thread.toJson(),
      },
      'messages': {
        thread.id: [
          Message(
            id: 'local-failed-1',
            content: '同一条消息',
            isMe: true,
            timestamp: localSentAt,
            status: MessageStatus.failed,
            type: MessageType.text,
          ).toJson(),
        ],
      },
      'lastMessageTime': {
        thread.id: localSentAt.toIso8601String(),
      },
      'deletedThreads': {
        thread.id: false,
      },
    });

    final provider = ChatProvider(
      chatService: _FakeChatService(
        threads: [thread],
        messagesByThread: {
          thread.id: [
            Message(
              id: 'remote-sent-1',
              content: '同一条消息',
              isMe: true,
              timestamp: localSentAt.add(const Duration(seconds: 20)),
              status: MessageStatus.sent,
              type: MessageType.text,
            ),
          ],
        },
      ),
    );
    addTearDown(provider.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 20));

    final messages = provider.getMessages(thread.id);
    expect(messages, hasLength(1));
    expect(messages.first.id, 'remote-sent-1');
    expect(messages.first.status, MessageStatus.sent);
    expect(messages.first.content, '同一条消息');
  });

  test('self echo websocket message should resolve local pending message only',
      () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_19');
    provider.addThread(thread);
    provider.getMessages(thread.id).add(
          Message(
            id: 'local-pending-1',
            content: '这是我发的',
            isMe: true,
            timestamp: DateTime.parse('2026-03-12T13:30:00.000'),
            status: MessageStatus.sending,
            type: MessageType.text,
          ),
        );

    ChatSocketService.instance.onMessageNew?.call(
      IncomingMessageEvent(
        threadId: thread.id,
        message: Message(
          id: 'remote-sent-self-1',
          content: '这是我发的',
          isMe: true,
          timestamp: DateTime.parse('2026-03-12T13:30:20.000'),
          status: MessageStatus.sent,
          type: MessageType.text,
        ),
      ),
    );

    final messages = provider.getMessages(thread.id);
    expect(messages, hasLength(1));
    expect(messages.first.id, 'remote-sent-self-1');
    expect(messages.first.status, MessageStatus.sent);
    expect(provider.getThread(thread.id)?.unreadCount, 0);
  });

  test('self echo websocket message should restore intimacy for pending send',
      () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_21', intimacyPoints: 60);
    provider.addThread(thread);
    provider.getMessages(thread.id).add(
          Message(
            id: 'local-pending-intimacy-1',
            content: '补亲密度',
            isMe: true,
            timestamp: DateTime.parse('2026-03-12T13:35:00.000'),
            status: MessageStatus.sending,
            type: MessageType.text,
          ),
        );

    ChatSocketService.instance.onMessageNew?.call(
      IncomingMessageEvent(
        threadId: thread.id,
        message: Message(
          id: 'remote-sent-self-2',
          content: '补亲密度',
          isMe: true,
          timestamp: DateTime.parse('2026-03-12T13:35:10.000'),
          status: MessageStatus.sent,
          type: MessageType.text,
        ),
      ),
    );

    final updatedThread = provider.getThread(thread.id);
    expect(updatedThread, isNotNull);
    expect(updatedThread!.intimacyPoints, greaterThan(60));
    expect(provider.getMessages(thread.id), hasLength(1));
    expect(provider.getMessages(thread.id).first.id, 'remote-sent-self-2');
  });

  test(
      'self echo websocket image should preserve local preview and not create notification',
      () async {
    await NotificationCenterProvider.instance.clearSession();
    final provider = ChatProvider();
    addTearDown(() async {
      provider.dispose();
      await NotificationCenterProvider.instance.clearSession();
    });
    final thread = _buildThread('u_chat_20');
    provider.addThread(thread);
    provider.getMessages(thread.id).add(
          Message(
            id: 'local-image-pending-1',
            content: '[图片]',
            isMe: true,
            timestamp: DateTime.parse('2026-03-12T13:40:00.000'),
            status: MessageStatus.sending,
            type: MessageType.image,
            imagePath: r'C:\mock\local-preview.jpg',
            imageQuality: ImageQuality.compressed,
          ),
        );

    ChatSocketService.instance.onMessageNew?.call(
      IncomingMessageEvent(
        threadId: thread.id,
        message: Message(
          id: 'remote-image-self-1',
          content: '[图片]',
          isMe: true,
          timestamp: DateTime.parse('2026-03-12T13:40:18.000'),
          status: MessageStatus.sent,
          type: MessageType.image,
          imagePath: null,
          imageQuality: ImageQuality.compressed,
        ),
      ),
    );

    final messages = provider.getMessages(thread.id);
    expect(messages, hasLength(1));
    expect(messages.first.id, 'remote-image-self-1');
    expect(messages.first.status, MessageStatus.sent);
    expect(messages.first.imagePath, r'C:\mock\local-preview.jpg');
    expect(provider.getThread(thread.id)?.unreadCount, 0);
    expect(NotificationCenterProvider.instance.unreadCount, 0);
  });

  test('markAsRead should mark same-thread chat notifications as read',
      () async {
    await NotificationCenterProvider.instance.clearSession();
    final provider = ChatProvider();
    addTearDown(() async {
      provider.dispose();
      await NotificationCenterProvider.instance.clearSession();
    });
    final thread = _buildThread('u_chat_23');
    final otherThread = _buildThread('u_chat_24');
    provider.addThread(
      ChatThread(
        id: thread.id,
        otherUser: thread.otherUser,
        createdAt: thread.createdAt,
        expiresAt: thread.expiresAt,
        intimacyPoints: thread.intimacyPoints,
        unreadCount: 2,
      ),
    );
    provider.addThread(otherThread);
    provider.getMessages(thread.id).addAll([
      Message(
        id: 'notify-thread-1',
        content: '第一条',
        isMe: false,
        timestamp: DateTime.parse('2026-03-12T14:10:00.000'),
      ),
      Message(
        id: 'notify-thread-2',
        content: '[图片]',
        isMe: false,
        timestamp: DateTime.parse('2026-03-12T14:10:10.000'),
        type: MessageType.image,
      ),
    ]);

    await NotificationCenterProvider.instance.addChatMessageNotification(
      thread: thread,
      message: Message(
        id: 'notify-thread-1',
        content: '第一条',
        isMe: false,
        timestamp: DateTime.parse('2026-03-12T14:10:00.000'),
      ),
    );
    await NotificationCenterProvider.instance.addChatMessageNotification(
      thread: thread,
      message: Message(
        id: 'notify-thread-2',
        content: '[图片]',
        isMe: false,
        timestamp: DateTime.parse('2026-03-12T14:10:10.000'),
        type: MessageType.image,
      ),
    );
    await NotificationCenterProvider.instance.addChatMessageNotification(
      thread: otherThread,
      message: Message(
        id: 'notify-other-1',
        content: '别的会话',
        isMe: false,
        timestamp: DateTime.parse('2026-03-12T14:10:20.000'),
      ),
    );

    provider.markAsRead(thread.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final sameThreadItems = NotificationCenterProvider.instance.items
        .where((item) => item.threadId == thread.id)
        .toList(growable: false);
    final otherThreadItems = NotificationCenterProvider.instance.items
        .where((item) => item.threadId == otherThread.id)
        .toList(growable: false);

    expect(provider.getThread(thread.id)?.unreadCount, 0);
    expect(sameThreadItems, isNotEmpty);
    expect(sameThreadItems.every((item) => item.isRead), isTrue);
    expect(otherThreadItems, isNotEmpty);
    expect(otherThreadItems.every((item) => item.isRead), isFalse);
  });

  test('notification center should dedupe same chat message notification',
      () async {
    await NotificationCenterProvider.instance.clearSession();
    addTearDown(() async {
      await NotificationCenterProvider.instance.clearSession();
    });

    final thread = _buildThread('u_chat_25');
    final message = Message(
      id: 'same-message-1',
      content: '重复通知测试',
      isMe: false,
      timestamp: DateTime.parse('2026-03-12T14:20:00.000'),
    );

    await NotificationCenterProvider.instance.addChatMessageNotification(
      thread: thread,
      message: message,
    );
    await NotificationCenterProvider.instance.addChatMessageNotification(
      thread: thread,
      message: message,
    );

    final items = NotificationCenterProvider.instance.items
        .where((item) => item.threadId == thread.id)
        .toList(growable: false);

    expect(items, hasLength(1));
    expect(items.first.sourceKey, 'chat-message:${thread.id}:${message.id}');
    expect(NotificationCenterProvider.instance.unreadCount, 1);
  });

  test(
      'remote hydration should keep deleted thread hidden and skip old history',
      () async {
    final thread = _buildThread('u_chat_26');
    await AppDataRepository.instance.saveChatState({
      'threads': {
        thread.id: thread.toJson(),
      },
      'messages': {
        thread.id: const <Map<String, dynamic>>[],
      },
      'lastMessageTime': {},
      'deletedThreads': {
        thread.id: true,
      },
    });

    final provider = ChatProvider(
      chatService: _FakeChatService(
        threads: [thread],
        messagesByThread: {
          thread.id: [
            Message(
              id: 'remote-hidden-history-1',
              content: '旧消息不应复活会话',
              isMe: false,
              timestamp: DateTime.parse('2026-03-12T14:30:00.000'),
              status: MessageStatus.sent,
            ),
          ],
        },
      ),
    );
    addTearDown(provider.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(provider.threads.containsKey(thread.id), isFalse);
    expect(provider.getMessages(thread.id), isEmpty);
  });

  test('successful empty remote hydration should clear stale remote thread',
      () async {
    final remoteThread = _buildThread(
      'th_chat_hydrate_empty',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      expiresAt: DateTime.now().add(const Duration(hours: 22)),
    );
    final localThread = _buildThread('u_chat_hydrate_local_only');
    final fakeChatService = _FakeChatService(
      hasSessionOverride: true,
      threadSnapshot: const ChatThreadHydrationSnapshot(threads: []),
    );
    final provider = ChatProvider(chatService: fakeChatService);
    addTearDown(provider.dispose);
    provider.addThread(remoteThread);
    provider.addThread(localThread);
    provider.getMessages(remoteThread.id).add(
          Message(
            id: 'hydrate-empty-msg-1',
            content: '会被远端空列表清掉',
            isMe: false,
            timestamp: DateTime.now().subtract(const Duration(hours: 1)),
            status: MessageStatus.sent,
          ),
        );

    await NotificationCenterProvider.instance.addChatMessageNotification(
      thread: remoteThread,
      message: provider.getMessages(remoteThread.id).first,
    );

    await provider.refreshFromRemote();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(provider.getThread(remoteThread.id), isNull);
    expect(provider.getMessages(remoteThread.id), isEmpty);
    expect(provider.getThread(localThread.id), isNotNull);
    expect(
      NotificationCenterProvider.instance.items
          .where((item) => item.threadId == remoteThread.id),
      isEmpty,
    );
  });

  test('failed remote hydration should keep local remote thread', () async {
    final remoteThread = _buildThread('th_chat_hydrate_failed');
    final fakeChatService = _FakeChatService(
      hasSessionOverride: true,
      failThreadHydration: true,
    );
    final provider = ChatProvider(chatService: fakeChatService);
    addTearDown(provider.dispose);
    provider.addThread(remoteThread);

    await provider.refreshFromRemote();

    expect(provider.getThread(remoteThread.id), isNotNull);
  });

  test('thread update should not restore locally deleted thread', () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_27');
    provider.addThread(thread);
    provider.deleteThread(thread.id);

    ChatSocketService.instance.onThreadUpdated?.call(
      ChatThread(
        id: thread.id,
        otherUser: thread.otherUser,
        createdAt: thread.createdAt,
        expiresAt: thread.expiresAt,
        intimacyPoints: thread.intimacyPoints,
        unreadCount: 0,
      ),
    );

    expect(provider.threads.containsKey(thread.id), isFalse);
  });

  test('incoming new message should still restore locally deleted thread', () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_28');
    provider.addThread(thread);
    provider.deleteThread(thread.id);

    ChatSocketService.instance.onMessageNew?.call(
      IncomingMessageEvent(
        threadId: thread.id,
        message: Message(
          id: 'incoming-restore-1',
          content: '我来找你了',
          isMe: false,
          timestamp: DateTime.parse('2026-03-12T14:35:00.000'),
          status: MessageStatus.sent,
        ),
      ),
    );

    expect(provider.threads.containsKey(thread.id), isTrue);
    expect(provider.getMessages(thread.id), hasLength(1));
    expect(provider.getThread(thread.id)?.unreadCount, 1);
  });

  test('message ack should not restore locally deleted thread', () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_29');
    provider.addThread(thread);
    provider.getMessages(thread.id).add(
          Message(
            id: 'local-pending-after-delete-1',
            content: '这条 ACK 不该复活会话',
            isMe: true,
            timestamp: DateTime.parse('2026-03-12T14:40:00.000'),
            status: MessageStatus.sending,
          ),
        );
    provider.deleteThread(thread.id);

    ChatSocketService.instance.onMessageAck?.call(
      MessageAckEvent(
        threadId: thread.id,
        clientMsgId: 'local-pending-after-delete-1',
        message: Message(
          id: 'remote-acked-after-delete-1',
          content: '这条 ACK 不该复活会话',
          isMe: true,
          timestamp: DateTime.parse('2026-03-12T14:40:08.000'),
          status: MessageStatus.sent,
        ),
      ),
    );

    expect(provider.threads.containsKey(thread.id), isFalse);
    expect(provider.getMessages(thread.id), isEmpty);
  });

  test('self echo should not restore locally deleted thread', () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_30');
    provider.addThread(thread);
    provider.getMessages(thread.id).add(
          Message(
            id: 'local-self-after-delete-1',
            content: '自回环不该复活会话',
            isMe: true,
            timestamp: DateTime.parse('2026-03-12T14:45:00.000'),
            status: MessageStatus.sending,
          ),
        );
    provider.deleteThread(thread.id);

    ChatSocketService.instance.onMessageNew?.call(
      IncomingMessageEvent(
        threadId: thread.id,
        message: Message(
          id: 'remote-self-after-delete-1',
          content: '自回环不该复活会话',
          isMe: true,
          timestamp: DateTime.parse('2026-03-12T14:45:06.000'),
          status: MessageStatus.sent,
        ),
      ),
    );

    expect(provider.threads.containsKey(thread.id), isFalse);
    expect(provider.getMessages(thread.id), isEmpty);
  });

  test('deleteThread should remove same-thread chat notifications', () async {
    await NotificationCenterProvider.instance.clearSession();
    final provider = ChatProvider();
    addTearDown(() async {
      provider.dispose();
      await NotificationCenterProvider.instance.clearSession();
    });
    final thread = _buildThread('u_chat_31');
    final otherThread = _buildThread('u_chat_32');
    provider.addThread(thread);
    provider.addThread(otherThread);

    await NotificationCenterProvider.instance.addChatMessageNotification(
      thread: thread,
      message: Message(
        id: 'delete-notify-thread-1',
        content: '要清掉的通知',
        isMe: false,
        timestamp: DateTime.parse('2026-03-12T14:50:00.000'),
      ),
    );
    await NotificationCenterProvider.instance.addChatMessageNotification(
      thread: otherThread,
      message: Message(
        id: 'delete-notify-other-1',
        content: '别的会话通知',
        isMe: false,
        timestamp: DateTime.parse('2026-03-12T14:50:10.000'),
      ),
    );

    provider.deleteThread(thread.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final sameThreadItems = NotificationCenterProvider.instance.items
        .where((item) => item.threadId == thread.id)
        .toList(growable: false);
    final otherThreadItems = NotificationCenterProvider.instance.items
        .where((item) => item.threadId == otherThread.id)
        .toList(growable: false);

    expect(sameThreadItems, isEmpty);
    expect(otherThreadItems, hasLength(1));
    expect(otherThreadItems.first.threadId, otherThread.id);
  });

  test('handleUserBlocked should clear same-thread unread and notifications',
      () async {
    await NotificationCenterProvider.instance.clearSession();
    final provider = ChatProvider();
    addTearDown(() async {
      provider.dispose();
      await NotificationCenterProvider.instance.clearSession();
    });
    final user = _buildUser('u_chat_blocked_1');
    final thread = ChatThread(
      id: 'th_chat_blocked_1',
      otherUser: user,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      intimacyPoints: 60,
      unreadCount: 3,
    );
    final otherThread = _buildThread('u_chat_blocked_2');
    provider.addThread(thread);
    provider.addThread(otherThread);

    await NotificationCenterProvider.instance.addChatMessageNotification(
      thread: thread,
      message: Message(
        id: 'blocked-notify-thread-1',
        content: '拉黑后应清掉',
        isMe: false,
        timestamp: DateTime.parse('2026-03-12T15:10:00.000'),
      ),
    );
    await NotificationCenterProvider.instance.addChatMessageNotification(
      thread: otherThread,
      message: Message(
        id: 'blocked-notify-other-1',
        content: '别的会话保留',
        isMe: false,
        timestamp: DateTime.parse('2026-03-12T15:10:10.000'),
      ),
    );

    provider.handleUserBlocked(user.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final sameThreadItems = NotificationCenterProvider.instance.items
        .where((item) => item.threadId == thread.id)
        .toList(growable: false);
    final otherThreadItems = NotificationCenterProvider.instance.items
        .where((item) => item.threadId == otherThread.id)
        .toList(growable: false);

    expect(provider.getThread(thread.id), isNotNull);
    expect(provider.getThread(thread.id)?.unreadCount, 0);
    expect(sameThreadItems, isEmpty);
    expect(otherThreadItems, hasLength(1));
    expect(otherThreadItems.first.threadId, otherThread.id);
  });
  test('retry delivery stats should track success and reselect requirements',
      () async {
    final remoteThread = _buildThread('th_chat_delivery_stats');
    final fakeSocketService = _FakeChatSocketService();
    final provider = ChatProvider(
      chatService: _FakeChatService(
        threads: [remoteThread],
        hasSessionOverride: true,
      ),
      chatSocketService: fakeSocketService,
    );
    addTearDown(provider.dispose);
    provider.addThread(remoteThread);
    provider.getMessages(remoteThread.id).add(
          Message(
            id: 'retry-stats-text-1',
            content: 'retry me',
            isMe: true,
            timestamp: DateTime.now(),
            status: MessageStatus.failed,
            type: MessageType.text,
          ),
        );

    final resent =
        provider.resendMessage(remoteThread.id, 'retry-stats-text-1');
    expect(resent, isTrue);

    fakeSocketService.onMessageAck?.call(
      MessageAckEvent(
        threadId: remoteThread.id,
        clientMsgId: 'retry-stats-text-1',
        message: Message(
          id: 'retry-stats-text-remote-1',
          content: 'retry me',
          isMe: true,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
          type: MessageType.text,
        ),
      ),
    );

    provider.getMessages(remoteThread.id).add(
          Message(
            id: 'retry-stats-image-1',
            content: '[图片]',
            isMe: true,
            timestamp: DateTime.now(),
            status: MessageStatus.failed,
            type: MessageType.image,
            imagePath: r'C:\mock\missing-original.jpg',
            imageQuality: ImageQuality.original,
          ),
        );

    final imageResent = await provider.resendImageMessage(
      remoteThread.id,
      'retry-stats-image-1',
    );

    expect(imageResent, isFalse);
    expect(provider.deliveryStats['retries_requested'], 1);
    expect(provider.deliveryStats['retries_succeeded'], 1);
    expect(provider.deliveryStats['retries_failed'], 0);
    expect(provider.deliveryStats['text_succeeded'], 1);
    expect(provider.deliveryStats['image_reselect_required'], 1);
    expect(provider.recentDeliveryEvents, isNotEmpty);
    expect(provider.recentDeliveryEvents.first.label, '原图失效，需重选图片');
    expect(provider.recentDeliveryEvents.first.tagLabel, '图片');
    expect(provider.hasDeliveryStats, isTrue);
  });

  test('resetDeliveryStats should clear delivery counters', () async {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final thread = _buildThread('u_chat_delivery_stats_reset');
    provider.addThread(thread);
    provider.getMessages(thread.id).add(
          Message(
            id: 'retry-stats-reset-image-1',
            content: '[图片]',
            isMe: true,
            timestamp: DateTime.now(),
            status: MessageStatus.failed,
            type: MessageType.image,
            imagePath: r'C:\mock\missing-reset.jpg',
            imageQuality: ImageQuality.original,
          ),
        );

    await provider.resendImageMessage(thread.id, 'retry-stats-reset-image-1');

    expect(provider.hasDeliveryStats, isTrue);

    provider.resetDeliveryStats();

    expect(provider.hasDeliveryStats, isFalse);
    expect(
      provider.deliveryStats.values.every((value) => value == 0),
      isTrue,
    );
    expect(provider.recentDeliveryEvents, isEmpty);
  });
}

class _FakeChatService extends ChatService {
  _FakeChatService({
    this.threads = const <ChatThread>[],
    this.messagesByThread = const <String, List<Message>>{},
    this.directThreadsByUserId = const <String, ChatThread>{},
    this.createDirectThreadDelay = Duration.zero,
    this.loadMessagesDelay = Duration.zero,
    this.hasSessionOverride = false,
    this.threadSnapshot,
    this.failThreadHydration = false,
  });

  final List<ChatThread> threads;
  ChatThreadHydrationSnapshot? threadSnapshot;
  final Map<String, List<Message>> messagesByThread;
  final Map<String, ChatThread> directThreadsByUserId;
  final Duration createDirectThreadDelay;
  final Map<String, int> loadMessagesCalls = <String, int>{};
  final Map<String, int> markThreadReadCalls = <String, int>{};
  final Duration loadMessagesDelay;
  final bool hasSessionOverride;
  final bool failThreadHydration;

  @override
  bool get hasSession => hasSessionOverride;

  @override
  Future<List<ChatThread>> loadThreads() async => threads;

  @override
  Future<ChatThreadHydrationSnapshot?> loadThreadHydrationSnapshot() async {
    if (failThreadHydration) {
      return null;
    }
    return threadSnapshot ?? ChatThreadHydrationSnapshot(threads: threads);
  }

  @override
  Future<List<Message>> loadMessages(String threadId) async {
    loadMessagesCalls[threadId] = (loadMessagesCalls[threadId] ?? 0) + 1;
    if (loadMessagesDelay > Duration.zero) {
      await Future<void>.delayed(loadMessagesDelay);
    }
    return messagesByThread[threadId] ?? const <Message>[];
  }

  @override
  Future<ChatThread?> createDirectThread(User user) async {
    if (createDirectThreadDelay > Duration.zero) {
      await Future<void>.delayed(createDirectThreadDelay);
    }
    return directThreadsByUserId[user.id];
  }

  @override
  Future<void> markThreadRead(
    String threadId, {
    String? lastReadMessageId,
  }) async {
    markThreadReadCalls[threadId] = (markThreadReadCalls[threadId] ?? 0) + 1;
  }
}

class _FakeChatSocketService implements ChatSocketService {
  @override
  ValueChanged<String>? onConnected;

  @override
  ValueChanged<MessageAckEvent>? onMessageAck;

  @override
  ValueChanged<IncomingMessageEvent>? onMessageNew;

  @override
  ValueChanged<PeerReadEvent>? onPeerRead;

  @override
  ValueChanged<ChatThread>? onThreadUpdated;

  @override
  ValueChanged<String>? onError;

  final Map<String, int> joinCalls = <String, int>{};
  final Map<String, int> markReadCalls = <String, int>{};
  final Map<String, List<String?>> markReadMessageIdsByThread =
      <String, List<String?>>{};
  final Map<String, int> sendImageCalls = <String, int>{};
  final Map<String, int> sendTextCalls = <String, int>{};

  @override
  bool get isConnected => true;

  @override
  Future<bool> connect() async => true;

  @override
  void disconnect() {}

  @override
  Future<bool> joinThread(String threadId) async {
    joinCalls[threadId] = (joinCalls[threadId] ?? 0) + 1;
    return true;
  }

  @override
  Future<bool> markRead(String threadId, {String? lastReadMessageId}) async {
    markReadCalls[threadId] = (markReadCalls[threadId] ?? 0) + 1;
    markReadMessageIdsByThread.putIfAbsent(threadId, () => <String?>[]).add(
          lastReadMessageId,
        );
    return true;
  }

  @override
  Future<bool> sendImage({
    required String threadId,
    required String imageKey,
    required bool burnAfterReading,
    required String clientMsgId,
  }) async {
    sendImageCalls[threadId] = (sendImageCalls[threadId] ?? 0) + 1;
    return true;
  }

  @override
  Future<bool> sendText({
    required String threadId,
    required String content,
    required String clientMsgId,
  }) async {
    sendTextCalls[threadId] = (sendTextCalls[threadId] ?? 0) + 1;
    return true;
  }

  void emitConnected(String userId) {
    onConnected?.call(userId);
  }
}

class _FakeMediaUploadService extends MediaUploadService {
  _FakeMediaUploadService({
    required this.preparedUploadBuilder,
  });

  final PreparedChatImageUpload Function(String threadId, File imageFile)
      preparedUploadBuilder;

  @override
  Future<PreparedChatImageUpload> prepareChatImageUpload(
    String threadId,
    File imageFile,
  ) async {
    return preparedUploadBuilder(threadId, imageFile);
  }
}
