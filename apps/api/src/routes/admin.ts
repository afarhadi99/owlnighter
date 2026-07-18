import type { FastifyInstance } from "fastify";
import { asc, count, desc, eq, inArray } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import {
  type AdminGroundingResponse,
  type AdminMetricsResponse,
  type AdminOverrideRequest,
  type AdminPlanSummary,
  type AdminPlansResponse,
  type AdminPushTestRequest,
  type AdminPushTestResponse,
  type AdminPushTestTokenResult,
  type AdminQuizInvalidateRequest,
  type AdminQuizInvalidateResponse,
  type AdminQuizSummary,
  type AdminQuizzesResponse,
  type AdminTtsResponse,
  type BookSearchRequest,
  type BookSearchResponse,
  type GroundingFact,
  type GroundingRun,
  type GroundingSource,
  type GroundingStatus,
  type TtsAssetSummary,
} from "@owlnighter/contracts";
import { mintFcmAccessToken, pushTemplateFor, sendPush, type PushDeps } from "@owlnighter/jobs";
import type { Deps } from "../deps.js";
import { badRequest, notFound } from "../plugins/errors.js";
import { reviewBucketFor } from "../services/grounding.js";
import { searchCatalog } from "../services/catalog.js";
import { suggestFrom } from "./books.js";
import { register } from "./helpers.js";

/** Clamp a `?limit=` query param to a sane window (default 50, max 200). */
function parseLimit(query: unknown, def = 50, max = 200): number {
  const raw = (query as Record<string, string> | undefined)?.["limit"];
  const n = raw !== undefined ? Number(raw) : def;
  if (!Number.isFinite(n) || n <= 0) return def;
  return Math.min(Math.floor(n), max);
}

/** Mask a device token so the admin response never leaks a full credential. */
function maskToken(token: string): string {
  if (token.length <= 10) return "***";
  return `${token.slice(0, 6)}…${token.slice(-4)}`;
}

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
  // Same deterministic search as the user-facing `searchBooks` (mobile "add a
  // book" flow), but gated by admin_panel session instead of a Supabase user
  // JWT — the admin console never holds the latter, so it needs its own route
  // rather than reusing /v1/books/search directly.
  register<BookSearchRequest, BookSearchResponse>(app, deps, "adminSearchBooks", async ({ body }) => {
    const params: Parameters<typeof searchCatalog>[2] = { title: body.title, limit: body.limit };
    if (body.author) params.author = body.author;
    if (body.isbn13) params.isbn13 = body.isbn13;
    const candidates = await searchCatalog(deps.config.env, deps.config.logger, params);
    const suggested = suggestFrom(candidates);
    return suggested ? { candidates, suggested } : { candidates };
  });

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

  register<never, AdminPlansResponse>(app, deps, "adminListPlans", async ({ req }) => {
    const limit = parseLimit(req.query);
    const planRows = await deps.db
      .select({
        id: schema.readingPlans.id,
        userId: schema.readingPlans.userId,
        bookId: schema.readingPlans.bookId,
        provider: schema.readingPlans.provider,
        providerModel: schema.readingPlans.providerModel,
        planVersion: schema.readingPlans.planVersion,
        pacingMode: schema.readingPlans.pacingMode,
        nightlyGoalPages: schema.readingPlans.nightlyGoalPages,
        startsOn: schema.readingPlans.startsOn,
        createdAt: schema.readingPlans.createdAt,
      })
      .from(schema.readingPlans)
      .orderBy(desc(schema.readingPlans.createdAt))
      .limit(limit);

    // One grouped count for the whole page rather than N per-plan queries.
    const planIds = planRows.map((p) => p.id);
    const countRows = planIds.length
      ? await deps.db
          .select({ planId: schema.readingPlanSteps.planId, value: count() })
          .from(schema.readingPlanSteps)
          .where(inArray(schema.readingPlanSteps.planId, planIds))
          .groupBy(schema.readingPlanSteps.planId)
      : [];
    const stepCounts = new Map<string, number>();
    for (const r of countRows) stepCounts.set(r.planId, Number(r.value));

    const plans: AdminPlanSummary[] = planRows.map((p) => ({
      planId: p.id,
      userId: p.userId,
      bookId: p.bookId,
      provider: p.provider,
      providerModel: p.providerModel,
      planVersion: p.planVersion,
      pacingMode: p.pacingMode as AdminPlanSummary["pacingMode"],
      nightlyGoalPages: p.nightlyGoalPages,
      startsOn: p.startsOn, // drizzle `date` column → 'YYYY-MM-DD' string
      createdAt: p.createdAt.toISOString(),
      stepCount: stepCounts.get(p.id) ?? 0,
    }));
    return { plans };
  });

  register<never, AdminQuizzesResponse>(app, deps, "adminListQuizzes", async ({ req }) => {
    const query = req.query as Record<string, string> | undefined;
    const limit = parseLimit(req.query);
    const stepId = query?.["stepId"];

    const quizRows = await deps.db
      .select({
        id: schema.quizInstances.id,
        stepId: schema.quizInstances.stepId,
        userId: schema.quizInstances.userId,
        quizMode: schema.quizInstances.quizMode,
        provider: schema.quizInstances.provider,
        providerModel: schema.quizInstances.providerModel,
        confidence: schema.quizInstances.confidence,
        invalidatedAt: schema.quizInstances.invalidatedAt,
        createdAt: schema.quizInstances.createdAt,
      })
      .from(schema.quizInstances)
      // `where(undefined)` is a no-op filter, so the optional stepId narrows cleanly.
      .where(stepId ? eq(schema.quizInstances.stepId, stepId) : undefined)
      .orderBy(desc(schema.quizInstances.createdAt))
      .limit(limit);

    const quizIds = quizRows.map((q) => q.id);
    const countRows = quizIds.length
      ? await deps.db
          .select({ quizId: schema.quizQuestions.quizId, value: count() })
          .from(schema.quizQuestions)
          .where(inArray(schema.quizQuestions.quizId, quizIds))
          .groupBy(schema.quizQuestions.quizId)
      : [];
    const questionCounts = new Map<string, number>();
    for (const r of countRows) questionCounts.set(r.quizId, Number(r.value));

    const quizzes: AdminQuizSummary[] = quizRows.map((q) => {
      const s: AdminQuizSummary = {
        quizId: q.id,
        stepId: q.stepId,
        userId: q.userId,
        quizMode: q.quizMode as AdminQuizSummary["quizMode"],
        provider: q.provider,
        providerModel: q.providerModel,
        confidence: Number(q.confidence),
        questionCount: questionCounts.get(q.id) ?? 0,
        createdAt: q.createdAt.toISOString(),
      };
      if (q.invalidatedAt) s.invalidatedAt = q.invalidatedAt.toISOString();
      return s;
    });
    return { quizzes };
  });

  register<AdminPushTestRequest, AdminPushTestResponse>(app, deps, "adminTestPush", async ({ body }) => {
    const { env } = deps.config;
    const configured = env.FCM_PROJECT_ID.length > 0 && env.FCM_SERVICE_ACCOUNT_JSON.length > 0;
    const template = pushTemplateFor(body.type);

    const tokenRows = await deps.db
      .select({ token: schema.pushTokens.token, platform: schema.pushTokens.platform })
      .from(schema.pushTokens)
      .where(eq(schema.pushTokens.userId, body.userId));

    const pushDeps: PushDeps = {
      projectId: env.FCM_PROJECT_ID,
      serviceAccountJson: env.FCM_SERVICE_ACCOUNT_JSON,
      logger: deps.config.logger,
    };

    // Mint the OAuth token once and reuse it across every device token.
    const accessToken = configured ? ((await mintFcmAccessToken(pushDeps)) ?? undefined) : undefined;

    const results: AdminPushTestTokenResult[] = [];
    for (const t of tokenRows) {
      const res = await sendPush(pushDeps, {
        token: t.token,
        notification: { title: template.title, body: template.body },
        data: template.data,
        ...(accessToken ? { accessToken } : {}),
      });
      results.push({
        token: maskToken(t.token),
        platform: t.platform,
        status: res.status,
        ...(res.status === "sent" ? {} : { detail: res.reason }),
      });
    }

    return {
      userId: body.userId,
      type: body.type,
      configured,
      notification: { title: template.title, body: template.body },
      results,
    };
  });
}
