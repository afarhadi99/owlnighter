import { z } from "zod";
import { IsoDateTime } from "./common.js";

export const AI_PROVIDER_NAMES = ["gemini", "groq", "openrouter", "ai_tutor_api"] as const;
export const AiProviderName = z.enum(AI_PROVIDER_NAMES);
export type AiProviderName = z.infer<typeof AiProviderName>;

/**
 * Per-key Zod validators. The single source of truth for what a setting's
 * `value` may hold. `PUT /v1/admin/settings/:key` validates against this
 * registry (not a single static request schema) because every key has a
 * different shape.
 */
export const SETTINGS_SCHEMA = {
  "max_books_per_user": z.number().int().min(1).max(50),
  "flag.groq_quiz_generation": z.boolean(),
  "flag.tts_pregeneration": z.boolean(),
  "flag.grounding_review_queue": z.boolean(),
  "grounding.auto_accept": z.number().min(0).max(1),
  "grounding.review_floor": z.number().min(0).max(1),
  "catalog.open_library_base_url": z.string().url(),
  "catalog.google_books_api_key": z.string(),
  "ai.gemini.model": z.string().min(1),
  "ai.deepgram.tts_model": z.string().min(1),
  "ai_provider.groq.api_key": z.string(),
  "ai_provider.groq.model": z.string(),
  "ai_provider.groq.system_prompt.plan_generation": z.string(),
  "ai_provider.groq.system_prompt.quiz_generation": z.string(),
  "ai_provider.openrouter.api_key": z.string(),
  "ai_provider.openrouter.model": z.string(),
  "ai_provider.openrouter.system_prompt.plan_generation": z.string(),
  "ai_provider.openrouter.system_prompt.quiz_generation": z.string(),
  "ai_provider.ai_tutor_api.api_key": z.string(),
  "ai_provider.ai_tutor_api.workflow_id.book_grounding": z.string(),
  "ai_provider.ai_tutor_api.workflow_id.plan_generation": z.string(),
  "ai_provider.ai_tutor_api.workflow_id.quiz_generation": z.string(),
  "ai_provider.ai_tutor_api.workflow_id.rewrite": z.string(),
  "ai_provider.default": AiProviderName,
  // Every task is overridable — packages/ts/ai/src/router.ts resolves
  // provider = taskOverrides[task] ?? default ?? "ai_tutor_api" for all four
  // tasks, with a structural-capability fallback to Gemini when the
  // preferred provider can't serve the task (no key, or ai_tutor_api missing
  // that task's workflow_id). `null` clears an override back to the default.
  "ai_provider.task_override.book_grounding": AiProviderName.nullable(),
  "ai_provider.task_override.plan_generation": AiProviderName.nullable(),
  "ai_provider.task_override.quiz_generation": AiProviderName.nullable(),
  "ai_provider.task_override.rewrite": AiProviderName.nullable(),
} as const satisfies Record<string, z.ZodType>;
export type SettingKey = keyof typeof SETTINGS_SCHEMA;
export const SETTING_KEYS = Object.keys(SETTINGS_SCHEMA) as SettingKey[];

/** Keys whose value is a credential — GET responses mask them, PUT accepts a fresh value only. */
export const SECRET_SETTING_KEYS: ReadonlySet<string> = new Set([
  "catalog.google_books_api_key",
  "ai_provider.groq.api_key",
  "ai_provider.openrouter.api_key",
  "ai_provider.ai_tutor_api.api_key",
]);

// ---- GET /v1/admin/settings ----
/** A secret row never carries its real value — only whether one is configured + a masked hint. */
export const AdminSettingRow = z.object({
  key: z.string(),
  value: z.unknown(),
  isSecret: z.boolean(),
  configured: z.boolean().optional(),
  hint: z.string().optional(),
  updatedAt: IsoDateTime,
});
export type AdminSettingRow = z.infer<typeof AdminSettingRow>;

export const AdminSettingsResponse = z.object({ settings: z.array(AdminSettingRow) });
export type AdminSettingsResponse = z.infer<typeof AdminSettingsResponse>;

// ---- PUT /v1/admin/settings/:key ----
export const AdminUpdateSettingRequest = z.object({ value: z.unknown() });
export type AdminUpdateSettingRequest = z.infer<typeof AdminUpdateSettingRequest>;

export const AdminUpdateSettingResponse = z.object({
  key: z.string(),
  updatedAt: IsoDateTime,
});
export type AdminUpdateSettingResponse = z.infer<typeof AdminUpdateSettingResponse>;

// ---- GET /v1/admin/ai/models?provider=groq|openrouter ----
export const AiModelInfo = z.object({
  id: z.string(),
  name: z.string(),
  contextLength: z.number().int().optional(),
  pricing: z.object({ prompt: z.string().optional(), completion: z.string().optional() }).optional(),
  modality: z.string().optional(),
});
export type AiModelInfo = z.infer<typeof AiModelInfo>;

export const AdminAiModelsResponse = z.object({
  provider: z.enum(["groq", "openrouter"]),
  models: z.array(AiModelInfo),
});
export type AdminAiModelsResponse = z.infer<typeof AdminAiModelsResponse>;
