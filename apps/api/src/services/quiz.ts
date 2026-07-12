import { z } from "zod";
import { and, asc, desc, eq, isNull } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import { contentHash } from "@owlnighter/shared";
import {
  type QuizCheckRequest,
  type QuizCheckResponse,
  type QuizGenerateRequest,
  type QuizInstance,
  type QuizMode,
  type QuizQuestion,
  type QuizSubmitRequest,
  type QuizSubmitResponse,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { badRequest, notFound, unavailable } from "../plugins/errors.js";
import type { AuthUser } from "../types.js";

/**
 * Model output for quiz generation. Carries the answer key + explanation, which
 * NEVER leave the server — the QuizInstance returned to the client omits them.
 */
const GeneratedQuiz = z.object({
  questions: z
    .array(
      z.object({
        kind: z.enum(["multiple_choice", "true_false", "short_answer"]),
        prompt: z.string(),
        options: z.array(z.string()).optional(),
        correctAnswer: z.string(),
        explanation: z.string().optional(),
        sourceCitationIndex: z.number().int().optional(),
      }),
    )
    .min(1),
});
type GeneratedQuiz = z.infer<typeof GeneratedQuiz>;

const PASS_RATIO = 0.6; // >=60% correct marks the reading complete.
const XP_PER_QUIZ = 20; // matches the "gained 20 XP" celebration copy in the blueprint.

const SYSTEM_PROMPT = [
  "You write short comprehension quizzes for a nightly reading app.",
  "Each question needs a single unambiguous correctAnswer.",
  "For multiple_choice, include 3-4 options and set correctAnswer to the exact option text.",
  "For true_false, correctAnswer is 'true' or 'false'.",
  "Do NOT invent page-specific facts unless the provided context supports them.",
  "Output valid JSON only.",
].join(" ");

/**
 * Effective quiz mode. Reader-supplied text always wins (user_text). Otherwise
 * we inherit the step's persisted quizMode — which was already clamped to the
 * book's grounding guarantee when the plan was generated.
 */
function effectiveMode(stepMode: QuizMode, req: QuizGenerateRequest): QuizMode {
  if (req.userProvidedText && req.userProvidedText.trim().length > 0) return "user_text";
  return stepMode;
}

function userPrompt(step: typeof schema.readingPlanSteps.$inferSelect, mode: QuizMode, req: QuizGenerateRequest): string {
  const parts = [
    `Step: ${step.title}`,
    step.chapterHint ? `Chapter: ${step.chapterHint}` : undefined,
    step.pageStart != null && step.pageEnd != null ? `Pages: ${step.pageStart}-${step.pageEnd}` : undefined,
    `Quiz mode: ${mode}`,
    `Question count: ${req.questionCount}`,
  ].filter(Boolean) as string[];
  if (mode === "user_text" && req.userProvidedText) {
    parts.push("", "Reader-supplied page text (base questions strictly on this):", req.userProvidedText);
  } else if (mode === "fallback") {
    parts.push("", "No page-level text is available. Write general comprehension prompts about the reading's themes.");
  }
  return parts.join("\n");
}

export async function generateStepQuiz(deps: Deps, user: AuthUser, stepId: string, req: QuizGenerateRequest): Promise<QuizInstance> {
  // Verify the step exists and belongs to the caller (via its plan).
  const stepRows = await deps.db
    .select()
    .from(schema.readingPlanSteps)
    .innerJoin(schema.readingPlans, eq(schema.readingPlanSteps.planId, schema.readingPlans.id))
    .where(eq(schema.readingPlanSteps.id, stepId))
    .limit(1);
  const joined = stepRows[0];
  if (!joined || joined.reading_plans.userId !== user.id) throw notFound("Step not found.");
  const step = joined.reading_plan_steps;

  const mode = effectiveMode(step.quizMode as QuizMode, req);

  // Reuse an existing quiz for this step unless regeneration was requested.
  // Invalidated quizzes (retired by an admin) are skipped so the reader gets a
  // fresh generation instead of the retired one.
  if (!req.regenerate) {
    const existing = await deps.db
      .select()
      .from(schema.quizInstances)
      .where(
        and(
          eq(schema.quizInstances.stepId, stepId),
          eq(schema.quizInstances.userId, user.id),
          isNull(schema.quizInstances.invalidatedAt),
        ),
      )
      .orderBy(desc(schema.quizInstances.createdAt))
      .limit(1);
    if (existing[0]) return loadQuizInstance(deps, existing[0]);
  }

  // Provider routing: Groq-first for quiz generation when the flag allows and a
  // Groq key exists; otherwise Gemini. Fall back to the other on failure.
  const useGroqFirst = deps.config.flags.groqQuizGeneration && deps.config.env.GROQ_API_KEY.length > 0;
  const order: Array<"gemini" | "groq"> = useGroqFirst ? ["groq", "gemini"] : ["gemini", "groq"];
  const configured = order.filter((p) => (p === "gemini" ? deps.config.env.GEMINI_API_KEY : deps.config.env.GROQ_API_KEY).length > 0);
  if (configured.length === 0) throw unavailable("Quiz generation unavailable: no AI provider key is configured.");

  const inputHash = contentHash([stepId, mode, req.questionCount, req.userProvidedText]);
  const system = SYSTEM_PROMPT;
  const prompt = userPrompt(step, mode, req);

  let generated: { data: GeneratedQuiz; provider: "gemini" | "groq"; model: string; attempts: number } | undefined;
  let lastErr: unknown;
  for (const provider of configured) {
    try {
      const r = await deps.ai.generateObject<GeneratedQuiz>({
        task: "quiz_generation",
        schemaName: "GeneratedQuiz",
        schema: GeneratedQuiz,
        system,
        user: prompt,
        provider,
        // Groq Qwen has no strict schema mode; the router validates + retries.
        requireStrictSchema: provider === "gemini",
      });
      generated = { data: r.data, provider: r.provider, model: r.model, attempts: r.attempts };
      break;
    } catch (err) {
      lastErr = err;
      deps.config.logger.warn({ err, provider }, "quiz generation failed, trying next provider");
    }
  }
  if (!generated) throw unavailable(`Quiz generation failed on all providers: ${String(lastErr)}`);

  // Trim to the requested count and compute a simple confidence.
  const questions = generated.data.questions.slice(0, req.questionCount);
  const confidence = mode === "grounded" ? 0.9 : mode === "user_text" ? 0.85 : mode === "preview" ? 0.7 : 0.5;

  // Persist the instance + questions (answer key server-side).
  const instRows = await deps.db
    .insert(schema.quizInstances)
    .values({
      userId: user.id,
      stepId,
      quizMode: mode,
      provider: generated.provider,
      providerModel: generated.model,
      confidence: String(confidence),
    })
    .returning({ id: schema.quizInstances.id });
  const quizId = instRows[0]!.id;

  await deps.db.insert(schema.quizGenerationRuns).values({
    quizId,
    provider: generated.provider,
    providerModel: generated.model,
    inputHash,
    status: "succeeded",
    attempts: generated.attempts,
    rawResult: generated.data as unknown as Record<string, unknown>,
  });

  const outQuestions: QuizQuestion[] = [];
  for (let i = 0; i < questions.length; i++) {
    const q = questions[i]!;
    const qRows = await deps.db
      .insert(schema.quizQuestions)
      .values({
        quizId,
        ordinal: i,
        kind: q.kind,
        prompt: q.prompt,
        options: q.options ?? null,
        correctAnswer: q.correctAnswer,
        explanation: q.explanation ?? null,
        sourceCitationIndex: q.sourceCitationIndex ?? null,
      })
      .returning({ id: schema.quizQuestions.id });
    const question: QuizQuestion = {
      id: qRows[0]!.id,
      kind: q.kind,
      prompt: q.prompt,
      quizMode: mode,
    };
    if (q.options) question.options = q.options;
    if (q.sourceCitationIndex != null) question.sourceCitationIndex = q.sourceCitationIndex;
    outQuestions.push(question);
  }

  return {
    quizId,
    stepId,
    quizMode: mode,
    questions: outQuestions,
    generatedByProvider: generated.provider,
    generatedByModel: generated.model,
    confidence,
  };
}

/** Rehydrate a QuizInstance (client-safe: no answer key) from persisted rows. */
async function loadQuizInstance(deps: Deps, inst: typeof schema.quizInstances.$inferSelect): Promise<QuizInstance> {
  const qRows = await deps.db
    .select()
    .from(schema.quizQuestions)
    .where(eq(schema.quizQuestions.quizId, inst.id))
    .orderBy(asc(schema.quizQuestions.ordinal));
  const questions: QuizQuestion[] = qRows.map((q) => {
    const question: QuizQuestion = {
      id: q.id,
      kind: q.kind as QuizQuestion["kind"],
      prompt: q.prompt,
      quizMode: inst.quizMode as QuizMode,
    };
    if (q.options) question.options = q.options as string[];
    if (q.sourceCitationIndex != null) question.sourceCitationIndex = q.sourceCitationIndex;
    return question;
  });
  return {
    quizId: inst.id,
    stepId: inst.stepId,
    quizMode: inst.quizMode as QuizMode,
    questions,
    generatedByProvider: inst.provider as "gemini" | "groq",
    generatedByModel: inst.providerModel,
    confidence: Number(inst.confidence),
  };
}

/** Case/space-insensitive answer comparison. Exported for the check endpoint. */
export function answersMatch(given: string, correct: string): boolean {
  const norm = (s: string) => s.trim().toLowerCase().replace(/\s+/g, " ");
  return norm(given) === norm(correct);
}

/**
 * Instant per-question feedback (Duolingo-style). Looks up the question by id,
 * verifying it belongs to a quiz instance owned by the caller, and compares
 * the given answer with the server-side answer key. Unlike `submitQuiz`, this
 * never records an attempt and never touches the streak/XP ledger.
 */
export async function checkQuizAnswer(
  deps: Deps,
  user: AuthUser,
  quizId: string,
  req: QuizCheckRequest,
): Promise<QuizCheckResponse> {
  const instRows = await deps.db.select().from(schema.quizInstances).where(eq(schema.quizInstances.id, quizId)).limit(1);
  const inst = instRows[0];
  if (!inst || inst.userId !== user.id) throw notFound("Quiz not found.");

  const qRows = await deps.db.select().from(schema.quizQuestions).where(eq(schema.quizQuestions.quizId, quizId));
  const question = qRows.find((q) => q.id === req.questionId);
  if (!question) throw notFound("Question not found.");

  const correct = answersMatch(req.answer, question.correctAnswer);
  return {
    correct,
    correctAnswer: question.correctAnswer,
    ...(question.explanation ? { explanation: question.explanation } : {}),
  };
}

export async function submitQuiz(deps: Deps, user: AuthUser, quizId: string, req: QuizSubmitRequest): Promise<QuizSubmitResponse> {
  const instRows = await deps.db.select().from(schema.quizInstances).where(eq(schema.quizInstances.id, quizId)).limit(1);
  const inst = instRows[0];
  if (!inst || inst.userId !== user.id) throw notFound("Quiz not found.");

  const qRows = await deps.db
    .select()
    .from(schema.quizQuestions)
    .where(eq(schema.quizQuestions.quizId, quizId))
    .orderBy(asc(schema.quizQuestions.ordinal));
  if (qRows.length === 0) throw badRequest("Quiz has no questions.");

  const answerById = new Map(req.answers.map((a) => [a.questionId, a.answer]));

  const perQuestion: QuizSubmitResponse["perQuestion"] = [];
  let correctCount = 0;
  for (const q of qRows) {
    const given = answerById.get(q.id) ?? "";
    const correct = answersMatch(given, q.correctAnswer);
    if (correct) correctCount++;
    perQuestion.push({
      questionId: q.id,
      correct,
      correctAnswer: q.correctAnswer,
      ...(q.explanation ? { explanation: q.explanation } : {}),
    });
  }
  const totalCount = qRows.length;
  const passed = correctCount / totalCount >= PASS_RATIO;

  // Record the attempt.
  await deps.db.insert(schema.quizAttempts).values({
    quizId,
    userId: user.id,
    answers: req.answers,
    correctCount,
    totalCount,
    passed,
  });

  // On pass, mark the step's reading complete (idempotent-ish: complete the most
  // recent open session for this step, or create a completed one).
  let markedComplete = false;
  if (passed) {
    const open = await deps.db
      .select()
      .from(schema.readingSessions)
      .where(and(eq(schema.readingSessions.userId, user.id), eq(schema.readingSessions.stepId, inst.stepId)))
      .orderBy(desc(schema.readingSessions.startedAt))
      .limit(1);
    const now = new Date();
    if (open[0] && !open[0].completedAt) {
      await deps.db.update(schema.readingSessions).set({ completedAt: now }).where(eq(schema.readingSessions.id, open[0].id));
    } else if (!open[0]) {
      await deps.db.insert(schema.readingSessions).values({ userId: user.id, stepId: inst.stepId, completedAt: now });
    }
    markedComplete = true;
  }

  const streak = await updateStreak(deps, user.id, passed ? XP_PER_QUIZ : 0);

  return { quizId, correctCount, totalCount, passed, markedComplete, perQuestion, streak };
}

/**
 * Update the streak_days ledger and derive current/longest streaks. One row per
 * (user, day); we upsert today's XP, then compute the current run of consecutive
 * days ending today and the longest run ever. This keeps streak logic in one
 * place and derives from the ledger rather than a mutable counter.
 */
async function updateStreak(deps: Deps, userId: string, xpGained: number): Promise<QuizSubmitResponse["streak"]> {
  const today = new Date().toISOString().slice(0, 10);

  if (xpGained > 0) {
    const existing = await deps.db
      .select()
      .from(schema.streakDays)
      .where(and(eq(schema.streakDays.userId, userId), eq(schema.streakDays.day, today)))
      .limit(1);
    if (existing[0]) {
      await deps.db
        .update(schema.streakDays)
        .set({ xp: existing[0].xp + xpGained })
        .where(eq(schema.streakDays.id, existing[0].id));
    } else {
      await deps.db.insert(schema.streakDays).values({ userId, day: today, xp: xpGained });
    }
  }

  const rows = await deps.db
    .select({ day: schema.streakDays.day })
    .from(schema.streakDays)
    .where(eq(schema.streakDays.userId, userId))
    .orderBy(asc(schema.streakDays.day));
  const days = [...new Set(rows.map((r) => r.day))].sort();

  const { current, longest } = computeStreaks(days, today);
  return { currentStreak: current, longestStreak: longest, xpGained };
}

/** Pure streak math over sorted ISO date strings. Exported for testability. */
export function computeStreaks(sortedDays: string[], today: string): { current: number; longest: number } {
  if (sortedDays.length === 0) return { current: 0, longest: 0 };
  const dayNum = (iso: string) => Math.floor(Date.parse(`${iso}T00:00:00Z`) / 86_400_000);
  const nums = sortedDays.map(dayNum);

  let longest = 1;
  let run = 1;
  for (let i = 1; i < nums.length; i++) {
    run = nums[i]! - nums[i - 1]! === 1 ? run + 1 : 1;
    if (run > longest) longest = run;
  }

  // Current streak: consecutive days ending today (or yesterday, grace for TZ).
  const todayNum = dayNum(today);
  const last = nums.at(-1)!;
  let current = 0;
  if (last === todayNum || last === todayNum - 1) {
    current = 1;
    for (let i = nums.length - 1; i > 0; i--) {
      if (nums[i]! - nums[i - 1]! === 1) current++;
      else break;
    }
  }
  return { current, longest };
}
