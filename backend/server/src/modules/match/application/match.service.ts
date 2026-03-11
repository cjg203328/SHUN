import { Inject, Injectable, OnModuleInit } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { BusinessError, ErrorCode } from '../../../common/errors/error-codes';
import { TokenUser } from '../../auth/domain/token-user';
import { FriendsService } from '../../friends/application/friends.service';
import { RuntimeStateStore } from '../../shared/ports/runtime-state-store.port';
import { UserSettingsStore } from '../../shared/ports/user-settings-store.port';
import { RUNTIME_STATE_STORE } from '../../shared/tokens';
import { USER_SETTINGS_STORE } from '../../shared/tokens';

export interface MatchQuota {
  remaining: number;
  lastResetDate: string;
}

export interface CandidateUser {
  userId: string;
  uid: string;
  nickname: string;
  avatar: string;
  status: string;
  distance: string;
  isOnline: boolean;
}

interface MatchRuntimeSnapshot {
  version: 1;
  quotaByUser: Array<{ userId: string; quota: MatchQuota }>;
}

const DAILY_QUOTA = 20;

@Injectable()
export class MatchService implements OnModuleInit {
  private readonly stateKey = 'match:state:v1';
  private readonly quotaByUser = new Map<string, MatchQuota>();
  private readonly candidates: CandidateUser[] = [
    {
      userId: 'u_001',
      uid: 'SNF0A101',
      nickname: 'Aster',
      avatar: 'avatar_1',
      status: 'Looking for a chat partner',
      distance: '3km',
      isOnline: true,
    },
    {
      userId: 'u_002',
      uid: 'SNF0A102',
      nickname: 'Nora',
      avatar: 'avatar_2',
      status: 'Still awake tonight',
      distance: '5km',
      isOnline: true,
    },
    {
      userId: 'u_003',
      uid: 'SNF0A103',
      nickname: 'Wind',
      avatar: 'avatar_3',
      status: 'Open to random conversations',
      distance: '8km',
      isOnline: false,
    },
  ];
  private isStateLoaded = false;

  constructor(
    private readonly friendsService: FriendsService,
    @Inject(RUNTIME_STATE_STORE)
    private readonly runtimeStateStore: RuntimeStateStore,
    @Inject(USER_SETTINGS_STORE)
    private readonly userStore: UserSettingsStore,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.ensureDemoCandidatesRegistered();
    await this.ensureLoaded();
  }

  async getQuota(actor: TokenUser): Promise<MatchQuota> {
    await this.ensureLoaded();
    const { quota, changed } = this.ensureQuota(actor.userId);
    if (changed) {
      await this.persistState();
    }
    return { ...quota };
  }

  async startMatch(
    actor: TokenUser,
    excludedUserIds: string[] = [],
  ): Promise<{
    matchId: string;
    threadId: string;
    quota: MatchQuota;
    user: CandidateUser;
    createdAt: string;
    expiresAt: string;
  }> {
    await this.ensureLoaded();
    const { quota } = this.ensureQuota(actor.userId);
    if (quota.remaining <= 0) {
      throw new BusinessError(
        ErrorCode.MatchQuotaExceeded,
        429,
        'No match quota remaining today',
      );
    }

    const blockedAwareCandidates = this.candidates.filter((candidate) => {
      if (excludedUserIds.includes(candidate.userId)) return false;
      if (candidate.userId === actor.userId) return false;
      return !this.friendsService.isBlockedBetween(actor.userId, candidate.userId);
    });

    const pool =
      blockedAwareCandidates.length > 0 ? blockedAwareCandidates : this.candidates;
    const selected = pool[Math.floor(Date.now() % pool.length)];

    quota.remaining -= 1;
    this.quotaByUser.set(actor.userId, quota);
    await this.persistState();

    return {
      matchId: `m_${randomUUID()}`,
      threadId: `th_${randomUUID()}`,
      quota: { ...quota },
      user: selected,
      createdAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    };
  }

  async cancelMatch(_actor: TokenUser): Promise<{ cancelled: true }> {
    await this.ensureLoaded();
    return { cancelled: true };
  }

  private ensureQuota(userId: string): { quota: MatchQuota; changed: boolean } {
    const today = this.today();
    const current = this.quotaByUser.get(userId);
    if (!current || current.lastResetDate !== today) {
      const reset: MatchQuota = { remaining: DAILY_QUOTA, lastResetDate: today };
      this.quotaByUser.set(userId, reset);
      return { quota: reset, changed: true };
    }
    return { quota: current, changed: false };
  }

  private today(): string {
    const now = new Date();
    const yyyy = now.getUTCFullYear();
    const mm = String(now.getUTCMonth() + 1).padStart(2, '0');
    const dd = String(now.getUTCDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  }

  private async ensureLoaded(): Promise<void> {
    if (this.isStateLoaded) return;

    const snapshot = await this.runtimeStateStore.getJson<MatchRuntimeSnapshot>(
      this.stateKey,
    );
    if (snapshot) {
      this.quotaByUser.clear();
      for (const item of snapshot.quotaByUser) {
        this.quotaByUser.set(item.userId, item.quota);
      }
    }

    this.isStateLoaded = true;
  }

  private async ensureDemoCandidatesRegistered(): Promise<void> {
    const now = new Date().toISOString();
    for (const candidate of this.candidates) {
      const existing = await this.userStore.getUserById(candidate.userId);
      if (existing != null) {
        continue;
      }

      await this.userStore.saveUser({
        userId: candidate.userId,
        uid: candidate.uid,
        phone: `demo_${candidate.userId}`,
        nickname: candidate.nickname,
        avatarUrl: candidate.avatar,
        signature: '这是用于区域测试的演示匹配账号',
        status: candidate.status,
        createdAt: now,
        updatedAt: now,
      });

      await this.userStore.saveSettings({
        userId: candidate.userId,
        invisibleMode: false,
        notificationEnabled: true,
        vibrationEnabled: true,
        dayThemeEnabled: false,
        transparentHomepage: false,
        portraitFullscreenBackground: false,
        updatedAt: now,
      });
    }
  }

  private async persistState(): Promise<void> {
    const snapshot: MatchRuntimeSnapshot = {
      version: 1,
      quotaByUser: [...this.quotaByUser.entries()].map(([userId, quota]) => ({
        userId,
        quota,
      })),
    };
    await this.runtimeStateStore.setJson(this.stateKey, snapshot);
  }
}
