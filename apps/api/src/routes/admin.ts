import type { FastifyInstance } from "fastify";
import { asc, desc, eq, inArray } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import {
  type AdminGroundingResponse,
  type AdminOverrideRequest,
  type GroundingFact,
  type GroundingRun,
  type GroundingSource,
  type GroundingStatus,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { badRequest, notFound } from "../plugins/errors.js";
import { reviewBucketFor } from "../services/grounding.js";
import { register } from "./helpers.js";

/** Columns on `books` an admin override is allowed to write. Guards against
 * arbitrary key injection from the free-form fieldOverrides record. */
const OVERRIDABLE = new Set([
  "canonicalTitle",
  "canonicalAuthor",
  "isbn13",
  "editionLabel",
  "languageCode",
  "publishedYear",
  "pageCount",
  "coverUrl",
  "groundingStatus",
]);

export function registerAdminRoutes(app: FastifyInstance, deps: Deps): void {
  register<never, AdminGroundingResponse>(app, deps, "adminGetGrounding", async ({ params }) => {
    const bookId = params["id"];
    if (!bookId) throw badRequest("Missing book id.");

    const bookRows = await deps.db.select().from(schema.books).where(eq(schema.books.id, bookId)).limit(1);
    const book = bookRows[0];
    if (!book) throw notFound("Book not found.");

    const runRows = await deps.db
      .select()
      .from(schema.bookGroundingRuns)
      .where(eq(schema.bookGroundingRuns.bookId, bookId))
      .orderBy(desc(schema.bookGroundingRuns.createdAt));
    const runIds = runRows.map((r) => r.id);

    const sourceRows = runIds.length
      ? await deps.db
          .select()
          .from(schema.bookGroundingSources)
          .where(inArray(schema.bookGroundingSources.groundingRunId, runIds))
          .orderBy(asc(schema.bookGroundingSources.citationIndex))
      : [];

    const factRows = runIds.length
      ? await deps.db
          .select()
          .from(schema.bookGroundingFacts)
          .where(inArray(schema.bookGroundingFacts.groundingRunId, runIds))
      : [];

    const runs: GroundingRun[] = runRows.map((r) => {
      const run: GroundingRun = {
        id: r.id,
        bookId,
        provider: "gemini",
        providerModel: r.providerModel,
        runKind: r.runKind as GroundingRun["runKind"],
        status: r.status as GroundingRun["status"],
        createdAt: r.createdAt.toISOString(),
      };
      if (r.completedAt) run.completedAt = r.completedAt.toISOString();
      return run;
    });

    const sources: GroundingSource[] = sourceRows.map((s) => {
      const src: GroundingSource = {
        id: s.id,
        sourceType: s.sourceType as GroundingSource["sourceType"],
        citationIndex: s.citationIndex,
        trustScore: Number(s.trustScore),
      };
      if (s.sourceUrl) src.sourceUrl = s.sourceUrl;
      if (s.sourceTitle) src.sourceTitle = s.sourceTitle;
      if (s.sourceSnippet) src.sourceSnippet = s.sourceSnippet;
      return src;
    });

    const facts: GroundingFact[] = factRows.map((f) => ({
      id: f.id,
      factType: f.factType as GroundingFact["factType"],
      key: f.key,
      value: f.valueJson,
      confidence: Number(f.confidence),
      provenanceSourceIds: f.provenanceSourceIds,
    }));

    return {
      bookId,
      groundingStatus: book.groundingStatus as GroundingStatus,
      runs,
      sources,
      facts,
      reviewBucket: reviewBucketFor(deps, Number(book.metadataConfidence)),
    };
  });

  // No response schema → 204 on success.
  register<AdminOverrideRequest, void>(app, deps, "adminOverrideBook", async ({ params, body }) => {
    const bookId = params["id"];
    if (!bookId) throw badRequest("Missing book id.");

    const bookRows = await deps.db.select({ id: schema.books.id }).from(schema.books).where(eq(schema.books.id, bookId)).limit(1);
    if (!bookRows[0]) throw notFound("Book not found.");

    // Whitelist the fields we allow to be overwritten.
    const set: Record<string, unknown> = { updatedAt: new Date() };
    for (const [k, v] of Object.entries(body.fieldOverrides)) {
      if (!OVERRIDABLE.has(k)) throw badRequest(`Field '${k}' is not overridable.`);
      set[k] = v;
    }
    // A trust lock pins the grounding_status to 'grounded' so downstream flows
    // treat the manually-corrected record as authoritative.
    if (body.trustLock) set["groundingStatus"] = "grounded";

    // Cast: keys are validated against OVERRIDABLE above, so this is a
    // deliberate dynamic update rather than an arbitrary write.
    await deps.db
      .update(schema.books)
      .set(set as Partial<typeof schema.books.$inferInsert>)
      .where(eq(schema.books.id, bookId));

    deps.config.logger.info({ bookId, reason: body.reason, trustLock: body.trustLock }, "admin override applied");
  });
}
