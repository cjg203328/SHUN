import { ChatService } from '../src/modules/chat/application/chat.service';
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

  it('persists match quota consumption', async () => {
    const userStore = new InMemoryUserSettingsStore();
    const runtimeStore = new InMemoryRuntimeStateStore();
    const userA = buildUser(3);
    const userB = buildUser(4);
    await userStore.saveUser(userA);
    await userStore.saveUser(userB);

    const friendsService = new FriendsService(userStore, runtimeStore);
    await friendsService.onModuleInit();

    const matchV1 = new MatchService(friendsService, runtimeStore);
    await matchV1.onModuleInit();
    const quota = await matchV1.getQuota(asTokenUser(userA));
    await matchV1.startMatch(asTokenUser(userA), [userB.userId]);

    const matchV2 = new MatchService(friendsService, runtimeStore);
    await matchV2.onModuleInit();
    const quotaAfterReload = await matchV2.getQuota(asTokenUser(userA));
    expect(quotaAfterReload.remaining).toBe(quota.remaining - 1);
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
});
