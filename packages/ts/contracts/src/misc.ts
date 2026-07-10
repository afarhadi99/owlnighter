import { z } from "zod";
import { GroundingStatus, Uuid, UserBookStatus } from "./common.js";

// ---- POST /v1/library/books ----
export const AddLibraryBookRequest = z.object({
  bookId: Uuid,
  targetNightlyPages: z.number().int().min(1).max(100).default(10),
  preferredReadingTimeLocal: z
    .string()
    .regex(/^\d{2}:\d{2}$/)
    .optional(),
  timezone: z.string().default("UTC"),
});
export type AddLibraryBookRequest = z.infer<typeof AddLibraryBookRequest>;

export const LibraryBook = z.object({
  id: Uuid,
  bookId: Uuid,
  status: UserBookStatus,
  currentPage: z.number().int().nonnegative().optional(),
  targetNightlyPages: z.number().int().optional(),
});
export type LibraryBook = z.infer<typeof LibraryBook>;

// ---- GET /v1/library/books ----
/**
 * A library entry enriched with its book's catalog identity (joined from
 * public.books) so the reader can render a real card — title, authors, cover,
 * grounding badge, and length — without a second lookup. `LibraryBook` above
 * stays the lean shape returned by POST add; this View is the list projection.
 */
export const LibraryBookView = z.object({
  id: Uuid,
  bookId: Uuid,
  status: UserBookStatus,
  currentPage: z.number().int().nonnegative().optional(),
  targetNightlyPages: z.number().int().optional(),
  // ---- joined from public.books ----
  title: z.string(),
  authors: z.array(z.string()),
  coverUrl: z.string().optional(),
  groundingStatus: GroundingStatus,
  pageCount: z.number().int().positive().optional(),
});
export type LibraryBookView = z.infer<typeof LibraryBookView>;

export const LibraryBooksResponse = z.object({ books: z.array(LibraryBookView) });
export type LibraryBooksResponse = z.infer<typeof LibraryBooksResponse>;

// ---- POST /v1/steps/:id/start ----
/** Opens (or reuses) a reading_sessions row for a plan step. */
export const StepStartResponse = z.object({
  sessionId: Uuid,
  stepId: Uuid,
  startedAt: z.iso.datetime(),
});
export type StepStartResponse = z.infer<typeof StepStartResponse>;

// ---- POST /v1/push/register ----
export const PushRegisterRequest = z.object({
  token: z.string().min(1),
  platform: z.enum(["ios", "android", "web"]),
  appVersion: z.string().optional(),
});
export type PushRegisterRequest = z.infer<typeof PushRegisterRequest>;

// ---- POST /v1/tts/generate ----
export const TtsGenerateRequest = z.object({
  text: z.string().min(1).max(5000),
  voiceModel: z.string().default("aura-2-thalia-en"),
  speakingRate: z.number().min(0.5).max(2).optional(),
  locale: z.string().default("en"),
  /** Link the generated asset to a plan step for prefetch. */
  stepId: Uuid.optional(),
});
export type TtsGenerateRequest = z.infer<typeof TtsGenerateRequest>;

export const TtsGenerateResponse = z.object({
  assetId: Uuid,
  assetKey: z.string(),
  cached: z.boolean(),
  storagePath: z.string(),
  durationMs: z.number().int().optional(),
});
export type TtsGenerateResponse = z.infer<typeof TtsGenerateResponse>;
