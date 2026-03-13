import { ChatService } from '../src/modules/chat/application/chat.service';
import { ErrorCode } from '../src/common/errors/error-codes';
import { FriendsService } from '../src/modules/friends/application/friends.service';
import { MatchService } from '../src/modules/match/application/match.service';
import { TokenUser } from '../src/modules/auth/domain/token-user';
import { UserEntity } from '../src/modules/shared/domain/entities';
import { InMemoryRuntimeStateStore } from '../src/modules/shared/infrastructure/in-memory-runtime-state.store';
import { InMemoryUserSettingsStore } from '../src/modules/shared/infrastructure/in-memory-user-settings.store';

function buildUser(index: number): UserEntity {
  return {
    userId: `u_test_${index}`,
    uid: `SNTEST${1000 + index}`,
    phone: `1380013800${index}`,
    nickname: `user_${index}`,
    signature: '',
    status: '',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
}

function asTokenUser(user: UserEntity): TokenUser {
  return {
    userId: user.userId,
    uid: user.uid,
    phone: user.phone,
  };
}

describe('Runtime state persistence', () => {
  it('persists friends requests and friendships via runtime store snapshot', async () => {
    const userStore = new InMemoryUserSettingsStore();
    const runtimeStore = new InMemoryRuntimeStateStore();
    const userA = buildUser(1);
    const userB = buildUser(2);
    await userStore.saveUser(userA);
    await userStore.saveUser(userB);

    const friendsV1 = new FriendsService(userStore, runtimeStore);
    await friendsV1.onModuleInit();
    const request = await friendsV1.createRequest(asTokenUser(userA), userB.userId, 'hello');

    const friendsV2 = new FriendsService(userStore, runtimeStore);
    await friendsV2.onModuleInit();
    const pending = await friendsV2.listPendingRequests(asTokenUser(userB));
    expect(pending.some((item) => item.requestId === request.requestId)).toBe(true);

    await friendsV2.acceptRequest(asTokenUser(userB), request.requestId);
    const friendsV3 = new FriendsService(userStore, runtimeStore);
    await friendsV3.onModuleInit();
    const friends = await friendsV3.listFriends(asTokenUser(userA));
    expect(friends.some((item) => item.userId === userB.userId)).toBe(true);
  });

  it('blocking user removes friendship and pending requests from runtime state', async () => {
    const userStore = new InMemoryUserSettingsStore();
    const runtimeStore = new InMemoryRuntimeStateStore();
    const userA = buildUser(11);
    const userB = buildUser(12);
    const userC = buildUser(13);
    await userStore.saveUser(userA);
    await userStore.saveUser(userB);
    await userStore.saveUser(userC);

    const friendsV1 = new FriendsService(userStore, runtimeStore);
    await friendsV1.onModuleInit();
    const acceptedRequest = await friendsV1.createRequest(
      asTokenUser(userA),
      userB.userId,
      'friend-me',
    );
    await friendsV1.acceptRequest(asTokenUser(userB), acceptedRequest.requestId);
    await friendsV1.createRequest(
      asTokenUser(userC),
      userA.userId,
      'pending-before-block',
    );

    await friendsV1.blockUser(asTokenUser(userA), userB.userId);
    await friendsV1.blockUser(asTokenUser(userA), userC.userId);

    const friendsV2 = new FriendsService(userStore, runtimeStore);
    await friendsV2.onModuleInit();
    const friendsForA = await friendsV2.listFriends(asTokenUser(userA));
    expect(friendsForA.some((item) => item.userId === userB.userId)).toBe(false);

    const pendingForA = await friendsV2.listPendingRequests(asTokenUser(userA));
    expect(pendingForA.some((item) => item.fromUser.userId === userC.userId)).toBe(false);
    expect(friendsV2.isBlockedBetween(userA.userId, userB.userId)).toBe(true);
    expect(friendsV2.isBlockedBetween(userA.userId, userC.userId)).toBe(true);
    expect(friendsV2.isFriendBetween(userA.userId, userB.userId)).toBe(false);
  });

  it('persists match quota consumption', async () => {
    const previousAppEnv = process.env.APP_ENV;
    try {
      process.env.APP_ENV = 'test';
      const userStore = new InMemoryUserSettingsStore();
      const runtimeStore = new InMemoryRuntimeStateStore();
      const userA = buildUser(3);
      const userB = buildUser(4);
      await userStore.saveUser(userA);
      await userStore.saveUser(userB);

      const friendsService = new FriendsService(userStore, runtimeStore);
      await friendsService.onModuleInit();

      const matchV1 = new MatchService(friendsService, runtimeStore, userStore);
      await matchV1.onModuleInit();
      const quota = await matchV1.getQuota(asTokenUser(userA));
      await matchV1.startMatch(asTokenUser(userA), [userB.userId]);

      const matchV2 = new MatchService(friendsService, runtimeStore, userStore);
      await matchV2.onModuleInit();
      const quotaAfterReload = await matchV2.getQuota(asTokenUser(userA));
      expect(quotaAfterReload.remaining).toBe(quota.remaining - 1);
    } finally {
      process.env.APP_ENV = previousAppEnv;
    }
  });

  it('does not register demo candidates outside demo-like environments', async () => {
    const previousAppEnv = process.env.APP_ENV;
    try {
      process.env.APP_ENV = 'staging';

      const userStore = new InMemoryUserSettingsStore();
      const runtimeStore = new InMemoryRuntimeStateStore();
      const userA = buildUser(30);
      await userStore.saveUser(userA);

      const friendsService = new FriendsService(userStore, runtimeStore);
      await friendsService.onModuleInit();

      const matchService = new MatchService(
        friendsService,
        runtimeStore,
        userStore,
      );
      await matchService.onModuleInit();

      await expect(
        matchService.startMatch(asTokenUser(userA)),
      ).rejects.toMatchObject({
        code: ErrorCode.MatchUnavailable,
        status: 503,
      });
      await expect(userStore.getUserById('u_001')).resolves.toBeNull();
    } finally {
      process.env.APP_ENV = previousAppEnv;
    }
  });

  it('persists chat threads/messages/read-state', async () => {
    const userStore = new InMemoryUserSettingsStore();
    const runtimeStore = new InMemoryRuntimeStateStore();
    const userA = buildUser(5);
    const userB = buildUser(6);
    await userStore.saveUser(userA);
    await userStore.saveUser(userB);

    const friendsService = new FriendsService(userStore, runtimeStore);
    await friendsService.onModuleInit();

    const chatV1 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV1.onModuleInit();
    const thread = await chatV1.createDirectThread(asTokenUser(userA), userB.userId);
    const message = await chatV1.sendTextMessage(
      asTokenUser(userA),
      thread.threadId,
      'hello',
    );

    const chatV2 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV2.onModuleInit();
    const threadsForB = await chatV2.listThreads(asTokenUser(userB));
    const threadForB = threadsForB.find((item) => item.threadId === thread.threadId);
    expect(threadForB?.unreadCount).toBe(1);
    await chatV2.markThreadRead(asTokenUser(userB), thread.threadId);

    const chatV3 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV3.onModuleInit();
    const messagesForA = await chatV3.listMessages(asTokenUser(userA), thread.threadId);
    const ownMessage = messagesForA.find((item) => item.messageId === message.messageId);
    expect(ownMessage?.isRead).toBe(true);
  });

  it('persists partial read-state up to lastReadMessageId', async () => {
    const userStore = new InMemoryUserSettingsStore();
    const runtimeStore = new InMemoryRuntimeStateStore();
    const userA = buildUser(7);
    const userB = buildUser(8);
    await userStore.saveUser(userA);
    await userStore.saveUser(userB);

    const friendsService = new FriendsService(userStore, runtimeStore);
    await friendsService.onModuleInit();

    const chatV1 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV1.onModuleInit();
    const thread = await chatV1.createDirectThread(asTokenUser(userA), userB.userId);
    const first = await chatV1.sendTextMessage(
      asTokenUser(userA),
      thread.threadId,
      'first',
    );
    const second = await chatV1.sendTextMessage(
      asTokenUser(userA),
      thread.threadId,
      'second',
    );
    await chatV1.sendTextMessage(
      asTokenUser(userA),
      thread.threadId,
      'third',
    );

    const chatV2 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV2.onModuleInit();
    await chatV2.markThreadRead(asTokenUser(userB), thread.threadId, second.messageId);

    const chatV3 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV3.onModuleInit();
    const threadsForB = await chatV3.listThreads(asTokenUser(userB));
    const threadForB = threadsForB.find((item) => item.threadId === thread.threadId);
    expect(threadForB?.unreadCount).toBe(1);

    const messagesForA = await chatV3.listMessages(asTokenUser(userA), thread.threadId);
    const firstForA = messagesForA.find((item) => item.messageId === first.messageId);
    const secondForA = messagesForA.find((item) => item.messageId === second.messageId);
    const thirdForA = messagesForA.find((item) => item.content === 'third');
    expect(firstForA?.isRead).toBe(true);
    expect(secondForA?.isRead).toBe(true);
    expect(thirdForA?.isRead).toBe(false);
  });

  it('recalled unread message no longer counts toward peer unread after reload', async () => {
    const userStore = new InMemoryUserSettingsStore();
    const runtimeStore = new InMemoryRuntimeStateStore();
    const userA = buildUser(14);
    const userB = buildUser(15);
    await userStore.saveUser(userA);
    await userStore.saveUser(userB);

    const friendsService = new FriendsService(userStore, runtimeStore);
    await friendsService.onModuleInit();

    const chatV1 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV1.onModuleInit();
    const thread = await chatV1.createDirectThread(asTokenUser(userA), userB.userId);
    const message = await chatV1.sendTextMessage(
      asTokenUser(userA),
      thread.threadId,
      'recall-before-read',
    );

    const chatV2 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV2.onModuleInit();
    const threadsBeforeRecall = await chatV2.listThreads(asTokenUser(userB));
    const threadBeforeRecall = threadsBeforeRecall.find(
      (item) => item.threadId === thread.threadId,
    );
    expect(threadBeforeRecall?.unreadCount).toBe(1);

    await chatV2.recallMessage(asTokenUser(userA), message.messageId);

    const chatV3 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV3.onModuleInit();
    const threadsAfterRecall = await chatV3.listThreads(asTokenUser(userB));
    const threadAfterRecall = threadsAfterRecall.find(
      (item) => item.threadId === thread.threadId,
    );
    expect(threadAfterRecall?.unreadCount).toBe(0);
  });

  it('marking thread as read does not reorder thread list', async () => {
    const userStore = new InMemoryUserSettingsStore();
    const runtimeStore = new InMemoryRuntimeStateStore();
    const userA = buildUser(16);
    const userB = buildUser(17);
    const userC = buildUser(18);
    await userStore.saveUser(userA);
    await userStore.saveUser(userB);
    await userStore.saveUser(userC);

    const friendsService = new FriendsService(userStore, runtimeStore);
    await friendsService.onModuleInit();

    const chatV1 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV1.onModuleInit();
    const threadAB = await chatV1.createDirectThread(asTokenUser(userA), userB.userId);
    const threadAC = await chatV1.createDirectThread(asTokenUser(userA), userC.userId);
    await chatV1.sendTextMessage(asTokenUser(userA), threadAB.threadId, 'older-thread-message');
    await chatV1.sendTextMessage(asTokenUser(userA), threadAC.threadId, 'newer-thread-message');

    const snapshot = await runtimeStore.getJson<{
      threads: Array<{ threadId: string; updatedAt: string }>;
    }>('chat:state:v1');
    if (!snapshot) {
      throw new Error('chat snapshot not found');
    }
    const abSnapshot = snapshot.threads.find((item) => item.threadId === threadAB.threadId);
    const acSnapshot = snapshot.threads.find((item) => item.threadId === threadAC.threadId);
    if (!abSnapshot || !acSnapshot) {
      throw new Error('thread snapshot not found');
    }
    abSnapshot.updatedAt = '2026-03-10T00:00:00.000Z';
    acSnapshot.updatedAt = '2026-03-11T00:00:00.000Z';
    await runtimeStore.setJson('chat:state:v1', snapshot);

    const chatV2 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV2.onModuleInit();
    await chatV2.markThreadRead(asTokenUser(userB), threadAB.threadId);

    const threadsForA = await chatV2.listThreads(asTokenUser(userA));
    expect(threadsForA.map((item) => item.threadId)).toEqual([
      threadAC.threadId,
      threadAB.threadId,
    ]);
  });

  it('reopening existing direct thread does not reorder thread list', async () => {
    const userStore = new InMemoryUserSettingsStore();
    const runtimeStore = new InMemoryRuntimeStateStore();
    const userA = buildUser(19);
    const userB = buildUser(20);
    const userC = buildUser(21);
    await userStore.saveUser(userA);
    await userStore.saveUser(userB);
    await userStore.saveUser(userC);

    const friendsService = new FriendsService(userStore, runtimeStore);
    await friendsService.onModuleInit();

    const chatV1 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV1.onModuleInit();
    const threadAB = await chatV1.createDirectThread(asTokenUser(userA), userB.userId);
    const threadAC = await chatV1.createDirectThread(asTokenUser(userA), userC.userId);

    const snapshot = await runtimeStore.getJson<{
      threads: Array<{ threadId: string; updatedAt: string }>;
    }>('chat:state:v1');
    if (!snapshot) {
      throw new Error('chat snapshot not found');
    }
    const abSnapshot = snapshot.threads.find((item) => item.threadId === threadAB.threadId);
    const acSnapshot = snapshot.threads.find((item) => item.threadId === threadAC.threadId);
    if (!abSnapshot || !acSnapshot) {
      throw new Error('thread snapshot not found');
    }
    abSnapshot.updatedAt = '2026-03-10T00:00:00.000Z';
    acSnapshot.updatedAt = '2026-03-11T00:00:00.000Z';
    await runtimeStore.setJson('chat:state:v1', snapshot);

    const chatV2 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV2.onModuleInit();
    await chatV2.createDirectThread(asTokenUser(userA), userB.userId);

    const threadsForA = await chatV2.listThreads(asTokenUser(userA));
    expect(threadsForA.map((item) => item.threadId)).toEqual([
      threadAC.threadId,
      threadAB.threadId,
    ]);
  });

  it('reopening expired stranger thread refreshes expiry window', async () => {
    const userStore = new InMemoryUserSettingsStore();
    const runtimeStore = new InMemoryRuntimeStateStore();
    const userA = buildUser(22);
    const userB = buildUser(23);
    await userStore.saveUser(userA);
    await userStore.saveUser(userB);

    const friendsService = new FriendsService(userStore, runtimeStore);
    await friendsService.onModuleInit();

    const chatV1 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV1.onModuleInit();
    const thread = await chatV1.createDirectThread(asTokenUser(userA), userB.userId);

    const snapshot = await runtimeStore.getJson<{
      threads: Array<{ threadId: string; expiresAt: string; isFriend: boolean }>;
    }>('chat:state:v1');
    if (!snapshot) {
      throw new Error('chat snapshot not found');
    }
    const threadSnapshot = snapshot.threads.find((item) => item.threadId === thread.threadId);
    if (!threadSnapshot) {
      throw new Error('thread snapshot not found');
    }
    threadSnapshot.expiresAt = new Date(Date.now() - 60_000).toISOString();
    threadSnapshot.isFriend = false;
    await runtimeStore.setJson('chat:state:v1', snapshot);

    const chatV2 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV2.onModuleInit();
    const reopened = await chatV2.createDirectThread(asTokenUser(userA), userB.userId);
    expect(Date.parse(reopened.expiresAt)).toBeGreaterThan(Date.now());

    const sent = await chatV2.sendTextMessage(asTokenUser(userA), reopened.threadId, 'after-reopen');
    expect(sent.threadId).toBe(reopened.threadId);
  });

  it('reopening existing friend thread keeps its expiry unchanged', async () => {
    const userStore = new InMemoryUserSettingsStore();
    const runtimeStore = new InMemoryRuntimeStateStore();
    const userA = buildUser(24);
    const userB = buildUser(25);
    await userStore.saveUser(userA);
    await userStore.saveUser(userB);

    const friendsService = new FriendsService(userStore, runtimeStore);
    await friendsService.onModuleInit();
    const acceptedRequest = await friendsService.createRequest(
      asTokenUser(userA),
      userB.userId,
      'friend-expiry',
    );
    await friendsService.acceptRequest(asTokenUser(userB), acceptedRequest.requestId);

    const chatV1 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV1.onModuleInit();
    const thread = await chatV1.createDirectThread(asTokenUser(userA), userB.userId);

    const snapshot = await runtimeStore.getJson<{
      threads: Array<{ threadId: string; expiresAt: string; isFriend: boolean }>;
    }>('chat:state:v1');
    if (!snapshot) {
      throw new Error('chat snapshot not found');
    }
    const threadSnapshot = snapshot.threads.find((item) => item.threadId === thread.threadId);
    if (!threadSnapshot) {
      throw new Error('thread snapshot not found');
    }
    const fixedExpiry = '2026-04-01T00:00:00.000Z';
    threadSnapshot.expiresAt = fixedExpiry;
    threadSnapshot.isFriend = true;
    await runtimeStore.setJson('chat:state:v1', snapshot);

    const chatV2 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV2.onModuleInit();
    const reopened = await chatV2.createDirectThread(asTokenUser(userA), userB.userId);
    expect(reopened.expiresAt).toBe(fixedExpiry);
  });

  it('validates image burn settings in chat service for all callers', async () => {
    const userStore = new InMemoryUserSettingsStore();
    const runtimeStore = new InMemoryRuntimeStateStore();
    const userA = buildUser(26);
    const userB = buildUser(27);
    await userStore.saveUser(userA);
    await userStore.saveUser(userB);

    const friendsService = new FriendsService(userStore, runtimeStore);
    await friendsService.onModuleInit();

    const chat = new ChatService(userStore, friendsService, runtimeStore);
    await chat.onModuleInit();
    const thread = await chat.createDirectThread(asTokenUser(userA), userB.userId);

    await expect(
      chat.sendImageMessageByActor(
        { userId: userA.userId },
        thread.threadId,
        'chat/test/image-a.jpg',
        false,
        5,
      ),
    ).rejects.toMatchObject({
      code: ErrorCode.InvalidInput,
      status: 400,
    });

    await expect(
      chat.sendImageMessageByActor(
        { userId: userA.userId },
        thread.threadId,
        'chat/test/image-b.jpg',
        true,
        0,
      ),
    ).rejects.toMatchObject({
      code: ErrorCode.InvalidInput,
      status: 400,
    });
  });

  it('deleting thread clears historical unread so restored thread only counts new messages', async () => {
    const userStore = new InMemoryUserSettingsStore();
    const runtimeStore = new InMemoryRuntimeStateStore();
    const userA = buildUser(28);
    const userB = buildUser(29);
    await userStore.saveUser(userA);
    await userStore.saveUser(userB);

    const friendsService = new FriendsService(userStore, runtimeStore);
    await friendsService.onModuleInit();

    const chatV1 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV1.onModuleInit();
    const thread = await chatV1.createDirectThread(asTokenUser(userA), userB.userId);
    await chatV1.sendTextMessage(asTokenUser(userB), thread.threadId, 'old-unread-1');
    await chatV1.sendTextMessage(asTokenUser(userB), thread.threadId, 'old-unread-2');

    const threadsBeforeDelete = await chatV1.listThreads(asTokenUser(userA));
    const threadBeforeDelete = threadsBeforeDelete.find(
      (item) => item.threadId === thread.threadId,
    );
    expect(threadBeforeDelete?.unreadCount).toBe(2);

    await chatV1.deleteThread(asTokenUser(userA), thread.threadId);
    await chatV1.sendTextMessage(asTokenUser(userB), thread.threadId, 'new-after-restore');

    const chatV2 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV2.onModuleInit();
    const restoredThreads = await chatV2.listThreads(asTokenUser(userA));
    const restoredThread = restoredThreads.find((item) => item.threadId === thread.threadId);
    expect(restoredThread?.unreadCount).toBe(1);

    const senderViewMessages = await chatV2.listMessages(asTokenUser(userB), thread.threadId);
    const oldMessages = senderViewMessages.filter((item) =>
      item.content.startsWith('old-unread'),
    );
    expect(oldMessages).toHaveLength(2);
    expect(oldMessages.every((item) => item.isRead)).toBe(true);
  });

  it('only allows sending uploaded image keys for the same thread and actor', async () => {
    const userStore = new InMemoryUserSettingsStore();
    const runtimeStore = new InMemoryRuntimeStateStore();
    const userA = buildUser(30);
    const userB = buildUser(31);
    await userStore.saveUser(userA);
    await userStore.saveUser(userB);

    const friendsService = new FriendsService(userStore, runtimeStore);
    await friendsService.onModuleInit();

    const chat = new ChatService(userStore, friendsService, runtimeStore);
    await chat.onModuleInit();
    const thread = await chat.createDirectThread(asTokenUser(userA), userB.userId);

    await expect(
      chat.sendImageMessage(
        asTokenUser(userA),
        thread.threadId,
        `chat/${thread.threadId}/${userA.userId}/missing.jpg`,
        false,
        undefined,
      ),
    ).rejects.toMatchObject({
      code: ErrorCode.InvalidInput,
      status: 400,
    });

    const uploadToken = await chat.createImageUploadToken(asTokenUser(userA), thread.threadId);
    await chat.uploadChatImage(
      asTokenUser(userA),
      thread.threadId,
      {
        uploadToken: uploadToken.uploadToken,
        objectKey: uploadToken.objectKey,
      },
      {
        buffer: Buffer.from([0xff, 0xd8, 0xff, 0xd9]),
        mimetype: 'image/jpeg',
      },
    );

    const sent = await chat.sendImageMessage(
      asTokenUser(userA),
      thread.threadId,
      uploadToken.objectKey,
      true,
      5,
    );
    expect(sent.imageKey).toBe(uploadToken.objectKey);

    await expect(
      chat.sendImageMessage(
        asTokenUser(userB),
        thread.threadId,
        uploadToken.objectKey,
        false,
        undefined,
      ),
    ).rejects.toMatchObject({
      code: ErrorCode.InvalidInput,
      status: 400,
    });
  });

  it('blocks expired stranger thread interactions until relationship becomes friend', async () => {
    const userStore = new InMemoryUserSettingsStore();
    const runtimeStore = new InMemoryRuntimeStateStore();
    const userA = buildUser(9);
    const userB = buildUser(10);
    await userStore.saveUser(userA);
    await userStore.saveUser(userB);

    const friendsService = new FriendsService(userStore, runtimeStore);
    await friendsService.onModuleInit();

    const chatV1 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV1.onModuleInit();
    const thread = await chatV1.createDirectThread(asTokenUser(userA), userB.userId);
    await chatV1.sendTextMessage(asTokenUser(userA), thread.threadId, 'before-expire');

    const snapshot = await runtimeStore.getJson<{
      threads: Array<{ threadId: string; expiresAt: string; isFriend: boolean }>;
    }>('chat:state:v1');
    if (!snapshot) {
      throw new Error('chat snapshot not found');
    }

    const threadSnapshot = snapshot.threads.find((item) => item.threadId === thread.threadId);
    if (!threadSnapshot) {
      throw new Error('thread snapshot not found');
    }
    threadSnapshot.expiresAt = new Date(Date.now() - 60_000).toISOString();
    threadSnapshot.isFriend = false;
    await runtimeStore.setJson('chat:state:v1', snapshot);

    const chatV2 = new ChatService(userStore, friendsService, runtimeStore);
    await chatV2.onModuleInit();
    const listedThreads = await chatV2.listThreads(asTokenUser(userA));
    expect(listedThreads.some((item) => item.threadId === thread.threadId)).toBe(true);
    const existingMessages = await chatV2.listMessages(asTokenUser(userA), thread.threadId);
    expect(existingMessages).toHaveLength(1);

    await expect(
      chatV2.sendTextMessage(asTokenUser(userA), thread.threadId, 'after-expire'),
    ).rejects.toMatchObject({
      code: ErrorCode.ThreadExpired,
      status: 409,
    });
    await expect(
      chatV2.createImageUploadToken(asTokenUser(userA), thread.threadId),
    ).rejects.toMatchObject({
      code: ErrorCode.ThreadExpired,
      status: 409,
    });

    const request = await friendsService.createRequest(
      asTokenUser(userA),
      userB.userId,
      'be-friends',
    );
    await friendsService.acceptRequest(asTokenUser(userB), request.requestId);

    const threadAfterFriend = await chatV2.getThreadSummaryByUserId(
      userA.userId,
      thread.threadId,
    );
    expect(threadAfterFriend.isFriend).toBe(true);

    const sentAfterFriend = await chatV2.sendTextMessage(
      asTokenUser(userA),
      thread.threadId,
      'after-friend',
    );
    expect(sentAfterFriend.threadId).toBe(thread.threadId);
  });
});
