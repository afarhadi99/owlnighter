import { z } from "zod";
import { BookIdentity } from "./book.js";
import { AiProvider, Confidence, PacingMode, QuizMode, Uuid } from "./common.js";

/** One night's worth of reading in a plan. */
export const PlanStep = z.object({
  stepIndex: z.number().int().nonnegative(),
  title: z.string(),
  // Bounded to catch AI hallucinations before they hit the DB — reading_plan_steps'
  // page_start/page_end are Postgres `integer` (max ~2.1B), and an unbounded schema
  // let occasional wild values (e.g. 10^15) through, crashing the insert.
  pageStart: z.number().int().nonnegative().max(100_000).optional(),
  pageEnd: z.number().int().nonnegative().max(100_000).optional(),
  chapterHint: z.string().optional(),
  quizMode: QuizMode,
  prompt: z.string(),
  confidence: Confidence,
});
export type PlanStep = z.infer<typeof PlanStep>;

/**
 * The full contract for a generated plan. Mirrors the research blueprint:
 * Gemini can emit this schema-constrained; Groq emits JSON that we validate.
 */
export const GroundedBookPlan = z.object({
  book: BookIdentity,
  pacingMode: PacingMode,
  nightlyGoalPages: z.number().int().min(3).max(50),
  rationale: z.string(),
  steps: z.array(PlanStep).min(1),
  citations: z
    .array(
      z.object({
        title: z.string(),
        url: z.url(),
        reason: z.string(),
      }),
    )
    .default([]),
});
export type GroundedBookPlan = z.infer<typeof GroundedBookPlan>;

// ---- POST /v1/plans/generate ----
export const PlanGenerateRequest = z.object({
  bookId: Uuid,
  goal: z.string().default("build nightly habit"),
  experience: z.enum(["new", "returning", "avid"]).default("returning"),
  pacingMode: PacingMode.default("standard"),
  bedtimeLocal: z
    .string()
    .regex(/^\d{2}:\d{2}$/)
    .optional(),
  maxMinutes: z.number().int().min(5).max(180).default(25),
  timezone: z.string().default("UTC"),
  /** Force a provider; otherwise routing rules decide. */
  provider: AiProvider.optional(),
  /**
   * What to do when the caller already has a plan for this book:
   *  - "reuse"      : return the latest existing plan WITHOUT calling the AI
   *  - "regenerate" : always author a new plan version
   * Defaults to "reuse" so re-opening a book is cheap and instant.
   */
  ifExists: z.enum(["reuse", "regenerate"]).default("reuse"),
});
export type PlanGenerateRequest = z.infer<typeof PlanGenerateRequest>;

/** State attached to a step for the reader UI (unlocked, done, etc.). */
export const PlanStepState = z.object({
  stepId: Uuid,
  stepIndex: z.number().int().nonnegative(),
  status: z.enum(["locked", "available", "completed"]),
  unlocksAt: z.iso.datetime().optional(),
  ttsAssetId: Uuid.optional(),
});
export type PlanStepState = z.infer<typeof PlanStepState>;

/**
 * A lightweight plan row for list views. Cheaper than PlanResponse (no steps or
 * step states); the client fetches the full plan via GET /v1/plans/:id on tap.
 */
export const PlanSummary = z.object({
  planId: Uuid,
  bookId: Uuid,
  planVersion: z.number().int(),
  pacingMode: PacingMode,
  nightlyGoalPages: z.number().int(),
  startsOn: z.iso.date(),
  createdAt: z.iso.datetime(),
});
export type PlanSummary = z.infer<typeof PlanSummary>;

// ---- GET /v1/plans?bookId= ----
export const ListPlansResponse = z.object({
  plans: z.array(PlanSummary),
});
export type ListPlansResponse = z.infer<typeof ListPlansResponse>;

export const PlanResponse = z.object({
  planId: Uuid,
  bookId: Uuid,
  provider: AiProvider,
  providerModel: z.string(),
  planVersion: z.number().int(),
  pacingMode: PacingMode,
  nightlyGoalPages: z.number().int(),
  startsOn: z.iso.date(),
  endsOn: z.iso.date().optional(),
  steps: z.array(PlanStep),
  stepStates: z.array(PlanStepState),
});
export type PlanResponse = z.infer<typeof PlanResponse>;
