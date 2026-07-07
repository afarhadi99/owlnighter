import { z } from "zod";
import { Confidence, GroundingStatus, Uuid } from "./common.js";

export const GroundingSource = z.object({
  id: Uuid,
  sourceType: z.enum(["google_books", "open_library", "web"]),
  sourceUrl: z.url().optional(),
  sourceTitle: z.string().optional(),
  sourceSnippet: z.string().optional(),
  citationIndex: z.number().int(),
  trustScore: Confidence,
});
export type GroundingSource = z.infer<typeof GroundingSource>;

export const GroundingFact = z.object({
  id: Uuid,
  factType: z.enum(["page_count", "chapter_map", "character", "theme", "preview_segment"]),
  key: z.string(),
  value: z.unknown(),
  confidence: Confidence,
  provenanceSourceIds: z.array(Uuid).default([]),
});
export type GroundingFact = z.infer<typeof GroundingFact>;

export const GroundingRun = z.object({
  id: Uuid,
  bookId: Uuid,
  provider: z.literal("gemini"),
  providerModel: z.string(),
  runKind: z.enum(["identify", "enrich", "reconcile", "preview_extract"]),
  status: z.enum(["running", "succeeded", "failed"]),
  createdAt: z.iso.datetime(),
  completedAt: z.iso.datetime().optional(),
});
export type GroundingRun = z.infer<typeof GroundingRun>;

// ---- GET /v1/admin/books/:id/grounding ----
export const AdminGroundingResponse = z.object({
  bookId: Uuid,
  groundingStatus: GroundingStatus,
  runs: z.array(GroundingRun),
  sources: z.array(GroundingSource),
  facts: z.array(GroundingFact),
  /** confidence >= 0.85 auto, 0.60–0.84 review, < 0.60 limited. */
  reviewBucket: z.enum(["auto_accepted", "needs_review", "limited"]),
});
export type AdminGroundingResponse = z.infer<typeof AdminGroundingResponse>;

// ---- POST /v1/admin/books/:id/override ----
export const AdminOverrideRequest = z.object({
  fieldOverrides: z.record(z.string(), z.unknown()),
  trustLock: z.boolean().default(false),
  reason: z.string().min(1),
});
export type AdminOverrideRequest = z.infer<typeof AdminOverrideRequest>;
