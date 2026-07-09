import type { FastifyInstance } from "fastify";
import { asc, count, desc, eq, inArray } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import {
  type AdminGroundingResponse,
  type AdminMetricsResponse,
  type AdminOverrideRequest,
  type AdminQuizInvalidateRequest,
  type AdminQuizInvalidateResponse,
  type AdminTtsResponse,
  type GroundingFact,
  type GroundingRun,
  type GroundingSource,
  type GroundingStatus,
  type TtsAssetSummary,
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

  register<never, AdminMetricsResponse>(app, deps, "adminGetMetrics", async () => {
    // Grounding buckets are threshold-derived (env-configured), so we bucket
    // per-book confidence in JS rather than in SQL. The same scan yields the
    // total book count, so no extra query is needed for that tile.
    const bookRows = await deps.db.select({ confidence: schema.books.metadataConfidence }).from(schema.books);
    let autoAccepted = 0;
    let needsReview = 0;
    let limited = 0;
    for (const b of bookRows) {
      const bucket = reviewBucketFor(deps, Number(b.confidence));
      if (bucket === "auto_accepted") autoAccepted++;
      else if (bucket === "needs_review") needsReview++;
      else limited++;
    }

    const attemptsRows = await deps.db.select({ value: count() }).from(schema.quizAttempts);
    const passedRows = await deps.db
      .select({ value: count() })
      .from(schema.quizAttempts)
      .where(eq(schema.quizAttempts.passed, true));
    const attempts = attemptsRows[0]?.value ?? 0;
    const passed = passedRows[0]?.value ?? 0;
    const passRate = attempts > 0 ? passed / attempts : 0;

    const ttsRows = await deps.db.select({ value: count() }).from(schema.ttsAssets);

    return {
      grounding: { autoAccepted, needsReview, limited },
      quiz: { attempts, passRate },
      tts: { assets: ttsRows[0]?.value ?? 0 },
      books: { total: bookRows.length },
    };
  });

  register<never, AdminTtsResponse>(app, deps, "adminGetTts", async () => {
    const rows = await deps.db
      .select()
      .from(schema.ttsAssets)
      .orderBy(desc(schema.ttsAssets.createdAt))
      .limit(200);
    const assets: TtsAssetSummary[] = rows.map((a) => {
      const s: TtsAssetSummary = {
        id: a.id,
        assetKey: a.assetKey,
        provider: a.provider,
        voiceModel: a.voiceModel,
        locale: a.locale,
        storagePath: a.storagePath,
        createdAt: a.createdAt.toISOString(),
      };
      if (a.durationMs != null) s.durationMs = a.durationMs;
      return s;
    });
    return { assets };
  });

  register<AdminQuizInvalidateRequest, AdminQuizInvalidateResponse>(
    app,
    deps,
    "adminInvalidateQuiz",
    async ({ params, body }) => {
      const quizId = params["id"];
      if (!quizId) throw badRequest("Missing quiz id.");

      const rows = await deps.db
        .select({ id: schema.quizInstances.id })
        .from(schema.quizInstances)
        .where(eq(schema.quizInstances.id, quizId))
        .limit(1);
      if (!rows[0]) throw notFound("Quiz not found.");

      await deps.db
        .update(schema.quizInstances)
        .set({ invalidatedAt: new Date(), invalidationReason: body.reason })
        .where(eq(schema.quizInstances.id, quizId));

      deps.config.logger.info({ quizId, reason: body.reason }, "quiz invalidated");
      return { quizId, invalidated: true };
    },
  );
}
