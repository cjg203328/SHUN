import { RuntimeStateStore } from '../ports/runtime-state-store.port';

export class InMemoryRuntimeStateStore implements RuntimeStateStore {
  private readonly state = new Map<string, unknown>();

  async getJson<T>(key: string): Promise<T | null> {
    const value = this.state.get(key);
    return (value as T | undefined) ?? null;
  }

  async setJson<T>(key: string, value: T): Promise<void> {
    this.state.set(key, value);
  }
}
