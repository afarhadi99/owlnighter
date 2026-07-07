import { z } from "zod";
import { Confidence, GroundingStatus } from "./common.js";

/** Canonical, edition-level identity of a book (the product-facing record). */
export const BookIdentity = z.object({
  canonicalTitle: z.string().min(1),
  authors: z.array(z.string()).min(1),
  editionLabel: z.string().optional(),
  isbn13: z.string().regex(/^\d{13}$/).optional(),
  googleBooksId: z.string().optional(),
  openLibraryKey: z.string().optional(),
  pageCount: z.number().int().positive().optional(),
  languageCode: z.string().length(2).optional(),
  publishedYear: z.number().int().optional(),
  coverUrl: z.url().optional(),
  confidence: Confidence,
});
export type BookIdentity = z.infer<typeof BookIdentity>;

/** A raw candidate returned by a deterministic catalog source. */
export const CatalogCandidate = z.object({
  source: z.enum(["google_books", "open_library"]),
  sourceId: z.string(),
  title: z.string(),
  authors: z.array(z.string()).default([]),
  isbn13: z.string().optional(),
  pageCount: z.number().int().positive().optional(),
  publishedYear: z.number().int().optional(),
  languageCode: z.string().optional(),
  coverUrl: z.url().optional(),
  rawUrl: z.url().optional(),
});
export type CatalogCandidate = z.infer<typeof CatalogCandidate>;

// ---- POST /v1/books/search ----
export const BookSearchRequest = z.object({
  title: z.string().min(1),
  author: z.string().optional(),
  isbn13: z.string().optional(),
  locale: z.string().default("en-US"),
  limit: z.number().int().min(1).max(25).default(10),
});
export type BookSearchRequest = z.infer<typeof BookSearchRequest>;

export const BookSearchResponse = z.object({
  candidates: z.array(CatalogCandidate),
  /** Best deterministic guess before grounding. */
  suggested: BookIdentity.optional(),
});
export type BookSearchResponse = z.infer<typeof BookSearchResponse>;

// ---- POST /v1/books/ground ----
export const BookGroundRequest = z.object({
  title: z.string().min(1),
  author: z.string().optional(),
  locale: z.string().default("en-US"),
  candidates: z.array(CatalogCandidate).default([]),
});
export type BookGroundRequest = z.infer<typeof BookGroundRequest>;

export const BookGroundResponse = z.object({
  bookId: z.uuid(),
  identity: BookIdentity,
  groundingStatus: GroundingStatus,
  /** True when page-level quizzing is unsafe due to weak source coverage. */
  pageLevelUnsafe: z.boolean(),
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
export type BookGroundResponse = z.infer<typeof BookGroundResponse>;
