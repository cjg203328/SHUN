import { INestApplication } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import * as request from 'supertest';
import { io, Socket } from 'socket.io-client';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/app.setup';

type LoginResult = {
  accessToken: string;
  user: { userId: string; uid: string };
};

describe('Chat Gateway (integration)', () => {
  let app: INestApplication;
  let baseUrl = '';
  let socketA: Socket | null = null;
  let socketB: Socket | null = null;

  const login = async (phone: string, deviceId: string): Promise<LoginResult> => {
    const sendOtpRes = await request(app.getHttpServer())
      .post('/api/v1/auth/otp/send')
      .send({ phone })
      .expect(201);

    const requestId = sendOtpRes.body.data.requestId as string;
    const verifyRes = await request(app.getHttpServer())
      .post('/api/v1/auth/otp/verify')
      .send({
        phone,
        code: '123456',
        requestId,
        deviceId,
      })
      .expect(201);

    return verifyRes.body.data as LoginResult;
  };

  const connectSocket = (token: string): Promise<Socket> =>
    new Promise((resolve, reject) => {
      const socket = io(`${baseUrl}/ws`, {
        transports: ['websocket'],
        auth: { token },
        forceNew: true,
      });

      const timer = setTimeout(() => {
        socket.disconnect();
        reject(new Error('socket connection timeout'));
      }, 5000);

      socket.once('connect', () => {
        clearTimeout(timer);
        resolve(socket);
      });
      socket.once('connect_error', (error) => {
        clearTimeout(timer);
        reject(error);
      });
    });

  const emitWithAck = <TResponse>(
    socket: Socket,
    event: string,
    payload: unknown,
  ): Promise<TResponse> =>
    new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(`ack timeout: ${event}`));
      }, 5000);

      socket.emit(event, payload, (response: TResponse) => {
        clearTimeout(timer);
        resolve(response);
      });
    });

  beforeAll(async () => {
    process.env.APP_ENV = 'test';
    process.env.USER_STORE_DRIVER = 'memory';
    process.env.AUTH_RUNTIME_DRIVER = 'memory';
    process.env.RUNTIME_STATE_DRIVER = 'memory';

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    configureApp(app);
    await app.init();
    await app.listen(0);
    const address = app.getHttpServer().address();
    if (!address || typeof address === 'string') {
      throw new Error('Failed to resolve listening port');
    }
    const port = address.port;
    baseUrl = `http://127.0.0.1:${port}`;
  });

  afterAll(async () => {
    socketA?.disconnect();
    socketB?.disconnect();
    await app.close();
  });

  it('should push msg.new and msg.read_by_peer via websocket', async () => {
    const userA = await login('13800138100', 'device-ws-a');
    const userB = await login('13800138101', 'device-ws-b');

    const createThreadRes = await request(app.getHttpServer())
      .post('/api/v1/threads/direct')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .send({ targetUserId: userB.user.userId })
      .expect(201);
    const threadId = createThreadRes.body.data.threadId as string;

    socketA = await connectSocket(userA.accessToken);
    socketB = await connectSocket(userB.accessToken);

    await emitWithAck(socketA, 'thread.join', { threadId });
    await emitWithAck(socketB, 'thread.join', { threadId });

    const msgNewPromise = new Promise<{ message: { isMe: boolean; messageId: string } }>(
      (resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('msg.new timeout')), 5000);
        socketB?.once('msg.new', (payload) => {
          clearTimeout(timer);
          resolve(payload as { message: { isMe: boolean; messageId: string } });
        });
      },
    );

    const ackPromise = new Promise<{ message: { isMe: boolean; messageId: string } }>(
      (resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('msg.ack timeout')), 5000);
        socketA?.once('msg.ack', (payload) => {
          clearTimeout(timer);
          resolve(payload as { message: { isMe: boolean; messageId: string } });
        });
      },
    );

    await emitWithAck(socketA, 'msg.send.text', {
      threadId,
      content: 'websocket hello',
      clientMsgId: 'ws-client-msg-1',
    });

    const msgNew = await msgNewPromise;
    const ack = await ackPromise;
    expect(msgNew.message.isMe).toBe(false);
    expect(ack.message.isMe).toBe(true);
    expect(msgNew.message.messageId).toBe(ack.message.messageId);

    const readByPeerPromise = new Promise<{ byUserId: string; threadId: string }>(
      (resolve, reject) => {
        const timer = setTimeout(
          () => reject(new Error('msg.read_by_peer timeout')),
          5000,
        );
        socketA?.once('msg.read_by_peer', (payload) => {
          clearTimeout(timer);
          resolve(payload as { byUserId: string; threadId: string });
        });
      },
    );

    await emitWithAck(socketB, 'msg.read', { threadId });
    const readByPeer = await readByPeerPromise;
    expect(readByPeer.byUserId).toBe(userB.user.userId);
    expect(readByPeer.threadId).toBe(threadId);
  });
});
