import type { FastifyInstance } from "fastify";
import {
  type BookGroundRequest,
  type BookGroundResponse,
  type BookIdentity,
  type BookSearchRequest,
  type BookSearchResponse,
  type CatalogCandidate,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { searchCatalog } from "../services/catalog.js";
import { groundBook } from "../services/grounding.js";
import { register } from "./helpers.js";

/**
 * Build a best-effort deterministic identity from the top candidate, before any
 * grounding. Confidence is low on purpose: this is a pre-grounding suggestion.
 */
function suggestFrom(candidates: CatalogCandidate[]): BookIdentity | undefined {
  const top = candidates[0];
  if (!top) return undefined;
  const identity: BookIdentity = {
    canonicalTitle: top.title,
    authors: top.authors.length > 0 ? top.authors : ["Unknown"],
    // Deterministic-only guess; grounding assigns the real confidence.
    confidence: 0.4,
  };
  if (top.isbn13) identity.isbn13 = top.isbn13;
  if (top.source === "google_books") identity.googleBooksId = top.sourceId;
  if (top.source === "open_library") identity.openLibraryKey = top.sourceId;
  if (top.pageCount) identity.pageCount = top.pageCount;
  if (top.languageCode && top.languageCode.length === 2) identity.languageCode = top.languageCode;
  if (top.publishedYear) identity.publishedYear = top.publishedYear;
  if (top.coverUrl) identity.coverUrl = top.coverUrl;
  return identity;
}

export function registerBookRoutes(app: FastifyInstance, deps: Deps): void {
  register<BookSearchRequest, BookSearchResponse>(app, deps, "searchBooks", async ({ body }) => {
    const params: Parameters<typeof searchCatalog>[2] = { title: body.title, limit: body.limit };
    if (body.author) params.author = body.author;
    if (body.isbn13) params.isbn13 = body.isbn13;
    const candidates = await searchCatalog(deps.config.env, deps.config.logger, params);
    const suggested = suggestFrom(candidates);
    return suggested ? { candidates, suggested } : { candidates };
  });

  register<BookGroundRequest, BookGroundResponse>(app, deps, "groundBook", async ({ body }) => {
    // If the caller didn't pre-supply candidates, fetch them now so grounding
    // always has a deterministic base to reconcile.
    let candidates = body.candidates;
    if (candidates.length === 0) {
      const params: Parameters<typeof searchCatalog>[2] = { title: body.title, limit: 10 };
      if (body.author) params.author = body.author;
      candidates = await searchCatalog(deps.config.env, deps.config.logger, params);
    }
    return groundBook(deps, { ...body, candidates });
  });
}
