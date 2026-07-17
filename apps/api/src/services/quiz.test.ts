import { test } from "node:test";
import assert from "node:assert/strict";
import { computeStreaks, GeneratedQuiz, quizVariables } from "./quiz.js";

// quizVariables only reads step.title/chapterHint/pageStart/pageEnd and
// req.questionCount/userProvidedText, so we cast minimal literals to the real
// parameter types rather than materializing full drizzle rows / contract objects.
type Step = Parameters<typeof quizVariables>[0];
type Req = Parameters<typeof quizVariables>[2];

test("quizVariables produces the six named keys for a grounded step", () => {
  const step = { title: "Chapter 1", chapterHint: "Ch. 1", pageStart: 1, pageEnd: 10 } as unknown as Step;
  const req = { questionCount: 3 } as unknown as Req;
  assert.deepEqual(quizVariables(step, "grounded", req), {
    stepTitle: "Chapter 1",
    chapterHint: "Ch. 1",
    pageRange: "1-10",
    quizMode: "grounded",
    questionCount: "3",
    readerContext: "",
  });
});

test("quizVariables embeds the reader text (with its framing line) for a user_text step", () => {
  // Missing chapterHint/pageStart/pageEnd collapse to empty strings, never undefined.
  const step = { title: "Chapter 1", chapterHint: null, pageStart: null, pageEnd: null } as unknown as Step;
  const req = { questionCount: 5, userProvidedText: "The fox jumped." } as unknown as Req;
  const vars = quizVariables(step, "user_text", req);
  assert.equal(vars.chapterHint, "");
  assert.equal(vars.pageRange, "");
  assert.equal(vars.quizMode, "user_text");
  assert.equal(vars.questionCount, "5");
  const readerContext = vars.readerContext ?? "";
  assert.ok(readerContext.startsWith("Reader-supplied page text (base questions strictly on this):"));
  assert.ok(readerContext.includes("The fox jumped."));
});

// The AI router safeParses the model's output against GeneratedQuiz before the
// service inserts it. A hallucinated sourceCitationIndex beyond Postgres int4
// range (max ~2.1B) must fail here so the router retries/falls back, rather than
// sailing through into quiz_questions.source_citation_index and crashing the
// insert — the same bug class already bounded on PlanStep.pageStart/pageEnd.
test("GeneratedQuiz rejects an out-of-range sourceCitationIndex", () => {
  const base = { kind: "true_false" as const, prompt: "?", correctAnswer: "true" };
  assert.equal(GeneratedQuiz.safeParse({ questions: [{ ...base, sourceCitationIndex: 1_000_000_000_000_000 }] }).success, false);
  // A negative index is also nonsensical and must be rejected.
  assert.equal(GeneratedQuiz.safeParse({ questions: [{ ...base, sourceCitationIndex: -1 }] }).success, false);
});

test("GeneratedQuiz accepts a realistic (or omitted) sourceCitationIndex", () => {
  const base = { kind: "true_false" as const, prompt: "?", correctAnswer: "true" };
  assert.equal(GeneratedQuiz.safeParse({ questions: [{ ...base, sourceCitationIndex: 3 }] }).success, true);
  assert.equal(GeneratedQuiz.safeParse({ questions: [{ ...base }] }).success, true);
});

test("computeStreaks: no days → zero", () => {
  assert.deepEqual(computeStreaks([], "2026-07-09"), { current: 0, longest: 0 });
});

test("computeStreaks: single day today → current 1", () => {
  assert.deepEqual(computeStreaks(["2026-07-09"], "2026-07-09"), { current: 1, longest: 1 });
});

test("computeStreaks: consecutive run ending today", () => {
  const days = ["2026-07-07", "2026-07-08", "2026-07-09"];
  assert.deepEqual(computeStreaks(days, "2026-07-09"), { current: 3, longest: 3 });
});

test("computeStreaks: gap breaks current but longest is remembered", () => {
  // A 3-day run, a gap, then a 2-day run ending today.
  const days = ["2026-07-01", "2026-07-02", "2026-07-03", "2026-07-08", "2026-07-09"];
  assert.deepEqual(computeStreaks(days, "2026-07-09"), { current: 2, longest: 3 });
});

test("computeStreaks: last day is yesterday → grace keeps current alive", () => {
  const days = ["2026-07-07", "2026-07-08"];
  assert.deepEqual(computeStreaks(days, "2026-07-09"), { current: 2, longest: 2 });
});

test("computeStreaks: last day older than yesterday → current resets to 0", () => {
  const days = ["2026-07-06", "2026-07-07"];
  assert.deepEqual(computeStreaks(days, "2026-07-09"), { current: 0, longest: 2 });
});
