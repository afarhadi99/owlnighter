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
  // Bounded to catch AI hallucinations before they hit the DB — books.page_count is
  // Postgres `integer` (max ~2.1B), and this identity is validated straight out of the
  // Gemini grounding call then inserted verbatim; an unbounded schema let wild values
  // (e.g. 10^12) through, crashing the insert. Mirrors PlanStep.pageStart/pageEnd.
  pageCount: z.number().int().positive().max(100_000).optional(),
  languageCode: z.string().length(2).optional(),
  // Bounded to a realistic calendar range for the same reason as pageCount above:
  // books.published_year is Postgres `integer` (max ~2.1B), and this identity comes
  // straight out of the Gemini grounding call then inserted verbatim; an unbounded
  // schema let a hallucinated/malformed value (e.g. a ms timestamp) crash the insert.
  publishedYear: z.number().int().min(-3000).max(2100).optional(),
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
  pageCount: z.number().int().positive().max(100_000).optional(),
  publishedYear: z.number().int().min(-3000).max(2100).optional(),
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
