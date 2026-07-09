import { z } from "zod";
import { Confidence, Uuid } from "./common.js";

// ---- GET /v1/admin/metrics ----
/**
 * Dashboard tiles for the admin console. Counts are derived on read from the
 * canonical tables so the dashboard can never drift from the data it reflects.
 */
export const AdminMetricsResponse = z.object({
  grounding: z.object({
    autoAccepted: z.number().int().nonnegative(),
    needsReview: z.number().int().nonnegative(),
    limited: z.number().int().nonnegative(),
  }),
  quiz: z.object({
    attempts: z.number().int().nonnegative(),
    passRate: Confidence,
  }),
  tts: z.object({
    assets: z.number().int().nonnegative(),
  }),
  books: z.object({
    total: z.number().int().nonnegative(),
  }),
});
export type AdminMetricsResponse = z.infer<typeof AdminMetricsResponse>;

// ---- GET /v1/admin/tts ----
/** One cached TTS asset as shown in the admin cache inspector. */
export const TtsAssetSummary = z.object({
  id: Uuid,
  assetKey: z.string(),
  provider: z.string(),
  voiceModel: z.string(),
  locale: z.string(),
  storagePath: z.string(),
  durationMs: z.number().int().optional(),
  createdAt: z.iso.datetime(),
});
export type TtsAssetSummary = z.infer<typeof TtsAssetSummary>;

export const AdminTtsResponse = z.object({ assets: z.array(TtsAssetSummary) });
export type AdminTtsResponse = z.infer<typeof AdminTtsResponse>;

// ---- POST /v1/admin/quiz/:id/invalidate ----
export const AdminQuizInvalidateRequest = z.object({ reason: z.string().min(1) });
export type AdminQuizInvalidateRequest = z.infer<typeof AdminQuizInvalidateRequest>;

export const AdminQuizInvalidateResponse = z.object({
  quizId: Uuid,
  invalidated: z.literal(true),
});
export type AdminQuizInvalidateResponse = z.infer<typeof AdminQuizInvalidateResponse>;
