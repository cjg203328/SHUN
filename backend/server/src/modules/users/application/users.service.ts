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

@Injectable()
export class UsersService {
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
    return {
      uploadToken: `upl_${randomUUID()}`,
      objectKey: `${type}/${actor.userId}/${Date.now()}.jpg`,
      expireSeconds: 300,
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

    if (!payload.uploadToken.startsWith('upl_')) {
      throw new BusinessError(ErrorCode.InvalidInput, 400, 'Invalid upload token');
    }

    const objectKey = payload.objectKey.trim();
    const expectedPrefix = `${type}/${actor.userId}/`;
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

    if (type == 'avatar') {
      await this.store.saveUser({
        ...user,
        avatarUrl: objectKey,
        updatedAt: new Date().toISOString(),
      });
    }

    return {
      objectKey,
      uploaded: true,
    };
  }
}
