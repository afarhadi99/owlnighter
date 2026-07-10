import { z } from "zod";
import { Confidence, IsoDate, IsoDateTime, PacingMode, QuizMode, Uuid } from "./common.js";

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

// ---- GET /v1/admin/plans ----
/** One reading plan as shown in the admin plan browser. `stepCount` is derived
 * from reading_plan_steps so the list can never disagree with the plan's steps. */
export const AdminPlanSummary = z.object({
  planId: Uuid,
  userId: Uuid,
  bookId: Uuid,
  provider: z.string(),
  providerModel: z.string(),
  planVersion: z.number().int(),
  pacingMode: PacingMode,
  nightlyGoalPages: z.number().int(),
  startsOn: IsoDate,
  createdAt: IsoDateTime,
  stepCount: z.number().int().nonnegative(),
});
export type AdminPlanSummary = z.infer<typeof AdminPlanSummary>;

export const AdminPlansResponse = z.object({ plans: z.array(AdminPlanSummary) });
export type AdminPlansResponse = z.infer<typeof AdminPlansResponse>;

// ---- GET /v1/admin/quizzes ----
/** One quiz instance as shown in the admin quiz browser. `questionCount` is
 * derived from quiz_questions; `invalidatedAt` is present only when retired. */
export const AdminQuizSummary = z.object({
  quizId: Uuid,
  stepId: Uuid,
  userId: Uuid,
  quizMode: QuizMode,
  provider: z.string(),
  providerModel: z.string(),
  confidence: Confidence,
  invalidatedAt: IsoDateTime.optional(),
  questionCount: z.number().int().nonnegative(),
  createdAt: IsoDateTime,
});
export type AdminQuizSummary = z.infer<typeof AdminQuizSummary>;

export const AdminQuizzesResponse = z.object({ quizzes: z.array(AdminQuizSummary) });
export type AdminQuizzesResponse = z.infer<typeof AdminQuizzesResponse>;

// ---- POST /v1/admin/push/test ----
/** The four notification kinds the push pipeline can render. Mirrors the
 * ReminderKind / PushType union in @owlnighter/jobs. */
export const PushType = z.enum([
  "nightly_reminder",
  "streak_warning",
  "completion_celebration",
  "re_engagement",
]);
export type PushType = z.infer<typeof PushType>;

export const AdminPushTestRequest = z.object({
  userId: Uuid,
  type: PushType,
});
export type AdminPushTestRequest = z.infer<typeof AdminPushTestRequest>;

/** Per-token delivery outcome. `token` is masked; `detail` explains a
 * not_configured/error result (absent when sent). */
export const AdminPushTestTokenResult = z.object({
  token: z.string(),
  platform: z.string(),
  status: z.enum(["sent", "not_configured", "error"]),
  detail: z.string().optional(),
});
export type AdminPushTestTokenResult = z.infer<typeof AdminPushTestTokenResult>;

export const AdminPushTestResponse = z.object({
  userId: Uuid,
  type: PushType,
  /** True only when FCM_PROJECT_ID and FCM_SERVICE_ACCOUNT_JSON are both set. */
  configured: z.boolean(),
  notification: z.object({ title: z.string(), body: z.string() }),
  results: z.array(AdminPushTestTokenResult),
});
export type AdminPushTestResponse = z.infer<typeof AdminPushTestResponse>;
