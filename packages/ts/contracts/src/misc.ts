import { z } from "zod";
import { Uuid, UserBookStatus } from "./common.js";

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
