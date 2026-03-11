import { Inject, Injectable, OnModuleInit } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { mkdir, writeFile } from 'fs/promises';
import { dirname, resolve } from 'path';
import { BusinessError, ErrorCode } from '../../../common/errors/error-codes';
import { TokenUser } from '../../auth/domain/token-user';
import { FriendsService } from '../../friends/application/friends.service';
import { RuntimeStateStore } from '../../shared/ports/runtime-state-store.port';
import { UserSettingsStore } from '../../shared/ports/user-settings-store.port';
import { RUNTIME_STATE_STORE, USER_SETTINGS_STORE } from '../../shared/tokens';
import { UploadChatImageDto } from '../dto/upload-chat-image.dto';

type MessageType = 'text' | 'image';
type MessageStatus = 'sent' | 'recalled';

interface ThreadRuntime {
  threadId: string;
  userA: string;
  userB: string;
  createdAt: string;
  updatedAt: string;
  expiresAt: string;
  isFriend: boolean;
  deletedBy: Set<string>;
}

interface MessageRuntime {
  messageId: string;
  threadId: string;
  senderId: string;
  type: MessageType;
  content: string;
  imageKey?: string;
  isBurnAfterReading: boolean;
  burnSeconds?: number;
  status: MessageStatus;
  createdAt: string;
  recalledAt?: string;
  clientMsgId?: string;
  readBy: Set<string>;
}

interface ThreadRuntimeSnapshot extends Omit<ThreadRuntime, 'deletedBy'> {
  deletedBy: string[];
}

interface MessageRuntimeSnapshot extends Omit<MessageRuntime, 'readBy'> {
  readBy: string[];
}

interface ChatRuntimeSnapshot {
  version: 1;
  threads: ThreadRuntimeSnapshot[];
  messagesByThread: Array<{
    threadId: string;
    messages: MessageRuntimeSnapshot[];
  }>;
  unreadCountByThreadUser: Array<{
    key: string;
    count: number;
  }>;
}

interface UploadedImageFile {
  buffer: Buffer;
  mimetype?: string;
}

export interface ThreadSummary {
  threadId: string;
  user: {
    userId: string;
    uid: string;
    nickname: string;
    avatarUrl?: string;
    status: string;
  };
  unreadCount: number;
  isFriend: boolean;
  createdAt: string;
  updatedAt: string;
  expiresAt: string;
}

export interface MessageView {
  messageId: string;
  threadId: string;
  type: MessageType;
  content: string;
  imageKey?: string;
  isBurnAfterReading: boolean;
  burnSeconds?: number;
  status: MessageStatus;
  isMe: boolean;
  isRead: boolean;
  createdAt: string;
  recalledAt?: string;
  clientMsgId?: string;
}

export interface ImageUploadTokenView {
  uploadToken: string;
  objectKey: string;
  expireSeconds: number;
}

export interface UploadedChatImageView {
  objectKey: string;
  uploaded: true;
}

interface ActorContext {
  userId: string;
}

@Injectable()
export class ChatService implements OnModuleInit {
  private readonly stateKey = 'chat:state:v1';
  private readonly threads = new Map<string, ThreadRuntime>();
  private readonly messagesByThread = new Map<string, MessageRuntime[]>();
  private readonly unreadCountByThreadUser = new Map<string, number>();
  private readonly messageIndex = new Map<string, MessageRuntime>();
  private isStateLoaded = false;

  constructor(
    @Inject(USER_SETTINGS_STORE)
    private readonly userStore: UserSettingsStore,
    private readonly friendsService: FriendsService,
    @Inject(RUNTIME_STATE_STORE)
    private readonly runtimeStateStore: RuntimeStateStore,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.ensureLoaded();
  }

  async createDirectThread(actor: TokenUser, targetUserId: string): Promise<ThreadSummary> {
    await this.ensureLoaded();
    if (targetUserId === actor.userId) {
      throw new BusinessError(ErrorCode.InvalidInput, 400, 'Cannot create thread with self');
    }

    const target = await this.userStore.getUserById(targetUserId);
    if (!target) {
      throw new BusinessError(ErrorCode.UserNotFound, 404, 'Target user not found');
    }
    if (this.friendsService.isBlockedBetween(actor.userId, targetUserId)) {
      throw new BusinessError(
        ErrorCode.BlockedRelation,
        403,
        'Blocked relation does not allow opening thread',
      );
    }

    const key = this.threadKey(actor.userId, targetUserId);
    let thread = this.threads.get(key);
    if (!thread) {
      const now = new Date();
      thread = {
        threadId: `th_${randomUUID()}`,
        userA: actor.userId,
        userB: targetUserId,
        createdAt: now.toISOString(),
        updatedAt: now.toISOString(),
        expiresAt: new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString(),
        isFriend: this.friendsService.isFriendBetween(actor.userId, targetUserId),
        deletedBy: new Set<string>(),
      };
      this.threads.set(key, thread);
      this.messagesByThread.set(thread.threadId, []);
    } else {
      thread.deletedBy.delete(actor.userId);
      thread.updatedAt = new Date().toISOString();
      thread.isFriend = this.friendsService.isFriendBetween(actor.userId, targetUserId);
      this.threads.set(key, thread);
    }

    this.ensureUnreadCounter(thread.threadId, actor.userId);
    this.ensureUnreadCounter(thread.threadId, targetUserId);
    await this.persistState();
    return this.toThreadSummary(actor.userId, thread);
  }

  async listThreads(actor: TokenUser): Promise<ThreadSummary[]> {
    await this.ensureLoaded();
    const ownThreads = [...this.threads.values()].filter((thread) => {
      if (!this.isThreadMember(actor.userId, thread)) return false;
      if (thread.deletedBy.has(actor.userId)) return false;
      return true;
    });

    const summaries = await Promise.all(
      ownThreads.map((thread) => this.toThreadSummary(actor.userId, thread)),
    );
    summaries.sort((a, b) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt));
    return summaries;
  }

  async listMessages(actor: TokenUser, threadId: string): Promise<MessageView[]> {
    await this.ensureLoaded();
    return this.listMessagesByUserId(actor.userId, threadId);
  }

  async listMessagesByUserId(
    actorUserId: string,
    threadId: string,
  ): Promise<MessageView[]> {
    await this.ensureLoaded();
    const thread = this.getThreadById(threadId);
    this.assertThreadAccessible(actorUserId, thread);
    const peerUserId = this.peerUserId(actorUserId, thread);
    const items = this.messagesByThread.get(thread.threadId) ?? [];
    return items.map((message) => this.toMessageView(actorUserId, peerUserId, message));
  }

  async getThreadSummaryByUserId(
    actorUserId: string,
    threadId: string,
  ): Promise<ThreadSummary> {
    await this.ensureLoaded();
    const thread = this.getThreadById(threadId);
    this.assertThreadAccessible(actorUserId, thread);
    return this.toThreadSummary(actorUserId, thread);
  }

  getThreadPeerUserId(actorUserId: string, threadId: string): string {
    const thread = this.getThreadById(threadId);
    this.assertThreadAccessible(actorUserId, thread);
    return this.peerUserId(actorUserId, thread);
  }

  async getMessageViewForUser(
    actorUserId: string,
    messageId: string,
  ): Promise<MessageView> {
    await this.ensureLoaded();
    const message = this.messageIndex.get(messageId);
    if (!message) {
      throw new BusinessError(ErrorCode.MessageNotFound, 404, 'Message not found');
    }
    const thread = this.getThreadById(message.threadId);
    this.assertThreadAccessible(actorUserId, thread);
    const peerUserId = this.peerUserId(actorUserId, thread);
    return this.toMessageView(actorUserId, peerUserId, message);
  }

  async sendTextMessage(
    actor: TokenUser,
    threadId: string,
    content: string,
    clientMsgId?: string,
  ): Promise<MessageView> {
    await this.ensureLoaded();
    return this.sendTextMessageByActor({ userId: actor.userId }, threadId, content, clientMsgId);
  }

  async sendTextMessageByActor(
    actor: ActorContext,
    threadId: string,
    content: string,
    clientMsgId?: string,
  ): Promise<MessageView> {
    await this.ensureLoaded();
    const normalized = content.trim();
    if (!normalized) {
      throw new BusinessError(ErrorCode.InvalidInput, 400, 'Message content is empty');
    }
    return this.sendMessage(actor, threadId, {
      type: 'text',
      content: normalized,
      clientMsgId,
      isBurnAfterReading: false,
    });
  }

  async sendImageMessage(
    actor: TokenUser,
    threadId: string,
    imageKey: string,
    burnAfterReading: boolean,
    burnSeconds: number | undefined,
    clientMsgId?: string,
  ): Promise<MessageView> {
    await this.ensureLoaded();
    return this.sendImageMessageByActor(
      { userId: actor.userId },
      threadId,
      imageKey,
      burnAfterReading,
      burnSeconds,
      clientMsgId,
    );
  }

  async sendImageMessageByActor(
    actor: ActorContext,
    threadId: string,
    imageKey: string,
    burnAfterReading: boolean,
    burnSeconds: number | undefined,
    clientMsgId?: string,
  ): Promise<MessageView> {
    await this.ensureLoaded();
    const normalizedKey = imageKey.trim();
    if (!normalizedKey) {
      throw new BusinessError(ErrorCode.InvalidInput, 400, 'Image key is empty');
    }
    const normalizedBurnSeconds = burnAfterReading ? burnSeconds ?? 5 : undefined;
    return this.sendMessage(actor, threadId, {
      type: 'image',
      content: '[image]',
      imageKey: normalizedKey,
      clientMsgId,
      isBurnAfterReading: burnAfterReading,
      burnSeconds: normalizedBurnSeconds,
    });
  }

  async createImageUploadToken(
    actor: TokenUser,
    threadId: string,
  ): Promise<ImageUploadTokenView> {
    await this.ensureLoaded();
    const thread = this.getThreadById(threadId);
    this.assertThreadAccessible(actor.userId, thread);

    return {
      uploadToken: `upl_chat_${randomUUID()}`,
      objectKey: `chat/${threadId}/${actor.userId}/${Date.now()}.jpg`,
      expireSeconds: 300,
    };
  }

  async uploadChatImage(
    actor: TokenUser,
    threadId: string,
    payload: UploadChatImageDto,
    file?: UploadedImageFile,
  ): Promise<UploadedChatImageView> {
    await this.ensureLoaded();
    const thread = this.getThreadById(threadId);
    this.assertThreadAccessible(actor.userId, thread);

    if (!file) {
      throw new BusinessError(ErrorCode.InvalidInput, 400, 'Image file is required');
    }

    if (!file.mimetype?.startsWith('image/')) {
      throw new BusinessError(ErrorCode.InvalidInput, 400, 'Only image upload is allowed');
    }

    if (!payload.uploadToken.startsWith('upl_chat_')) {
      throw new BusinessError(ErrorCode.InvalidInput, 400, 'Invalid upload token');
    }

    const objectKey = payload.objectKey.trim();
    const expectedPrefix = `chat/${threadId}/${actor.userId}/`;
    if (!objectKey.startsWith(expectedPrefix)) {
      throw new BusinessError(ErrorCode.InvalidInput, 400, 'Invalid object key');
    }

    const mediaRoot = resolve(process.cwd(), 'storage', 'media');
    const destination = resolve(mediaRoot, objectKey);
    if (!destination.startsWith(mediaRoot)) {
      throw new BusinessError(ErrorCode.InvalidInput, 400, 'Unsafe object key');
    }

    await mkdir(dirname(destination), { recursive: true });
    await writeFile(destination, file.buffer);

    return {
      objectKey,
      uploaded: true,
    };
  }

  async markThreadRead(
    actor: TokenUser,
    threadId: string,
    _lastReadMessageId?: string,
  ): Promise<void> {
    await this.ensureLoaded();
    await this.markThreadReadByActor({ userId: actor.userId }, threadId);
  }

  async markThreadReadByActor(
    actor: ActorContext,
    threadId: string,
    _lastReadMessageId?: string,
  ): Promise<void> {
    await this.ensureLoaded();
    const thread = this.getThreadById(threadId);
    this.assertThreadAccessible(actor.userId, thread);
    const messages = this.messagesByThread.get(thread.threadId) ?? [];

    for (const message of messages) {
      if (message.senderId !== actor.userId) {
        message.readBy.add(actor.userId);
      }
    }

    this.unreadCountByThreadUser.set(this.unreadKey(thread.threadId, actor.userId), 0);
    thread.updatedAt = new Date().toISOString();
    thread.deletedBy.delete(actor.userId);
    await this.persistState();
  }

  async deleteThread(actor: TokenUser, threadId: string): Promise<void> {
    await this.ensureLoaded();
    await this.deleteThreadByActor({ userId: actor.userId }, threadId);
  }

  async deleteThreadByActor(actor: ActorContext, threadId: string): Promise<void> {
    await this.ensureLoaded();
    const thread = this.getThreadById(threadId);
    this.assertThreadAccessible(actor.userId, thread);
    thread.deletedBy.add(actor.userId);
    await this.persistState();
  }

  async recallMessage(actor: TokenUser, messageId: string): Promise<void> {
    await this.ensureLoaded();
    await this.recallMessageByActor({ userId: actor.userId }, messageId);
  }

  async recallMessageByActor(actor: ActorContext, messageId: string): Promise<void> {
    await this.ensureLoaded();
    const message = this.messageIndex.get(messageId);
    if (!message) {
      throw new BusinessError(ErrorCode.MessageNotFound, 404, 'Message not found');
    }
    if (message.senderId !== actor.userId) {
      throw new BusinessError(ErrorCode.InvalidInput, 403, 'Only sender can recall');
    }
    const elapsedMs = Date.now() - Date.parse(message.createdAt);
    if (elapsedMs > 2 * 60 * 1000) {
      throw new BusinessError(
        ErrorCode.MessageRecallExpired,
        409,
        'Recall time window exceeded',
      );
    }

    message.status = 'recalled';
    message.recalledAt = new Date().toISOString();
    message.content = '[recalled]';
    message.imageKey = undefined;
    message.isBurnAfterReading = false;
    message.burnSeconds = undefined;
    await this.persistState();
  }

  private async sendMessage(
    actor: ActorContext,
    threadId: string,
    payload: {
      type: MessageType;
      content: string;
      imageKey?: string;
      clientMsgId?: string;
      isBurnAfterReading: boolean;
      burnSeconds?: number;
    },
  ): Promise<MessageView> {
    await this.ensureLoaded();
    const thread = this.getThreadById(threadId);
    this.assertThreadAccessible(actor.userId, thread);
    const peerUserId = this.peerUserId(actor.userId, thread);
    if (this.friendsService.isBlockedBetween(actor.userId, peerUserId)) {
      throw new BusinessError(
        ErrorCode.BlockedRelation,
        403,
        'Blocked relation does not allow sending message',
      );
    }

    const message: MessageRuntime = {
      messageId: `msg_${randomUUID()}`,
      threadId: thread.threadId,
      senderId: actor.userId,
      type: payload.type,
      content: payload.content,
      imageKey: payload.imageKey,
      isBurnAfterReading: payload.isBurnAfterReading,
      burnSeconds: payload.burnSeconds,
      status: 'sent',
      createdAt: new Date().toISOString(),
      clientMsgId: payload.clientMsgId,
      readBy: new Set<string>([actor.userId]),
    };

    const messages = this.messagesByThread.get(thread.threadId) ?? [];
    messages.push(message);
    this.messagesByThread.set(thread.threadId, messages);
    this.messageIndex.set(message.messageId, message);

    thread.deletedBy.delete(actor.userId);
    thread.deletedBy.delete(peerUserId);
    thread.updatedAt = new Date().toISOString();
    this.threads.set(this.threadKey(thread.userA, thread.userB), thread);

    const unreadKey = this.unreadKey(thread.threadId, peerUserId);
    const currentUnread = this.unreadCountByThreadUser.get(unreadKey) ?? 0;
    this.unreadCountByThreadUser.set(unreadKey, currentUnread + 1);
    await this.persistState();
    return this.toMessageView(actor.userId, peerUserId, message);
  }

  private getThreadById(threadId: string): ThreadRuntime {
    const thread = [...this.threads.values()].find((item) => item.threadId === threadId);
    if (!thread) {
      throw new BusinessError(ErrorCode.ThreadNotFound, 404, 'Thread not found');
    }
    return thread;
  }

  private assertThreadAccessible(userId: string, thread: ThreadRuntime): void {
    if (!this.isThreadMember(userId, thread)) {
      throw new BusinessError(ErrorCode.ThreadNotFound, 404, 'Thread not found');
    }
  }

  private isThreadMember(userId: string, thread: ThreadRuntime): boolean {
    return thread.userA === userId || thread.userB === userId;
  }

  private peerUserId(userId: string, thread: ThreadRuntime): string {
    return thread.userA === userId ? thread.userB : thread.userA;
  }

  private unreadKey(threadId: string, userId: string): string {
    return `${threadId}:${userId}`;
  }

  private threadKey(userA: string, userB: string): string {
    return [userA, userB].sort().join(':');
  }

  private ensureUnreadCounter(threadId: string, userId: string): void {
    const key = this.unreadKey(threadId, userId);
    if (!this.unreadCountByThreadUser.has(key)) {
      this.unreadCountByThreadUser.set(key, 0);
    }
  }

  private async toThreadSummary(userId: string, thread: ThreadRuntime): Promise<ThreadSummary> {
    const peerUserId = this.peerUserId(userId, thread);
    const peer = await this.userStore.getUserById(peerUserId);
    if (!peer) {
      throw new BusinessError(ErrorCode.UserNotFound, 404, 'Peer user not found');
    }

    return {
      threadId: thread.threadId,
      user: {
        userId: peer.userId,
        uid: peer.uid,
        nickname: peer.nickname,
        avatarUrl: peer.avatarUrl,
        status: peer.status,
      },
      unreadCount:
        this.unreadCountByThreadUser.get(this.unreadKey(thread.threadId, userId)) ?? 0,
      isFriend: thread.isFriend,
      createdAt: thread.createdAt,
      updatedAt: thread.updatedAt,
      expiresAt: thread.expiresAt,
    };
  }

  private toMessageView(
    actorUserId: string,
    peerUserId: string,
    message: MessageRuntime,
  ): MessageView {
    const isMe = message.senderId === actorUserId;
    return {
      messageId: message.messageId,
      threadId: message.threadId,
      type: message.type,
      content: message.content,
      imageKey: message.imageKey,
      isBurnAfterReading: message.isBurnAfterReading,
      burnSeconds: message.burnSeconds,
      status: message.status,
      isMe,
      isRead: isMe ? message.readBy.has(peerUserId) : false,
      createdAt: message.createdAt,
      recalledAt: message.recalledAt,
      clientMsgId: message.clientMsgId,
    };
  }

  private async ensureLoaded(): Promise<void> {
    if (this.isStateLoaded) return;

    const snapshot = await this.runtimeStateStore.getJson<ChatRuntimeSnapshot>(this.stateKey);
    if (snapshot) {
      this.threads.clear();
      this.messagesByThread.clear();
      this.unreadCountByThreadUser.clear();
      this.messageIndex.clear();

      for (const thread of snapshot.threads) {
        this.threads.set(this.threadKey(thread.userA, thread.userB), {
          ...thread,
          deletedBy: new Set(thread.deletedBy),
        });
      }

      for (const item of snapshot.messagesByThread) {
        const messages = item.messages.map((message) => ({
          ...message,
          readBy: new Set(message.readBy),
        }));
        this.messagesByThread.set(item.threadId, messages);
        for (const message of messages) {
          this.messageIndex.set(message.messageId, message);
        }
      }

      for (const unread of snapshot.unreadCountByThreadUser) {
        this.unreadCountByThreadUser.set(unread.key, unread.count);
      }
    }

    this.isStateLoaded = true;
  }

  private async persistState(): Promise<void> {
    const snapshot: ChatRuntimeSnapshot = {
      version: 1,
      threads: [...this.threads.values()].map((thread) => ({
        ...thread,
        deletedBy: [...thread.deletedBy.values()],
      })),
      messagesByThread: [...this.messagesByThread.entries()].map(([threadId, messages]) => ({
        threadId,
        messages: messages.map((message) => ({
          ...message,
          readBy: [...message.readBy.values()],
        })),
      })),
      unreadCountByThreadUser: [...this.unreadCountByThreadUser.entries()].map(
        ([key, count]) => ({ key, count }),
      ),
    };
    await this.runtimeStateStore.setJson(this.stateKey, snapshot);
  }
}
