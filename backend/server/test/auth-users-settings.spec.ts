import { INestApplication } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/app.setup';

describe('Auth + Users + Settings (integration)', () => {
  let app: INestApplication;
  let accessToken = '';
  let accessTokenB = '';
  let userIdB = '';
  let uidB = '';
  let requestId = '';
  let threadId = '';
  let messageId = '';

  const login = async (phone: string, deviceId: string) => {
    const sendOtpRes = await request(app.getHttpServer())
      .post('/api/v1/auth/otp/send')
      .send({ phone })
      .expect(201);

    const otpRequestId = sendOtpRes.body.data.requestId as string;

    const verifyRes = await request(app.getHttpServer())
      .post('/api/v1/auth/otp/verify')
      .send({
        phone,
        code: '123456',
        requestId: otpRequestId,
        deviceId,
      })
      .expect(201);

    return verifyRes.body.data as {
      accessToken: string;
      user: { userId: string; uid: string };
    };
  };

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
  });

  afterAll(async () => {
    await app.close();
  });

  it('should complete auth flow and return access token', async () => {
    const userA = await login('13800138000', 'device-test-01');
    const userB = await login('13800138001', 'device-test-02');
    accessToken = userA.accessToken;
    accessTokenB = userB.accessToken;
    userIdB = userB.user.userId;
    uidB = userB.user.uid;

    expect(uidB).toContain('SN');
    expect(accessToken).toContain('atk_');
  });

  it('should read and update profile', async () => {
    const getRes = await request(app.getHttpServer())
      .get('/api/v1/users/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);

    expect(getRes.body.data.phone).toBe('13800138000');

    const patchRes = await request(app.getHttpServer())
      .patch('/api/v1/users/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        nickname: '测试昵称',
        signature: '测试签名',
        status: '测试状态',
      })
      .expect(200);

    expect(patchRes.body.data.nickname).toBe('测试昵称');
    expect(patchRes.body.data.signature).toBe('测试签名');
    expect(patchRes.body.data.status).toBe('测试状态');

    const avatarUploadTokenRes = await request(app.getHttpServer())
      .post('/api/v1/users/me/avatar/upload-token')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(201);
    expect(avatarUploadTokenRes.body.data.objectKey).toContain('avatar/');

    const avatarUploadRes = await request(app.getHttpServer())
      .post('/api/v1/users/me/avatar/upload')
      .set('Authorization', `Bearer ${accessToken}`)
      .field('uploadToken', avatarUploadTokenRes.body.data.uploadToken)
      .field('objectKey', avatarUploadTokenRes.body.data.objectKey)
      .attach('file', Buffer.from([0xff, 0xd8, 0xff, 0xd9]), {
        filename: 'avatar-test.jpg',
        contentType: 'image/jpeg',
      })
      .expect(201);
    expect(avatarUploadRes.body.data.uploaded).toBe(true);

    const getAvatarRes = await request(app.getHttpServer())
      .get('/api/v1/users/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);
    expect(getAvatarRes.body.data.avatarUrl).toBe(
      avatarUploadTokenRes.body.data.objectKey,
    );
  });

  it('should read and update settings', async () => {
    const getRes = await request(app.getHttpServer())
      .get('/api/v1/settings/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);

    expect(getRes.body.data.dayThemeEnabled).toBe(false);

    const patchRes = await request(app.getHttpServer())
      .patch('/api/v1/settings/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        dayThemeEnabled: true,
        portraitFullscreenBackground: true,
        transparentHomepage: true,
      })
      .expect(200);

    expect(patchRes.body.data.dayThemeEnabled).toBe(true);
    expect(patchRes.body.data.portraitFullscreenBackground).toBe(true);
    expect(patchRes.body.data.transparentHomepage).toBe(true);
  });

  it('should support user search, friend request and accept', async () => {
    const searchRes = await request(app.getHttpServer())
      .get('/api/v1/users/search')
      .set('Authorization', `Bearer ${accessToken}`)
      .query({ uid: uidB })
      .expect(200);
    expect(searchRes.body.data.userId).toBe(userIdB);

    const createReqRes = await request(app.getHttpServer())
      .post('/api/v1/friends/requests')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        targetUserId: userIdB,
        message: 'hello',
      })
      .expect(201);
    requestId = createReqRes.body.data.requestId as string;

    const pendingRes = await request(app.getHttpServer())
      .get('/api/v1/friends/requests/pending')
      .set('Authorization', `Bearer ${accessTokenB}`)
      .expect(200);
    expect(pendingRes.body.data.length).toBeGreaterThan(0);
    expect(pendingRes.body.data[0].fromUser.userId).toBeDefined();

    await request(app.getHttpServer())
      .post(`/api/v1/friends/requests/${requestId}/accept`)
      .set('Authorization', `Bearer ${accessTokenB}`)
      .expect(201);

    const friendsRes = await request(app.getHttpServer())
      .get('/api/v1/friends')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);
    expect(
      friendsRes.body.data.some(
        (item: { user: { userId: string } }) => item.user.userId === userIdB,
      ),
    ).toBe(true);
  });

  it('should support block list and match quota/start', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/friends/${userIdB}/block`)
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(201);

    const friendsAfterBlock = await request(app.getHttpServer())
      .get('/api/v1/friends')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);
    expect(
      friendsAfterBlock.body.data.some(
        (item: { user: { userId: string } }) => item.user.userId === userIdB,
      ),
    ).toBe(false);

    const blockedRes = await request(app.getHttpServer())
      .get('/api/v1/users/blocked')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);
    expect(blockedRes.body.data.some((item: { userId: string }) => item.userId === userIdB)).toBe(true);

    const pendingAfterBlock = await request(app.getHttpServer())
      .get('/api/v1/friends/requests/pending')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);
    expect(
      pendingAfterBlock.body.data.some(
        (item: { fromUser: { userId: string } }) => item.fromUser.userId === userIdB,
      ),
    ).toBe(false);

    const quotaRes = await request(app.getHttpServer())
      .get('/api/v1/match/quota')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);
    const quotaBefore = quotaRes.body.data.remaining as number;
    expect(quotaBefore).toBeGreaterThan(0);

    const matchRes = await request(app.getHttpServer())
      .post('/api/v1/match/start')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ excludeUserIds: [userIdB] })
      .expect(201);
    expect(matchRes.body.data.threadId).toContain('th_');
    expect(matchRes.body.data.quota.remaining).toBe(quotaBefore - 1);

    await request(app.getHttpServer())
      .delete(`/api/v1/friends/${userIdB}/block`)
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);
  });

  it('should support thread and messaging flow with peer-read and recall', async () => {
    const createThreadRes = await request(app.getHttpServer())
      .post('/api/v1/threads/direct')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ targetUserId: userIdB })
      .expect(201);
    threadId = createThreadRes.body.data.threadId as string;
    expect(threadId).toContain('th_');

    const uploadTokenRes = await request(app.getHttpServer())
      .post(`/api/v1/threads/${threadId}/messages/image/upload-token`)
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(201);
    expect(uploadTokenRes.body.data.uploadToken).toContain('upl_chat_');
    expect(uploadTokenRes.body.data.objectKey).toContain(`chat/${threadId}/`);

    const uploadImageRes = await request(app.getHttpServer())
      .post(`/api/v1/threads/${threadId}/messages/image/upload`)
      .set('Authorization', `Bearer ${accessToken}`)
      .field('uploadToken', uploadTokenRes.body.data.uploadToken)
      .field('objectKey', uploadTokenRes.body.data.objectKey)
      .attach('file', Buffer.from([0xff, 0xd8, 0xff, 0xd9]), {
        filename: 'chat-test.jpg',
        contentType: 'image/jpeg',
      })
      .expect(201);
    expect(uploadImageRes.body.data.uploaded).toBe(true);
    expect(uploadImageRes.body.data.objectKey).toBe(
      uploadTokenRes.body.data.objectKey,
    );

    const sendImageRes = await request(app.getHttpServer())
      .post(`/api/v1/threads/${threadId}/messages/image`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        imageKey: uploadImageRes.body.data.objectKey,
        burnAfterReading: true,
        burnSeconds: 5,
        clientMsgId: 'rest-image-1',
      })
      .expect(201);
    expect(sendImageRes.body.data.type).toBe('image');
    expect(sendImageRes.body.data.imageKey).toBe(uploadImageRes.body.data.objectKey);
    expect(sendImageRes.body.data.isBurnAfterReading).toBe(true);

    await request(app.getHttpServer())
      .post(`/api/v1/threads/${threadId}/messages/image/upload`)
      .set('Authorization', `Bearer ${accessToken}`)
      .field('uploadToken', uploadTokenRes.body.data.uploadToken)
      .field('objectKey', uploadTokenRes.body.data.objectKey)
      .attach('file', Buffer.from([0xff, 0xd8, 0xff, 0xd9]), {
        filename: 'chat-test-reuse.jpg',
        contentType: 'image/jpeg',
      })
      .expect(400);

    await request(app.getHttpServer())
      .post(`/api/v1/threads/${threadId}/messages/image`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        imageKey: `chat/${threadId}/${userIdB}/forged-image.jpg`,
        burnAfterReading: false,
      })
      .expect(400);

    const sendRes = await request(app.getHttpServer())
      .post(`/api/v1/threads/${threadId}/messages/text`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ content: '你好，测试消息' })
      .expect(201);
    messageId = sendRes.body.data.messageId as string;
    expect(sendRes.body.data.isRead).toBe(false);

    const threadListB = await request(app.getHttpServer())
      .get('/api/v1/threads')
      .set('Authorization', `Bearer ${accessTokenB}`)
      .expect(200);
    const threadB = threadListB.body.data.find(
      (item: { threadId: string }) => item.threadId === threadId,
    );
    expect(threadB.unreadCount).toBe(2);

    await request(app.getHttpServer())
      .post(`/api/v1/threads/${threadId}/read`)
      .set('Authorization', `Bearer ${accessTokenB}`)
      .send({})
      .expect(201);

    const messagesAAfterRead = await request(app.getHttpServer())
      .get(`/api/v1/threads/${threadId}/messages`)
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);
    const ownMessage = messagesAAfterRead.body.data.find(
      (item: { messageId: string }) => item.messageId === messageId,
    );
    expect(ownMessage.isRead).toBe(true);

    await request(app.getHttpServer())
      .post(`/api/v1/messages/${messageId}/recall`)
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(201);

    const messagesAfterRecall = await request(app.getHttpServer())
      .get(`/api/v1/threads/${threadId}/messages`)
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);
    const recalled = messagesAfterRecall.body.data.find(
      (item: { messageId: string }) => item.messageId === messageId,
    );
    expect(recalled.status).toBe('recalled');

    await request(app.getHttpServer())
      .delete(`/api/v1/threads/${threadId}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);

    const threadListAAfterDelete = await request(app.getHttpServer())
      .get('/api/v1/threads')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);
    expect(
      threadListAAfterDelete.body.data.some(
        (item: { threadId: string }) => item.threadId === threadId,
      ),
    ).toBe(false);

    await request(app.getHttpServer())
      .get(`/api/v1/threads/${threadId}/messages`)
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(404);

    await request(app.getHttpServer())
      .post(`/api/v1/threads/${threadId}/read`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({})
      .expect(404);

    await request(app.getHttpServer())
      .post(`/api/v1/threads/${threadId}/messages/text`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ content: 'deleted-thread-send' })
      .expect(404);

    await request(app.getHttpServer())
      .post(`/api/v1/messages/${messageId}/recall`)
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(404);

    await request(app.getHttpServer())
      .post(`/api/v1/threads/${threadId}/messages/text`)
      .set('Authorization', `Bearer ${accessTokenB}`)
      .send({ content: '恢复会话消息' })
      .expect(201);

    const threadListARestore = await request(app.getHttpServer())
      .get('/api/v1/threads')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);
    const restored = threadListARestore.body.data.find(
      (item: { threadId: string }) => item.threadId === threadId,
    );
    expect(restored.unreadCount).toBe(1);
  });

  it('should support partial read via REST lastReadMessageId', async () => {
    const createThreadRes = await request(app.getHttpServer())
      .post('/api/v1/threads/direct')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ targetUserId: userIdB })
      .expect(201);
    const partialReadThreadId = createThreadRes.body.data.threadId as string;

    const firstRes = await request(app.getHttpServer())
      .post(`/api/v1/threads/${partialReadThreadId}/messages/text`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ content: 'first-rest-read' })
      .expect(201);
    const secondRes = await request(app.getHttpServer())
      .post(`/api/v1/threads/${partialReadThreadId}/messages/text`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ content: 'second-rest-read' })
      .expect(201);
    await request(app.getHttpServer())
      .post(`/api/v1/threads/${partialReadThreadId}/messages/text`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ content: 'third-rest-read' })
      .expect(201);

    await request(app.getHttpServer())
      .post(`/api/v1/threads/${partialReadThreadId}/read`)
      .set('Authorization', `Bearer ${accessTokenB}`)
      .send({ lastReadMessageId: secondRes.body.data.messageId })
      .expect(201);

    const threadListB = await request(app.getHttpServer())
      .get('/api/v1/threads')
      .set('Authorization', `Bearer ${accessTokenB}`)
      .expect(200);
    const threadB = threadListB.body.data.find(
      (item: { threadId: string }) => item.threadId === partialReadThreadId,
    );
    expect(threadB.unreadCount).toBe(1);

    const messagesA = await request(app.getHttpServer())
      .get(`/api/v1/threads/${partialReadThreadId}/messages`)
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);
    const first = messagesA.body.data.find(
      (item: { messageId: string }) => item.messageId === firstRes.body.data.messageId,
    );
    const second = messagesA.body.data.find(
      (item: { messageId: string }) => item.messageId === secondRes.body.data.messageId,
    );
    const third = messagesA.body.data.find(
      (item: { content: string }) => item.content === 'third-rest-read',
    );
    expect(first.isRead).toBe(true);
    expect(second.isRead).toBe(true);
    expect(third.isRead).toBe(false);
  });

  it('should clear peer unread count when unread message is recalled', async () => {
    const userC = await login('13800138002', 'device-test-03');
    const userD = await login('13800138003', 'device-test-04');

    const createThreadRes = await request(app.getHttpServer())
      .post('/api/v1/threads/direct')
      .set('Authorization', `Bearer ${userC.accessToken}`)
      .send({ targetUserId: userD.user.userId })
      .expect(201);
    const recallThreadId = createThreadRes.body.data.threadId as string;

    const sendRes = await request(app.getHttpServer())
      .post(`/api/v1/threads/${recallThreadId}/messages/text`)
      .set('Authorization', `Bearer ${userC.accessToken}`)
      .send({ content: 'recall-unread-message' })
      .expect(201);

    const threadListBeforeRecall = await request(app.getHttpServer())
      .get('/api/v1/threads')
      .set('Authorization', `Bearer ${userD.accessToken}`)
      .expect(200);
    const beforeRecall = threadListBeforeRecall.body.data.find(
      (item: { threadId: string }) => item.threadId === recallThreadId,
    );
    expect(beforeRecall.unreadCount).toBe(1);

    await request(app.getHttpServer())
      .post(`/api/v1/messages/${sendRes.body.data.messageId}/recall`)
      .set('Authorization', `Bearer ${userC.accessToken}`)
      .expect(201);

    const threadListAfterRecall = await request(app.getHttpServer())
      .get('/api/v1/threads')
      .set('Authorization', `Bearer ${userD.accessToken}`)
      .expect(200);
    const afterRecall = threadListAfterRecall.body.data.find(
      (item: { threadId: string }) => item.threadId === recallThreadId,
    );
    expect(afterRecall.unreadCount).toBe(0);
  });

  it('should reject forged chat image upload tokens', async () => {
    const userE = await login('13800138004', 'device-test-05');
    const userF = await login('13800138005', 'device-test-06');

    const createThreadRes = await request(app.getHttpServer())
      .post('/api/v1/threads/direct')
      .set('Authorization', `Bearer ${userE.accessToken}`)
      .send({ targetUserId: userF.user.userId })
      .expect(201);
    const forgedThreadId = createThreadRes.body.data.threadId as string;

    await request(app.getHttpServer())
      .post(`/api/v1/threads/${forgedThreadId}/messages/image/upload`)
      .set('Authorization', `Bearer ${userE.accessToken}`)
      .field('uploadToken', 'upl_chat_forged_token')
      .field('objectKey', `chat/${forgedThreadId}/${userE.user.userId}/forged.jpg`)
      .attach('file', Buffer.from([0xff, 0xd8, 0xff, 0xd9]), {
        filename: 'chat-forged.jpg',
        contentType: 'image/jpeg',
      })
      .expect(400);
  });

  it('should reject invalid burn settings for image messages via REST', async () => {
    const userG = await login('13800138006', 'device-test-07');
    const userH = await login('13800138007', 'device-test-08');

    const createThreadRes = await request(app.getHttpServer())
      .post('/api/v1/threads/direct')
      .set('Authorization', `Bearer ${userG.accessToken}`)
      .send({ targetUserId: userH.user.userId })
      .expect(201);
    const burnThreadId = createThreadRes.body.data.threadId as string;

    await request(app.getHttpServer())
      .post(`/api/v1/threads/${burnThreadId}/messages/image`)
      .set('Authorization', `Bearer ${userG.accessToken}`)
      .send({
        imageKey: 'chat/fake/image-1.jpg',
        burnAfterReading: false,
        burnSeconds: 5,
      })
      .expect(400);

    await request(app.getHttpServer())
      .post(`/api/v1/threads/${burnThreadId}/messages/image`)
      .set('Authorization', `Bearer ${userG.accessToken}`)
      .send({
        imageKey: 'chat/fake/image-2.jpg',
        burnAfterReading: true,
        burnSeconds: 99,
      })
      .expect(400);
  });

  it('should only count new unread after deleted thread is restored', async () => {
    const userI = await login('13800138008', 'device-test-09');
    const userJ = await login('13800138009', 'device-test-10');

    const createThreadRes = await request(app.getHttpServer())
      .post('/api/v1/threads/direct')
      .set('Authorization', `Bearer ${userI.accessToken}`)
      .send({ targetUserId: userJ.user.userId })
      .expect(201);
    const restoredThreadId = createThreadRes.body.data.threadId as string;

    await request(app.getHttpServer())
      .post(`/api/v1/threads/${restoredThreadId}/messages/text`)
      .set('Authorization', `Bearer ${userJ.accessToken}`)
      .send({ content: 'old-delete-unread-1' })
      .expect(201);
    await request(app.getHttpServer())
      .post(`/api/v1/threads/${restoredThreadId}/messages/text`)
      .set('Authorization', `Bearer ${userJ.accessToken}`)
      .send({ content: 'old-delete-unread-2' })
      .expect(201);

    const threadListBeforeDelete = await request(app.getHttpServer())
      .get('/api/v1/threads')
      .set('Authorization', `Bearer ${userI.accessToken}`)
      .expect(200);
    const beforeDelete = threadListBeforeDelete.body.data.find(
      (item: { threadId: string }) => item.threadId === restoredThreadId,
    );
    expect(beforeDelete.unreadCount).toBe(2);

    await request(app.getHttpServer())
      .delete(`/api/v1/threads/${restoredThreadId}`)
      .set('Authorization', `Bearer ${userI.accessToken}`)
      .expect(200);

    await request(app.getHttpServer())
      .post(`/api/v1/threads/${restoredThreadId}/messages/text`)
      .set('Authorization', `Bearer ${userJ.accessToken}`)
      .send({ content: 'new-delete-unread' })
      .expect(201);

    const threadListAfterRestore = await request(app.getHttpServer())
      .get('/api/v1/threads')
      .set('Authorization', `Bearer ${userI.accessToken}`)
      .expect(200);
    const afterRestore = threadListAfterRestore.body.data.find(
      (item: { threadId: string }) => item.threadId === restoredThreadId,
    );
    expect(afterRestore.unreadCount).toBe(1);
  });
});
