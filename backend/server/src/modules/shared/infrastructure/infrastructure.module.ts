import { Global, Module } from '@nestjs/common';
import {
  AUTH_RUNTIME_STORE,
  RUNTIME_STATE_STORE,
  USER_SETTINGS_STORE,
} from '../tokens';
import { InMemoryUserSettingsStore } from './in-memory-user-settings.store';
import { PostgresUserSettingsStore } from './postgres-user-settings.store';
import { AuthRuntimeStore } from '../ports/auth-runtime-store.port';
import { InMemoryAuthRuntimeStore } from './in-memory-auth-runtime.store';
import { RedisAuthRuntimeStore } from './redis-auth-runtime.store';
import { UserSettingsStore } from '../ports/user-settings-store.port';
import { RuntimeStateStore } from '../ports/runtime-state-store.port';
import { InMemoryRuntimeStateStore } from './in-memory-runtime-state.store';
import { RedisRuntimeStateStore } from './redis-runtime-state.store';

function createUserSettingsStore(): UserSettingsStore {
  const driver = (process.env.USER_STORE_DRIVER ?? 'memory').toLowerCase();
  if (driver === 'postgres') {
    return new PostgresUserSettingsStore();
  }
  return new InMemoryUserSettingsStore();
}

function createAuthRuntimeStore(): AuthRuntimeStore {
  const driver = (process.env.AUTH_RUNTIME_DRIVER ?? 'memory').toLowerCase();
  if (driver === 'redis') {
    return new RedisAuthRuntimeStore();
  }
  return new InMemoryAuthRuntimeStore();
}

function createRuntimeStateStore(): RuntimeStateStore {
  const driver = (process.env.RUNTIME_STATE_DRIVER ?? 'memory').toLowerCase();
  if (driver === 'redis') {
    return new RedisRuntimeStateStore();
  }
  return new InMemoryRuntimeStateStore();
}

@Global()
@Module({
  providers: [
    {
      provide: USER_SETTINGS_STORE,
      useFactory: createUserSettingsStore,
    },
    {
      provide: AUTH_RUNTIME_STORE,
      useFactory: createAuthRuntimeStore,
    },
    {
      provide: RUNTIME_STATE_STORE,
      useFactory: createRuntimeStateStore,
    },
  ],
  exports: [USER_SETTINGS_STORE, AUTH_RUNTIME_STORE, RUNTIME_STATE_STORE],
})
export class InfrastructureModule {}
