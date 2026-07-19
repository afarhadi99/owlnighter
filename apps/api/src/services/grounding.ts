import { z } from "zod";
import { eq, or } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import { contentHash } from "@owlnighter/shared";
import {
  BookIdentity,
  type BookGroundRequest,
  type BookGroundResponse,
  type GroundingStatus,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { unavailable } from "../plugins/errors.js";
import { isTaskConfigured } from "./ai-availability.js";

/**
 * Schema the grounding model must return. This is the "truth layer": edition
 * identity plus the sources and facts that back it. We deliberately keep it
 * separate from the API's BookGroundResponse — the API response is derived from
 * this after we persist and assign a bookId.
 */
const GroundedIdentity = z.object({
  identity: BookIdentity,
  /** Whether page-level quizzing is unsafe due to weak source coverage. */
  pageLevelUnsafe: z.boolean(),
  sources: z
    .array(
      z.object({
        sourceType: z.enum(["google_books", "open_library", "web"]),
        url: z.url().optional(),
        title: z.string().optional(),
        snippet: z.string().optional(),
        trustScore: z.number().min(0).max(1),
      }),
    )
    .default([]),
  facts: z
    .array(
      z.object({
        factType: z.enum(["page_count", "chapter_map", "character", "theme", "preview_segment"]),
        key: z.string(),
        value: z.unknown(),
        confidence: z.number().min(0).max(1),
        /** Indices into the `sources` array that back this fact. */
        sourceIndices: z.array(z.number().int()).default([]),
      }),
    )
    .default([]),
});
type GroundedIdentity = z.infer<typeof GroundedIdentity>;

const SYSTEM_PROMPT = [
  "You are a book catalog reconciliation system. Use Google Search Grounding.",
  "Resolve the most likely edition-level identity from the provided candidates.",
  "Return page_count only if supported by citations.",
  "Set pageLevelUnsafe=true when source coverage is too weak to guarantee page-specific quizzing.",
  "Return only JSON matching the schema.",
].join(" ");

function userPrompt(req: BookGroundRequest): string {
  const lines = [
    "Reader query:",
    `- title: ${JSON.stringify(req.title)}`,
    req.author ? `- author: ${JSON.stringify(req.author)}` : undefined,
    `- locale: ${JSON.stringify(req.locale)}`,
    "",
    "Candidate records:",
  ].filter(Boolean) as string[];
  req.candidates.forEach((c, i) => {
    lines.push(`${i + 1}) ${c.source}: ${JSON.stringify(c)}`);
  });
  lines.push(
    "",
    "Tasks: choose the most likely edition-level identity; estimate confidence;",
    "attach grounded source citations; flag pageLevelUnsafe if coverage is low.",
  );
  return lines.join("\n");
}

/** confidence >= AUTO auto-accept; >= FLOOR review; else limited. */
export type ReviewBucket = "auto_accepted" | "needs_review" | "limited";

export function reviewBucketFor(deps: Deps, confidence: number): ReviewBucket {
  const { GROUNDING_AUTO_ACCEPT, GROUNDING_REVIEW_FLOOR } = deps.config.env;
  if (confidence >= GROUNDING_AUTO_ACCEPT) return "auto_accepted";
  if (confidence >= GROUNDING_REVIEW_FLOOR) return "needs_review";
  return "limited";
}

/** Map confidence bucket + coverage flag to the persisted grounding_status. */
function groundingStatusFor(bucket: ReviewBucket, pageLevelUnsafe: boolean): GroundingStatus {
  if (bucket === "limited") return "blocked";
  if (bucket === "needs_review" || pageLevelUnsafe) return "partial";
  return "grounded";
}

/**
 * Find an existing book by strong identity keys, so re-grounding the same title
 * updates the same row instead of creating duplicates.
 */
async function findExistingBook(deps: Deps, identity: BookIdentity): Promise<string | undefined> {
  const conds = [];
  if (identity.isbn13) conds.push(eq(schema.books.isbn13, identity.isbn13));
  if (identity.googleBooksId) conds.push(eq(schema.books.googleBooksId, identity.googleBooksId));
  if (conds.length === 0) return undefined;
  const rows = await deps.db
    .select({ id: schema.books.id })
    .from(schema.books)
    // any strong key match is the same book
    .where(conds.length === 1 ? conds[0] : or(...conds))
    .limit(1);
  return rows[0]?.id;
}

/**
 * Two-pass grounding. Pass 1 (deterministic catalog candidates) is done by the
 * caller and passed in as `req.candidates`; here we run pass 2 (Gemini + Search
 * Grounding), persist the truth layer, and return the API response.
 */
export async function groundBook(deps: Deps, req: BookGroundRequest): Promise<BookGroundResponse> {
  if (!(await isTaskConfigured(deps, "book_grounding"))) {
    throw unavailable("Grounding unavailable: no AI provider is configured for book grounding.");
  }

  const inputHash = contentHash([req.title, req.author, req.locale, JSON.stringify(req.candidates)]);

  const result = await deps.ai.generateObject<GroundedIdentity>({
    task: "book_grounding",
    schemaName: "GroundedIdentity",
    schema: GroundedIdentity,
    system: SYSTEM_PROMPT,
    user: userPrompt(req),
    requireGrounding: true,
    requireStrictSchema: true,
  });

  const grounded = result.data;
  const identity = grounded.identity;
  const bucket = reviewBucketFor(deps, identity.confidence);
  const status = groundingStatusFor(bucket, grounded.pageLevelUnsafe);

  // ---- Persist the book (upsert on strong identity) ----
  const existingId = await findExistingBook(deps, identity);
  const bookValues = {
    canonicalTitle: identity.canonicalTitle,
    canonicalAuthor: identity.authors,
    isbn13: identity.isbn13 ?? null,
    googleBooksId: identity.googleBooksId ?? null,
    openLibraryKey: identity.openLibraryKey ?? null,
    editionLabel: identity.editionLabel ?? null,
    languageCode: identity.languageCode ?? null,
    publishedYear: identity.publishedYear ?? null,
    pageCount: identity.pageCount ?? null,
    coverUrl: identity.coverUrl ?? null,
    metadataConfidence: String(identity.confidence),
    groundingStatus: status,
    updatedAt: new Date(),
  };

  let bookId: string;
  if (existingId) {
    await deps.db.update(schema.books).set(bookValues).where(eq(schema.books.id, existingId));
    bookId = existingId;
  } else {
    const inserted = await deps.db.insert(schema.books).values(bookValues).returning({ id: schema.books.id });
    bookId = inserted[0]!.id;
  }

  // ---- Persist the grounding run ----
  const citations = result.citations;
  const runRows = await deps.db
    .insert(schema.bookGroundingRuns)
    .values({
      bookId,
      provider: result.provider,
      providerModel: result.model,
      runKind: "reconcile",
      inputHash,
      status: "succeeded",
      citationsJson: citations,
      rawResult: grounded as unknown as Record<string, unknown>,
      completedAt: new Date(),
    })
    .returning({ id: schema.bookGroundingRuns.id });
  const runId = runRows[0]!.id;

  // ---- Persist sources, keeping their array index → row id for fact provenance ----
  const sourceIdByIndex = new Map<number, string>();
  for (let i = 0; i < grounded.sources.length; i++) {
    const s = grounded.sources[i]!;
    const rows = await deps.db
      .insert(schema.bookGroundingSources)
      .values({
        groundingRunId: runId,
        sourceType: s.sourceType,
        sourceUrl: s.url ?? null,
        sourceTitle: s.title ?? null,
        sourceSnippet: s.snippet ?? null,
        citationIndex: i,
        trustScore: String(s.trustScore),
      })
      .returning({ id: schema.bookGroundingSources.id });
    sourceIdByIndex.set(i, rows[0]!.id);
  }

  // ---- Persist facts with resolved source-id provenance ----
  for (const f of grounded.facts) {
    const provenanceSourceIds = f.sourceIndices
      .map((idx) => sourceIdByIndex.get(idx))
      .filter((v): v is string => typeof v === "string");
    await deps.db.insert(schema.bookGroundingFacts).values({
      groundingRunId: runId,
      factType: f.factType,
      key: f.key,
      valueJson: f.value as unknown as Record<string, unknown>,
      confidence: String(f.confidence),
      provenanceSourceIds,
    });
  }

  return {
    bookId,
    identity,
    groundingStatus: status,
    pageLevelUnsafe: grounded.pageLevelUnsafe,
    citations,
  };
}
