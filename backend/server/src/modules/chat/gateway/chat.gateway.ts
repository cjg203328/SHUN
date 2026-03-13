import { Logger } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { AuthService } from '../../auth/application/auth.service';
import { TokenUser } from '../../auth/domain/token-user';
import { BusinessError, ErrorCode } from '../../../common/errors/error-codes';
import { ChatService } from '../application/chat.service';

type JoinThreadPayload = {
  threadId: string;
};

type SendTextPayload = {
  threadId: string;
  content: string;
  clientMsgId?: string;
};

type SendImagePayload = {
  threadId: string;
  imageKey: string;
  burnAfterReading?: boolean;
  burnSeconds?: number;
  clientMsgId?: string;
};

type ReadPayload = {
  threadId: string;
  lastReadMessageId?: string;
};

type TypingPayload = {
  threadId: string;
  isTyping: boolean;
};

type AckErrorResponse = {
  ok: false;
  error: {
    code: string;
    message: string;
    status: number;
  };
};

@WebSocketGateway({
  namespace: '/ws',
  cors: {
    origin: '*',
  },
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  private server!: Server;

  private readonly logger = new Logger(ChatGateway.name);
  private readonly socketUser = new Map<string, TokenUser>();
  private readonly userSockets = new Map<string, Set<string>>();

  constructor(
    private readonly authService: AuthService,
    private readonly chatService: ChatService,
  ) {}

  async handleConnection(client: Socket): Promise<void> {
    const token = this.resolveToken(client);
    if (!token) {
      client.emit('error', { code: 'AUTH_TOKEN_INVALID', message: 'Missing token' });
      client.disconnect(true);
      return;
    }

    const user = await this.authService.validateAccessToken(token);
    if (!user) {
      client.emit('error', { code: 'AUTH_TOKEN_INVALID', message: 'Invalid token' });
      client.disconnect(true);
      return;
    }

    this.socketUser.set(client.id, user);
    const socketSet = this.userSockets.get(user.userId) ?? new Set<string>();
    socketSet.add(client.id);
    this.userSockets.set(user.userId, socketSet);
    this.logger.log(`socket connected: ${client.id} user=${user.userId}`);
    client.emit('connected', { userId: user.userId });
  }

  handleDisconnect(client: Socket): void {
    const user = this.socketUser.get(client.id);
    if (!user) return;
    this.socketUser.delete(client.id);
    const socketSet = this.userSockets.get(user.userId);
    socketSet?.delete(client.id);
    if (socketSet && socketSet.size === 0) {
      this.userSockets.delete(user.userId);
    }
    this.logger.log(`socket disconnected: ${client.id} user=${user.userId}`);
  }

  @SubscribeMessage('thread.join')
  async onThreadJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: JoinThreadPayload,
  ): Promise<{ joined: true; threadId: string } | AckErrorResponse> {
    try {
      const actor = this.requireSocketUser(client);
      this.chatService.getRealtimeThreadPeerUserId(actor.userId, payload.threadId);
      await client.join(this.threadRoom(payload.threadId));
      return { joined: true, threadId: payload.threadId };
    } catch (error) {
      return this.toAckError(error);
    }
  }

  @SubscribeMessage('msg.send.text')
  async onSendText(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: SendTextPayload,
  ): Promise<{ ok: true; messageId: string } | AckErrorResponse> {
    try {
      const actor = this.requireSocketUser(client);
      const ownView = await this.chatService.sendTextMessageByActor(
        { userId: actor.userId },
        payload.threadId,
        payload.content,
        payload.clientMsgId,
      );
      const peerUserId = this.chatService.getThreadPeerUserId(actor.userId, payload.threadId);
      const peerView = await this.chatService.getMessageViewForUser(
        peerUserId,
        ownView.messageId,
      );

      this.emitToUser(actor.userId, 'msg.ack', {
        threadId: payload.threadId,
        message: ownView,
        clientMsgId: payload.clientMsgId,
      });
      this.emitToUser(peerUserId, 'msg.new', {
        threadId: payload.threadId,
        message: peerView,
      });

      await this.emitThreadUpdated(payload.threadId, actor.userId, peerUserId);
      return { ok: true, messageId: ownView.messageId };
    } catch (error) {
      return this.toAckError(error);
    }
  }

  @SubscribeMessage('msg.send.image')
  async onSendImage(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: SendImagePayload,
  ): Promise<{ ok: true; messageId: string } | AckErrorResponse> {
    try {
      const actor = this.requireSocketUser(client);
      const ownView = await this.chatService.sendImageMessageByActor(
        { userId: actor.userId },
        payload.threadId,
        payload.imageKey,
        payload.burnAfterReading ?? false,
        payload.burnSeconds,
        payload.clientMsgId,
      );
      const peerUserId = this.chatService.getThreadPeerUserId(actor.userId, payload.threadId);
      const peerView = await this.chatService.getMessageViewForUser(
        peerUserId,
        ownView.messageId,
      );

      this.emitToUser(actor.userId, 'msg.ack', {
        threadId: payload.threadId,
        message: ownView,
        clientMsgId: payload.clientMsgId,
      });
      this.emitToUser(peerUserId, 'msg.new', {
        threadId: payload.threadId,
        message: peerView,
      });

      await this.emitThreadUpdated(payload.threadId, actor.userId, peerUserId);
      return { ok: true, messageId: ownView.messageId };
    } catch (error) {
      return this.toAckError(error);
    }
  }

  @SubscribeMessage('msg.read')
  async onRead(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: ReadPayload,
  ): Promise<{ ok: true; threadId: string } | AckErrorResponse> {
    try {
      const actor = this.requireSocketUser(client);
      await this.chatService.markThreadReadByActor(
        { userId: actor.userId },
        payload.threadId,
        payload.lastReadMessageId,
      );
      const peerUserId = this.chatService.getThreadPeerUserId(actor.userId, payload.threadId);

      this.emitToUser(peerUserId, 'msg.read_by_peer', {
        threadId: payload.threadId,
        byUserId: actor.userId,
        lastReadMessageId: payload.lastReadMessageId,
      });
      await this.emitThreadUpdated(payload.threadId, actor.userId, peerUserId);
      return { ok: true, threadId: payload.threadId };
    } catch (error) {
      return this.toAckError(error);
    }
  }

  @SubscribeMessage('typing')
  onTyping(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: TypingPayload,
  ): { ok: true } | AckErrorResponse {
    try {
      const actor = this.requireSocketUser(client);
      const peerUserId = this.chatService.getRealtimeThreadPeerUserId(
        actor.userId,
        payload.threadId,
      );
      this.emitToUser(peerUserId, 'typing', {
        threadId: payload.threadId,
        userId: actor.userId,
        isTyping: payload.isTyping,
      });
      return { ok: true };
    } catch (error) {
      return this.toAckError(error);
    }
  }

  private resolveToken(client: Socket): string {
    const authToken = client.handshake.auth?.token;
    if (typeof authToken === 'string' && authToken.trim()) {
      return authToken.trim();
    }

    const authorization = client.handshake.headers.authorization;
    if (typeof authorization === 'string' && authorization.startsWith('Bearer ')) {
      return authorization.substring('Bearer '.length).trim();
    }
    return '';
  }

  private toAckError(error: unknown): AckErrorResponse {
    if (error instanceof BusinessError) {
      return {
        ok: false,
        error: {
          code: error.code,
          message: error.message,
          status: error.status,
        },
      };
    }

    return {
      ok: false,
      error: {
        code: ErrorCode.InternalError,
        message: 'Internal server error',
        status: 500,
      },
    };
  }

  private requireSocketUser(client: Socket): TokenUser {
    const actor = this.socketUser.get(client.id);
    if (!actor) {
      throw new Error('Socket is not authenticated');
    }
    return actor;
  }

  private emitToUser(userId: string, event: string, payload: unknown): void {
    const socketIds = this.userSockets.get(userId);
    if (!socketIds || socketIds.size === 0) return;
    for (const socketId of socketIds.values()) {
      this.server.to(socketId).emit(event, payload);
    }
  }

  private async emitThreadUpdated(
    threadId: string,
    actorUserId: string,
    peerUserId: string,
  ): Promise<void> {
    const actorSummary = await this.chatService.getThreadSummaryByUserId(
      actorUserId,
      threadId,
    );
    const peerSummary = await this.chatService.getThreadSummaryByUserId(
      peerUserId,
      threadId,
    );
    this.emitToUser(actorUserId, 'thread.updated', actorSummary);
    this.emitToUser(peerUserId, 'thread.updated', peerSummary);
  }

  private threadRoom(threadId: string): string {
    return `thread:${threadId}`;
  }
}
