import { z } from "zod";

/** Shared scalar + enum vocabulary used across every contract. */

export const Uuid = z.uuid();
export const IsoDateTime = z.iso.datetime();
export const IsoDate = z.iso.date();

export const AiProvider = z.enum(["gemini", "groq"]);
export type AiProvider = z.infer<typeof AiProvider>;

export const PacingMode = z.enum(["gentle", "standard", "intensive"]);
export type PacingMode = z.infer<typeof PacingMode>;

/**
 * How trustworthy a step's quiz is. The product NEVER claims page-specific
 * precision it cannot back with text:
 *  - grounded  : questions backed by grounded facts/citations
 *  - preview   : backed by public preview/context, not full page text
 *  - user_text : reader supplied the page text/photo
 *  - fallback  : generic comprehension prompts; no page-level guarantee
 */
export const QuizMode = z.enum(["grounded", "preview", "user_text", "fallback"]);
export type QuizMode = z.infer<typeof QuizMode>;

export const GroundingStatus = z.enum(["pending", "grounded", "partial", "blocked"]);
export type GroundingStatus = z.infer<typeof GroundingStatus>;

export const UserBookStatus = z.enum(["active", "paused", "completed", "archived"]);
export type UserBookStatus = z.infer<typeof UserBookStatus>;

export const Confidence = z.number().min(0).max(1);

/** Standard error envelope returned by the API. */
export const ApiError = z.object({
  error: z.object({
    code: z.string(),
    message: z.string(),
    requestId: z.string().optional(),
    details: z.unknown().optional(),
  }),
});
export type ApiError = z.infer<typeof ApiError>;
