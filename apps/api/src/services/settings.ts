import {
  SECRET_SETTING_KEYS,
  SETTINGS_SCHEMA,
  type AdminSettingsResponse,
  type AdminUpdateSettingResponse,
  type SettingKey,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { badRequest, notFound } from "../plugins/errors.js";

function maskHint(value: unknown): string {
  const s = typeof value === "string" ? value : "";
  return s.length === 0 ? "not set" : `…${s.slice(-4)}`;
}

export async function getAllSettings(deps: Deps): Promise<AdminSettingsResponse> {
  const rows = await deps.settings.listAll();
  return {
    settings: rows.map((r) => {
      if (r.isSecret) {
        const configured = typeof r.value === "string" && r.value.length > 0;
        return {
          key: r.key,
          value: undefined,
          isSecret: true,
          configured,
          hint: maskHint(r.value),
          updatedAt: r.updatedAt.toISOString(),
        };
      }
      return { key: r.key, value: r.value, isSecret: false, updatedAt: r.updatedAt.toISOString() };
    }),
  };
}

export async function updateSetting(
  deps: Deps,
  adminId: string,
  key: string,
  rawValue: unknown,
): Promise<AdminUpdateSettingResponse> {
  const schema = SETTINGS_SCHEMA[key as SettingKey];
  if (!schema) throw notFound(`Unknown setting key: ${key}`);
  const parsed = schema.safeParse(rawValue);
  if (!parsed.success) throw badRequest(`Invalid value for "${key}".`, parsed.error.issues);
  const isSecret = SECRET_SETTING_KEYS.has(key);
  const updatedAt = await deps.settings.set(key, parsed.data, isSecret, adminId);
  return { key, updatedAt: updatedAt.toISOString() };
}
