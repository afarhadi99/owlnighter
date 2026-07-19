import { and, asc, desc, eq } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import {
  GroundedBookPlan,
  type BookIdentity,
  type ListPlansResponse,
  type PacingMode,
  type PlanGenerateRequest,
  type PlanResponse,
  type PlanStep,
  type PlanStepState,
  type PlanSummary,
  type QuizMode,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { notFound, unavailable } from "../plugins/errors.js";
import { isTaskConfigured } from "./ai-availability.js";
import type { AuthUser } from "../types.js";

const SYSTEM_PROMPT = [
  "You create realistic nightly reading plans from a grounded fact set.",
  "Each step covers one night. Only set pageStart/pageEnd when page data is trustworthy.",
  "Set a per-step quizMode: 'grounded' when backed by grounded facts, 'preview' for",
  "public-preview context, 'fallback' when there is no page-level guarantee.",
  "Output valid JSON only, matching the schema.",
].join(" ");

function loadIdentity(row: typeof schema.books.$inferSelect): BookIdentity {
  const identity: BookIdentity = {
    canonicalTitle: row.canonicalTitle,
    authors: row.canonicalAuthor,
    confidence: Number(row.metadataConfidence),
  };
  if (row.editionLabel) identity.editionLabel = row.editionLabel;
  if (row.isbn13) identity.isbn13 = row.isbn13;
  if (row.googleBooksId) identity.googleBooksId = row.googleBooksId;
  if (row.openLibraryKey) identity.openLibraryKey = row.openLibraryKey;
  if (row.pageCount) identity.pageCount = row.pageCount;
  if (row.languageCode) identity.languageCode = row.languageCode;
  if (row.publishedYear) identity.publishedYear = row.publishedYear;
  if (row.coverUrl) identity.coverUrl = row.coverUrl;
  return identity;
}

function userPrompt(identity: BookIdentity, groundingStatus: string, req: PlanGenerateRequest): string {
  const coverageMode = groundingStatus === "grounded" ? "grounded" : groundingStatus === "partial" ? "preview" : "fallback";
  const facts = {
    // Identity MUST be in the prompt — without it the model has no idea which
    // book it is planning for and will hallucinate chapters from another title.
    title: identity.canonicalTitle,
    authors: identity.authors,
    editionLabel: identity.editionLabel,
    publishedYear: identity.publishedYear,
    pageCount: identity.pageCount,
    languageCode: identity.languageCode,
    coverageMode,
    confidence: identity.confidence,
  };
  const prefs = {
    goal: req.goal,
    experience: req.experience,
    bedtime: req.bedtimeLocal,
    maxMinutes: req.maxMinutes,
    pacingMode: req.pacingMode,
  };
  return [
    `Book facts:\n${JSON.stringify(facts, null, 2)}`,
    "",
    `Reader preferences:\n${JSON.stringify(prefs, null, 2)}`,
    "",
    "Constraints:",
    `- Pacing: ${req.pacingMode}`,
    "- Nightly goal must respect the reader's maxMinutes",
    `- Use quizMode 'fallback' for any step where page coverage is weak (coverageMode=${coverageMode})`,
  ].join("\n");
}

/**
 * A step's quiz can never claim more precision than the book's grounding
 * supports. We clamp the model's per-step quizMode down to what the book's
 * grounding_status actually allows, so the honesty guarantee holds even if the
 * model is over-optimistic.
 */
function clampQuizMode(mode: QuizMode, groundingStatus: string): QuizMode {
  if (mode === "user_text") return mode; // reader-supplied text is always allowed
  if (groundingStatus === "grounded") return mode;
  if (groundingStatus === "partial") return mode === "grounded" ? "preview" : mode;
  // blocked / pending → no page-level guarantee
  return "fallback";
}

function todayIso(): string {
  return new Date().toISOString().slice(0, 10);
}

export async function generatePlan(deps: Deps, user: AuthUser, req: PlanGenerateRequest): Promise<PlanResponse> {
  const bookRows = await deps.db.select().from(schema.books).where(eq(schema.books.id, req.bookId)).limit(1);
  const book = bookRows[0];
  if (!book) throw notFound("Book not found. Ground it first via POST /v1/books/ground.");

  // Cheap path: if the caller already has a plan for this book and asked to
  // reuse (the default), return the latest existing plan without touching the AI.
  // This is what fixes the on-device "regenerate on every open" bug.
  if (req.ifExists === "reuse") {
    const existing = await deps.db
      .select({ id: schema.readingPlans.id, userId: schema.readingPlans.userId, planVersion: schema.readingPlans.planVersion })
      .from(schema.readingPlans)
      .where(and(eq(schema.readingPlans.userId, user.id), eq(schema.readingPlans.bookId, req.bookId)))
      .orderBy(desc(schema.readingPlans.planVersion))
      .limit(1);
    // Guard ownership in JS too (getPlan re-checks), so a mis-scoped row is never reused.
    const latest = existing.find((p) => p.userId === user.id);
    if (latest) return getPlan(deps, user, latest.id);
  }

  // Provider selection for plan_generation is owned entirely by the AI router
  // (createAiRouter/generateObject in packages/ts/ai/src/router.ts) and is fully
  // overridable via admin settings — nothing here is pinned to a specific
  // provider. This pre-check just turns "nothing configured" into a clear 503
  // instead of the bare Error the router would throw (which maps to a 500).
  if (!(await isTaskConfigured(deps, "plan_generation"))) {
    throw unavailable("Plan generation unavailable: no AI provider is configured for plan generation.");
  }

  const identity = loadIdentity(book);
  const result = await deps.ai.generateObject<GroundedBookPlan>({
    task: "plan_generation",
    schemaName: "GroundedBookPlan",
    schema: GroundedBookPlan,
    system: SYSTEM_PROMPT,
    user: userPrompt(identity, book.groundingStatus, req),
    // Grounding already happened at book-ground time and its facts are baked into
    // the prompt, so the plan pass does not need live search grounding.
    requireGrounding: false,
  });
  const plan = result.data;

  // Determine plan version: bump if this user already has a plan for this book.
  const prior = await deps.db
    .select({ v: schema.readingPlans.planVersion })
    .from(schema.readingPlans)
    .where(and(eq(schema.readingPlans.userId, user.id), eq(schema.readingPlans.bookId, req.bookId)))
    .orderBy(asc(schema.readingPlans.planVersion));
  const planVersion = (prior.at(-1)?.v ?? 0) + 1;

  const startsOn = todayIso();
  const planRows = await deps.db
    .insert(schema.readingPlans)
    .values({
      userId: user.id,
      bookId: req.bookId,
      provider: result.provider,
      providerModel: result.model,
      planVersion,
      nightlyGoalPages: plan.nightlyGoalPages,
      pacingMode: plan.pacingMode,
      startsOn,
    })
    .returning({ id: schema.readingPlans.id });
  const planId = planRows[0]!.id;

  // Persist steps, clamping each quizMode to the book's grounding guarantee.
  const steps: PlanStep[] = [];
  const stepStates: PlanStepState[] = [];
  for (let i = 0; i < plan.steps.length; i++) {
    const s = plan.steps[i]!;
    const quizMode = clampQuizMode(s.quizMode, book.groundingStatus);
    const stepRows = await deps.db
      .insert(schema.readingPlanSteps)
      .values({
        planId,
        stepIndex: s.stepIndex,
        pageStart: s.pageStart ?? null,
        pageEnd: s.pageEnd ?? null,
        chapterHint: s.chapterHint ?? null,
        title: s.title,
        shortPrompt: s.prompt,
        quizMode,
      })
      .returning({ id: schema.readingPlanSteps.id });
    const stepId = stepRows[0]!.id;

    steps.push({ ...s, quizMode });
    // First step is available immediately; the rest unlock as the reader progresses.
    stepStates.push({
      stepId,
      stepIndex: s.stepIndex,
      status: i === 0 ? "available" : "locked",
    });
  }

  return {
    planId,
    bookId: req.bookId,
    provider: result.provider,
    providerModel: result.model,
    planVersion,
    pacingMode: plan.pacingMode,
    nightlyGoalPages: plan.nightlyGoalPages,
    startsOn,
    steps,
    stepStates,
  };
}

/**
 * List the caller's plans as lightweight summaries (newest planVersion first),
 * optionally narrowed to a single book. The client fetches the full plan via
 * GET /v1/plans/:id when the user taps one.
 */
export async function listPlans(deps: Deps, user: AuthUser, bookId?: string): Promise<ListPlansResponse> {
  const where = bookId
    ? and(eq(schema.readingPlans.userId, user.id), eq(schema.readingPlans.bookId, bookId))
    : eq(schema.readingPlans.userId, user.id);
  const rows = await deps.db
    .select({
      id: schema.readingPlans.id,
      bookId: schema.readingPlans.bookId,
      planVersion: schema.readingPlans.planVersion,
      pacingMode: schema.readingPlans.pacingMode,
      nightlyGoalPages: schema.readingPlans.nightlyGoalPages,
      startsOn: schema.readingPlans.startsOn,
      createdAt: schema.readingPlans.createdAt,
    })
    .from(schema.readingPlans)
    .where(where)
    .orderBy(desc(schema.readingPlans.planVersion));

  const plans: PlanSummary[] = rows.map((r) => ({
    planId: r.id,
    bookId: r.bookId,
    planVersion: r.planVersion,
    pacingMode: r.pacingMode as PacingMode,
    nightlyGoalPages: r.nightlyGoalPages,
    startsOn: r.startsOn, // drizzle `date` column → 'YYYY-MM-DD' string
    createdAt: r.createdAt.toISOString(),
  }));
  return { plans };
}

/** Fetch a persisted plan + its step states for the reader UI. */
export async function getPlan(deps: Deps, user: AuthUser, planId: string): Promise<PlanResponse> {
  const planRows = await deps.db.select().from(schema.readingPlans).where(eq(schema.readingPlans.id, planId)).limit(1);
  const plan = planRows[0];
  if (!plan || plan.userId !== user.id) throw notFound("Plan not found.");

  const bookRows = await deps.db
    .select({ metadataConfidence: schema.books.metadataConfidence })
    .from(schema.books)
    .where(eq(schema.books.id, plan.bookId))
    .limit(1);
  const book = bookRows[0];

  const stepRows = await deps.db
    .select()
    .from(schema.readingPlanSteps)
    .where(eq(schema.readingPlanSteps.planId, planId))
    .orderBy(asc(schema.readingPlanSteps.stepIndex));

  // Completed steps are those with a completed reading_session.
  const sessions = await deps.db
    .select({ stepId: schema.readingSessions.stepId, completedAt: schema.readingSessions.completedAt })
    .from(schema.readingSessions)
    .where(eq(schema.readingSessions.userId, user.id));
  const completed = new Set(sessions.filter((s) => s.completedAt).map((s) => s.stepId));

  const steps: PlanStep[] = [];
  const stepStates: PlanStepState[] = [];
  let firstIncompleteSeen = false;
  for (const row of stepRows) {
    steps.push({
      stepIndex: row.stepIndex,
      title: row.title,
      ...(row.pageStart != null ? { pageStart: row.pageStart } : {}),
      ...(row.pageEnd != null ? { pageEnd: row.pageEnd } : {}),
      ...(row.chapterHint ? { chapterHint: row.chapterHint } : {}),
      quizMode: row.quizMode as QuizMode,
      prompt: row.shortPrompt ?? "",
      // Per-step confidence isn't persisted (only the quizMode provenance is);
      // the book's metadataConfidence is the meaningful trust signal here.
      confidence: Number(book?.metadataConfidence ?? 1),
    });

    const isCompleted = completed.has(row.id);
    let status: PlanStepState["status"];
    if (isCompleted) status = "completed";
    else if (!firstIncompleteSeen) {
      status = "available";
      firstIncompleteSeen = true;
    } else status = "locked";

    const state: PlanStepState = { stepId: row.id, stepIndex: row.stepIndex, status };
    if (row.unlocksAt) state.unlocksAt = row.unlocksAt.toISOString();
    if (row.ttsAssetId) state.ttsAssetId = row.ttsAssetId;
    stepStates.push(state);
  }

  return {
    planId: plan.id,
    bookId: plan.bookId,
    provider: plan.provider as "gemini" | "groq",
    providerModel: plan.providerModel,
    planVersion: plan.planVersion,
    pacingMode: plan.pacingMode as PlanResponse["pacingMode"],
    nightlyGoalPages: plan.nightlyGoalPages,
    startsOn: plan.startsOn,
    ...(plan.endsOn ? { endsOn: plan.endsOn } : {}),
    steps,
    stepStates,
  };
}
