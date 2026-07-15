import { eq } from "drizzle-orm";
import type { Db } from "./client.js";
import { appSettings } from "./schema.js";

const TTL_MS = 30_000;

export interface SettingRow {
  key: string;
  value: unknown;
  isSecret: boolean;
  updatedAt: Date;
}

export interface SettingsCache {
  /** Read a setting's value as T, falling back when the row is missing. Cached ~30s. */
  get<T>(key: string, fallback: T): Promise<T>;
  /** Every row, uncached — used by the admin settings list endpoint. */
  listAll(): Promise<SettingRow[]>;
  /** Upsert a value and drop the cached copy for that key. Returns the new updatedAt. */
  set(key: string, value: unknown, isSecret: boolean, updatedBy: string | undefined): Promise<Date>;
  /** Drop a cached key (or the whole cache when omitted). */
  invalidate(key?: string): void;
}

export function createSettingsCache(db: Db): SettingsCache {
  const cache = new Map<string, { value: unknown; expiresAt: number }>();

  return {
    async get<T>(key: string, fallback: T): Promise<T> {
      const cached = cache.get(key);
      if (cached && cached.expiresAt > Date.now()) return cached.value as T;
      const rows = await db.select().from(appSettings).where(eq(appSettings.key, key)).limit(1);
      const value = (rows[0]?.value ?? fallback) as T;
      cache.set(key, { value, expiresAt: Date.now() + TTL_MS });
      return value;
    },

    async listAll(): Promise<SettingRow[]> {
      const rows = await db.select().from(appSettings);
      return rows.map((r) => ({ key: r.key, value: r.value, isSecret: r.isSecret, updatedAt: r.updatedAt }));
    },

    async set(key: string, value: unknown, isSecret: boolean, updatedBy: string | undefined): Promise<Date> {
      const updatedAt = new Date();
      await db
        .insert(appSettings)
        .values({ key, value, isSecret, updatedAt, updatedBy: updatedBy ?? null })
        .onConflictDoUpdate({ target: appSettings.key, set: { value, updatedAt, updatedBy: updatedBy ?? null } });
      cache.delete(key);
      return updatedAt;
    },

    invalidate(key?: string): void {
      if (key) cache.delete(key);
      else cache.clear();
    },
  };
}
