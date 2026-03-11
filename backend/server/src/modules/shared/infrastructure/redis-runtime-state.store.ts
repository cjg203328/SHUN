import Redis from 'ioredis';
import { RuntimeStateStore } from '../ports/runtime-state-store.port';

const KEY_PREFIX = 'runtime:';

export class RedisRuntimeStateStore implements RuntimeStateStore {
  private readonly redis: Redis;
  private readonly keyPrefix: string;

  constructor() {
    this.redis = new Redis({
      host: process.env.REDIS_HOST ?? '127.0.0.1',
      port: Number(process.env.REDIS_PORT ?? 6379),
      lazyConnect: false,
      maxRetriesPerRequest: 2,
    });
    this.keyPrefix = process.env.RUNTIME_STATE_PREFIX ?? KEY_PREFIX;
  }

  async getJson<T>(key: string): Promise<T | null> {
    const raw = await this.redis.get(this.prefixedKey(key));
    return raw ? (JSON.parse(raw) as T) : null;
  }

  async setJson<T>(key: string, value: T): Promise<void> {
    await this.redis.set(this.prefixedKey(key), JSON.stringify(value));
  }

  private prefixedKey(key: string): string {
    return `${this.keyPrefix}${key}`;
  }
}
