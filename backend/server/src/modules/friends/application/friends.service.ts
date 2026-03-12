import { Inject, Injectable, OnModuleInit } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { BusinessError, ErrorCode } from '../../../common/errors/error-codes';
import { TokenUser } from '../../auth/domain/token-user';
import { UserEntity } from '../../shared/domain/entities';
import { RuntimeStateStore } from '../../shared/ports/runtime-state-store.port';
import { UserSettingsStore } from '../../shared/ports/user-settings-store.port';
import { RUNTIME_STATE_STORE, USER_SETTINGS_STORE } from '../../shared/tokens';

type FriendRequestStatus = 'pending' | 'accepted' | 'rejected';

export interface FriendRequestRuntime {
  requestId: string;
  fromUserId: string;
  toUserId: string;
  message?: string;
  status: FriendRequestStatus;
  createdAt: string;
  updatedAt: string;
}

export interface FriendshipRuntime {
  friendshipId: string;
  userA: string;
  userB: string;
  isMutualFollow: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface FriendListItem {
  id: string;
  userId: string;
  user: UserEntity;
  becameFriendAt: string;
  isMutualFollow: boolean;
}

export interface PendingFriendRequestItem {
  id: string;
  requestId: string;
  fromUser: UserEntity;
  message: string | undefined;
  status: FriendRequestStatus;
  createdAt: string;
}

interface FriendsRuntimeSnapshot {
  version: 1;
  requests: FriendRequestRuntime[];
  friendships: FriendshipRuntime[];
  blockedByUser: Array<{
    userId: string;
    blockedUserIds: string[];
  }>;
}

@Injectable()
export class FriendsService implements OnModuleInit {
  private readonly stateKey = 'friends:state:v1';
  private readonly requests = new Map<string, FriendRequestRuntime>();
  private readonly friendships = new Map<string, FriendshipRuntime>();
  private readonly blockedByUser = new Map<string, Set<string>>();
  private isStateLoaded = false;

  constructor(
    @Inject(USER_SETTINGS_STORE)
    private readonly userStore: UserSettingsStore,
    @Inject(RUNTIME_STATE_STORE)
    private readonly runtimeStateStore: RuntimeStateStore,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.ensureLoaded();
  }

  async searchByUid(actor: TokenUser, uid: string): Promise<UserEntity> {
    await this.ensureLoaded();
    const target = await this.userStore.getUserByUid(uid.trim().toUpperCase());
    if (!target || target.userId === actor.userId) {
      throw new BusinessError(ErrorCode.UidNotFound, 404, 'User not found by uid');
    }
    if (this.isBlockedBetween(actor.userId, target.userId)) {
      throw new BusinessError(
        ErrorCode.BlockedRelation,
        403,
        'Blocked relation does not allow searching',
      );
    }
    return target;
  }

  async listFriends(actor: TokenUser): Promise<FriendListItem[]> {
    await this.ensureLoaded();
    const relatedFriendships = [...this.friendships.values()].filter(
      (friendship) =>
        friendship.userA === actor.userId || friendship.userB === actor.userId,
    );

    const items = await Promise.all(
      relatedFriendships.map(async (friendship) => {
        const peerId =
          friendship.userA === actor.userId ? friendship.userB : friendship.userA;
        const user = await this.userStore.getUserById(peerId);
        if (!user) return null;
        return {
          id: peerId,
          userId: peerId,
          user,
          becameFriendAt: friendship.createdAt,
          isMutualFollow: friendship.isMutualFollow,
        } satisfies FriendListItem;
      }),
    );

    return items.filter((item): item is FriendListItem => item !== null);
  }

  async listPendingRequests(actor: TokenUser): Promise<PendingFriendRequestItem[]> {
    await this.ensureLoaded();
    const requests = [...this.requests.values()].filter(
      (request) => request.toUserId === actor.userId && request.status === 'pending',
    );

    const items: Array<PendingFriendRequestItem | null> = await Promise.all(
      requests.map(async (request) => {
        const fromUser = await this.userStore.getUserById(request.fromUserId);
        if (!fromUser) return null;
        return {
          id: request.requestId,
          requestId: request.requestId,
          fromUser,
          message: request.message,
          status: request.status,
          createdAt: request.createdAt,
        } satisfies PendingFriendRequestItem;
      }),
    );

    return items.filter((item): item is PendingFriendRequestItem => item !== null);
  }

  async createRequest(
    actor: TokenUser,
    targetUserId: string,
    message?: string,
  ): Promise<FriendRequestRuntime> {
    await this.ensureLoaded();
    const target = await this.userStore.getUserById(targetUserId);
    if (!target || target.userId === actor.userId) {
      throw new BusinessError(ErrorCode.UserNotFound, 404, 'Target user not found');
    }
    if (this.isBlockedBetween(actor.userId, target.userId)) {
      throw new BusinessError(
        ErrorCode.BlockedRelation,
        403,
        'Blocked relation does not allow friend request',
      );
    }
    if (this.areFriends(actor.userId, target.userId)) {
      throw new BusinessError(
        ErrorCode.FriendAlreadyExists,
        409,
        'Users are already friends',
      );
    }

    const duplicated = [...this.requests.values()].some(
      (request) =>
        request.status === 'pending' &&
        request.fromUserId === actor.userId &&
        request.toUserId === target.userId,
    );
    if (duplicated) {
      throw new BusinessError(
        ErrorCode.FriendRequestDuplicate,
        409,
        'Pending request already exists',
      );
    }

    const now = new Date().toISOString();
    const created: FriendRequestRuntime = {
      requestId: randomUUID(),
      fromUserId: actor.userId,
      toUserId: target.userId,
      message,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    };
    this.requests.set(created.requestId, created);
    await this.persistState();
    return created;
  }

  async acceptRequest(actor: TokenUser, requestId: string): Promise<FriendshipRuntime> {
    await this.ensureLoaded();
    const request = this.requests.get(requestId);
    if (!request || request.toUserId !== actor.userId) {
      throw new BusinessError(
        ErrorCode.FriendRequestNotFound,
        404,
        'Friend request not found',
      );
    }
    if (request.status !== 'pending') {
      throw new BusinessError(
        ErrorCode.InvalidInput,
        409,
        'Friend request already handled',
      );
    }
    request.status = 'accepted';
    request.updatedAt = new Date().toISOString();
    this.requests.set(request.requestId, request);

    const key = this.friendshipKey(request.fromUserId, request.toUserId);
    const now = new Date().toISOString();
    const friendship: FriendshipRuntime = {
      friendshipId: randomUUID(),
      userA: request.fromUserId,
      userB: request.toUserId,
      isMutualFollow: true,
      createdAt: now,
      updatedAt: now,
    };
    this.friendships.set(key, friendship);
    await this.persistState();
    return friendship;
  }

  async rejectRequest(actor: TokenUser, requestId: string): Promise<void> {
    await this.ensureLoaded();
    const request = this.requests.get(requestId);
    if (!request || request.toUserId !== actor.userId) {
      throw new BusinessError(
        ErrorCode.FriendRequestNotFound,
        404,
        'Friend request not found',
      );
    }
    request.status = 'rejected';
    request.updatedAt = new Date().toISOString();
    this.requests.set(request.requestId, request);
    await this.persistState();
  }

  async blockUser(actor: TokenUser, targetUserId: string): Promise<void> {
    await this.ensureLoaded();
    const target = await this.userStore.getUserById(targetUserId);
    if (!target || target.userId === actor.userId) {
      throw new BusinessError(ErrorCode.UserNotFound, 404, 'Target user not found');
    }
    const blockedSet = this.blockedByUser.get(actor.userId) ?? new Set<string>();
    blockedSet.add(target.userId);
    this.blockedByUser.set(actor.userId, blockedSet);
    this.friendships.delete(this.friendshipKey(actor.userId, target.userId));
    this.resolveRequestsBetweenUsers(actor.userId, target.userId, 'rejected');
    await this.persistState();
  }

  async unblockUser(actor: TokenUser, targetUserId: string): Promise<void> {
    await this.ensureLoaded();
    const blockedSet = this.blockedByUser.get(actor.userId);
    blockedSet?.delete(targetUserId);
    await this.persistState();
  }

  async listBlocked(actor: TokenUser): Promise<UserEntity[]> {
    await this.ensureLoaded();
    const blockedSet = this.blockedByUser.get(actor.userId) ?? new Set<string>();
    const users = await Promise.all(
      [...blockedSet.values()].map((userId) => this.userStore.getUserById(userId)),
    );
    return users.filter((item): item is UserEntity => item !== null);
  }

  isBlockedBetween(userA: string, userB: string): boolean {
    const blockedByA = this.blockedByUser.get(userA);
    const blockedByB = this.blockedByUser.get(userB);
    return blockedByA?.has(userB) === true || blockedByB?.has(userA) === true;
  }

  isFriendBetween(userA: string, userB: string): boolean {
    return this.areFriends(userA, userB);
  }

  private areFriends(userA: string, userB: string): boolean {
    return this.friendships.has(this.friendshipKey(userA, userB));
  }

  private getFriendIds(userId: string): string[] {
    const friends: string[] = [];
    for (const friendship of this.friendships.values()) {
      if (friendship.userA === userId) friends.push(friendship.userB);
      if (friendship.userB === userId) friends.push(friendship.userA);
    }
    return friends;
  }

  private friendshipKey(userA: string, userB: string): string {
    return [userA, userB].sort().join(':');
  }

  private resolveRequestsBetweenUsers(
    userA: string,
    userB: string,
    status: Extract<FriendRequestStatus, 'accepted' | 'rejected'>,
  ): void {
    const now = new Date().toISOString();
    for (const request of this.requests.values()) {
      const matchesUsers =
        (request.fromUserId === userA && request.toUserId === userB) ||
        (request.fromUserId === userB && request.toUserId === userA);
      if (!matchesUsers || request.status !== 'pending') {
        continue;
      }
      request.status = status;
      request.updatedAt = now;
      this.requests.set(request.requestId, request);
    }
  }

  private async ensureLoaded(): Promise<void> {
    if (this.isStateLoaded) return;

    const snapshot = await this.runtimeStateStore.getJson<FriendsRuntimeSnapshot>(
      this.stateKey,
    );
    if (snapshot) {
      this.requests.clear();
      for (const request of snapshot.requests) {
        this.requests.set(request.requestId, request);
      }

      this.friendships.clear();
      for (const friendship of snapshot.friendships) {
        this.friendships.set(
          this.friendshipKey(friendship.userA, friendship.userB),
          friendship,
        );
      }

      this.blockedByUser.clear();
      for (const item of snapshot.blockedByUser) {
        this.blockedByUser.set(item.userId, new Set(item.blockedUserIds));
      }
    }

    this.isStateLoaded = true;
  }

  private async persistState(): Promise<void> {
    const snapshot: FriendsRuntimeSnapshot = {
      version: 1,
      requests: [...this.requests.values()],
      friendships: [...this.friendships.values()],
      blockedByUser: [...this.blockedByUser.entries()].map(([userId, blockedSet]) => ({
        userId,
        blockedUserIds: [...blockedSet.values()],
      })),
    };
    await this.runtimeStateStore.setJson(this.stateKey, snapshot);
  }
}
