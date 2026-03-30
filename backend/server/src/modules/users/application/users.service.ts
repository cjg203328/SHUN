import { Inject, Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { mkdir, writeFile } from 'fs/promises';
import { dirname, resolve } from 'path';
import { BusinessError, ErrorCode } from '../../../common/errors/error-codes';
import { UpdateProfileDto } from '../dto/update-profile.dto';
import { TokenUser } from '../../auth/domain/token-user';
import { USER_SETTINGS_STORE } from '../../shared/tokens';
import { UserSettingsStore } from '../../shared/ports/user-settings-store.port';
import { UploadUserMediaDto } from '../dto/upload-user-media.dto';

interface UploadedMediaFile {
  buffer: Buffer;
  mimetype?: string;
}

interface PendingUserUploadToken {
  uploadToken: string;
  userId: string;
  type: 'avatar' | 'background';
  objectKey: string;
  expiresAt: number;
}

@Injectable()
export class UsersService {
  private readonly uploadTokenExpireSeconds = 300;
  private readonly maxUploadBytes = 8 * 1024 * 1024;
  private readonly pendingUploadTokens = new Map<string, PendingUserUploadToken>();

  constructor(
    @Inject(USER_SETTINGS_STORE)
    private readonly store: UserSettingsStore,
  ) {}

  async getCurrentUser(actor: TokenUser) {
    const user = await this.store.getUserById(actor.userId);
    if (!user) {
      throw new BusinessError(ErrorCode.UserNotFound, 404, 'User not found');
    }
    return user;
  }

  async updateProfile(actor: TokenUser, payload: UpdateProfileDto) {
    const user = await this.getCurrentUser(actor);
    const next = {
      ...user,
      nickname: payload.nickname ?? user.nickname,
      signature: payload.signature ?? user.signature,
      status: payload.status ?? user.status,
      updatedAt: new Date().toISOString(),
    };
    await this.store.saveUser(next);
    return next;
  }

  async createUploadToken(actor: TokenUser, type: 'avatar' | 'background') {
    await this.getCurrentUser(actor);
    this.purgeExpiredUploadTokens();
    const uploadToken = `upl_${randomUUID()}`;
    const objectKey = `${type}/${actor.userId}/${Date.now()}.jpg`;
    this.pendingUploadTokens.set(uploadToken, {
      uploadToken,
      userId: actor.userId,
      type,
      objectKey,
      expiresAt: Date.now() + this.uploadTokenExpireSeconds * 1000,
    });
    return {
      uploadToken,
      objectKey,
      expireSeconds: this.uploadTokenExpireSeconds,
    };
  }

  async uploadMedia(
    actor: TokenUser,
    type: 'avatar' | 'background',
    payload: UploadUserMediaDto,
    file?: UploadedMediaFile,
  ) {
    const user = await this.getCurrentUser(actor);

    if (!file) {
      throw new BusinessError(ErrorCode.InvalidInput, 400, 'Image file is required');
    }

    if (!file.mimetype?.startsWith('image/')) {
      throw new BusinessError(ErrorCode.InvalidInput, 400, 'Only image upload is allowed');
    }

    if (file.buffer.byteLength > this.maxUploadBytes) {
      throw new BusinessError(ErrorCode.InvalidInput, 400, 'Image file is too large');
    }

    const objectKey = payload.objectKey.trim();
    this.consumeUploadToken(actor.userId, type, payload.uploadToken, objectKey);

    const mediaRoot = resolve(process.cwd(), 'storage', 'media');
    const destination = resolve(mediaRoot, objectKey);
    if (!destination.startsWith(mediaRoot)) {
      throw new BusinessError(ErrorCode.InvalidInput, 400, 'Unsafe object key');
    }

    await mkdir(dirname(destination), { recursive: true });
    await writeFile(destination, file.buffer);

    if (type == 'avatar') {
      await this.store.saveUser({
        ...user,
        avatarUrl: objectKey,
        updatedAt: new Date().toISOString(),
      });
    } else {
      await this.store.saveUser({
        ...user,
        backgroundUrl: objectKey,
        updatedAt: new Date().toISOString(),
      });
    }

    return {
      objectKey,
      uploaded: true,
    };
  }

  private consumeUploadToken(
    userId: string,
    type: 'avatar' | 'background',
    uploadToken: string,
    objectKey: string,
  ): void {
    this.purgeExpiredUploadTokens();
    const pendingToken = this.pendingUploadTokens.get(uploadToken);
    if (!pendingToken) {
      throw new BusinessError(ErrorCode.InvalidInput, 400, 'Invalid upload token');
    }
    if (
      pendingToken.userId !== userId ||
      pendingToken.type !== type ||
      pendingToken.objectKey !== objectKey
    ) {
      throw new BusinessError(ErrorCode.InvalidInput, 400, 'Invalid upload token');
    }
    this.pendingUploadTokens.delete(uploadToken);
  }

  private purgeExpiredUploadTokens(): void {
    const now = Date.now();
    for (const [uploadToken, pendingToken] of this.pendingUploadTokens.entries()) {
      if (pendingToken.expiresAt <= now) {
        this.pendingUploadTokens.delete(uploadToken);
      }
    }
  }
}
