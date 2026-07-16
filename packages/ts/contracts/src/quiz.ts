import { z } from "zod";
import { AiProvider, Confidence, QuizMode, Uuid } from "./common.js";

/** A single quiz question. Answer key stays server-side until scoring. */
export const QuizQuestion = z.object({
  id: z.string(),
  kind: z.enum(["multiple_choice", "true_false", "short_answer"]),
  prompt: z.string(),
  /** Present for choice questions; omitted for short_answer. */
  options: z.array(z.string()).optional(),
  /** Where the question's evidence came from (provenance for honesty). */
  quizMode: QuizMode,
  // Bounded like PlanStep.pageStart/pageEnd — quiz_questions.source_citation_index
  // is a Postgres `integer` (max ~2.1B), and an unbounded schema let an
  // AI-hallucinated value (e.g. 10^15) sail through validation straight into the
  // insert, crashing it. A question realistically cites one of a handful of
  // grounding citations, so 1000 is a generous safety margin.
  sourceCitationIndex: z.number().int().nonnegative().max(1000).optional(),
});
export type QuizQuestion = z.infer<typeof QuizQuestion>;

export const QuizInstance = z.object({
  quizId: Uuid,
  stepId: Uuid,
  quizMode: QuizMode,
  questions: z.array(QuizQuestion).min(1),
  generatedByProvider: AiProvider,
  generatedByModel: z.string(),
  confidence: Confidence,
});
export type QuizInstance = z.infer<typeof QuizInstance>;

// ---- POST /v1/steps/:id/quiz ----
export const QuizGenerateRequest = z.object({
  /** Optional reader-supplied page text → enables `user_text` mode. */
  userProvidedText: z.string().max(20000).optional(),
  questionCount: z.number().int().min(2).max(8).default(4),
  regenerate: z.boolean().default(false),
});
export type QuizGenerateRequest = z.infer<typeof QuizGenerateRequest>;

// ---- POST /v1/quiz/:id/submit ----
export const QuizSubmitRequest = z.object({
  answers: z
    .array(
      z.object({
        questionId: z.string(),
        answer: z.string(),
      }),
    )
    .min(1),
});
export type QuizSubmitRequest = z.infer<typeof QuizSubmitRequest>;

export const QuizSubmitResponse = z.object({
  quizId: Uuid,
  correctCount: z.number().int().nonnegative(),
  totalCount: z.number().int().positive(),
  passed: z.boolean(),
  markedComplete: z.boolean(),
  perQuestion: z.array(
    z.object({
      questionId: z.string(),
      correct: z.boolean(),
      correctAnswer: z.string(),
      explanation: z.string().optional(),
    }),
  ),
  streak: z.object({
    currentStreak: z.number().int().nonnegative(),
    longestStreak: z.number().int().nonnegative(),
    xpGained: z.number().int().nonnegative(),
  }),
});
export type QuizSubmitResponse = z.infer<typeof QuizSubmitResponse>;

// ---- POST /v1/quiz/:id/check ----
/** Instant per-question feedback (Duolingo-style) — does NOT record an attempt
 * or affect the streak. Only the final `submitQuiz` does that. */
export const QuizCheckRequest = z.object({
  questionId: z.string(),
  answer: z.string(),
});
export type QuizCheckRequest = z.infer<typeof QuizCheckRequest>;

export const QuizCheckResponse = z.object({
  correct: z.boolean(),
  correctAnswer: z.string(),
  explanation: z.string().optional(),
});
export type QuizCheckResponse = z.infer<typeof QuizCheckResponse>;
