import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../app.js";
import { DEV_BEARER, DEV_USER_ID, fakeDeps, tableRows } from "../test/helpers.js";

const STEP_ID = "dddddddd-dddd-4ddd-8ddd-dddddddddddd";
const QUIZ_ID = "ffffffff-ffff-4fff-8fff-ffffffffffff";
const Q1 = "q1111111-1111-4111-8111-111111111111";
const Q2 = "q2222222-2222-4222-8222-222222222222";

test("POST /v1/steps/:id/quiz reuses an existing quiz (no answer key leaked)", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows(
    [schema.profiles, []],
    // The step+plan join returns the drizzle nested row shape.
    [
      schema.readingPlanSteps,
      [
        {
          reading_plan_steps: { id: STEP_ID, title: "Night 1", quizMode: "grounded", chapterHint: null, pageStart: null, pageEnd: null },
          reading_plans: { userId: DEV_USER_ID },
        },
      ],
    ],
    [schema.quizInstances, [{ id: QUIZ_ID, stepId: STEP_ID, userId: DEV_USER_ID, quizMode: "grounded", provider: "gemini", providerModel: "gemini-test", confidence: "0.9" }]],
    [schema.quizQuestions, [{ id: Q1, kind: "multiple_choice", prompt: "Who?", options: ["a", "b"], correctAnswer: "a", explanation: "spoiler", sourceCitationIndex: null }]],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "POST", url: `/v1/steps/${STEP_ID}/quiz`, headers: DEV_BEARER, payload: {} });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { quizId: string; questions: Array<Record<string, unknown>> };
    assert.equal(body.quizId, QUIZ_ID);
    assert.equal(body.questions.length, 1);
    // The client-safe shape must never carry the answer key or explanation.
    assert.equal(body.questions[0]!["correctAnswer"], undefined);
    assert.equal(body.questions[0]!["explanation"], undefined);
  } finally {
    await app.close();
  }
});

test("POST /v1/steps/:id/quiz requires auth (401)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "POST", url: `/v1/steps/${STEP_ID}/quiz`, payload: {} });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("POST /v1/quiz/:id/submit scores answers, passes, and advances the streak", async () => {
  const { schema } = await import("@owlnighter/db");
  const today = new Date().toISOString().slice(0, 10);
  const byTable = tableRows(
    [schema.profiles, []],
    [schema.quizInstances, [{ id: QUIZ_ID, userId: DEV_USER_ID, stepId: STEP_ID, quizMode: "grounded" }]],
    [
      schema.quizQuestions,
      [
        { id: Q1, ordinal: 0, correctAnswer: "a", explanation: "because" },
        { id: Q2, ordinal: 1, correctAnswer: "true", explanation: null },
      ],
    ],
    [schema.readingSessions, [{ id: "s1", stepId: STEP_ID, completedAt: null, startedAt: new Date() }]],
    [schema.streakDays, [{ id: "sd1", day: today, xp: 0 }]],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "POST",
      url: `/v1/quiz/${QUIZ_ID}/submit`,
      headers: DEV_BEARER,
      payload: { answers: [{ questionId: Q1, answer: " A " }, { questionId: Q2, answer: "true" }] },
    });
    assert.equal(res.statusCode, 200);
    const body = res.json() as {
      correctCount: number;
      totalCount: number;
      passed: boolean;
      markedComplete: boolean;
      streak: { currentStreak: number; xpGained: number };
    };
    assert.equal(body.correctCount, 2); // case/space-insensitive match
    assert.equal(body.totalCount, 2);
    assert.equal(body.passed, true);
    assert.equal(body.markedComplete, true);
    assert.equal(body.streak.xpGained, 20);
    assert.equal(body.streak.currentStreak, 1);
  } finally {
    await app.close();
  }
});

test("POST /v1/quiz/:id/check reports correct with the answer key and explanation", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows(
    [schema.profiles, []],
    [schema.quizInstances, [{ id: QUIZ_ID, userId: DEV_USER_ID, stepId: STEP_ID }]],
    [schema.quizQuestions, [{ id: Q1, quizId: QUIZ_ID, ordinal: 0, correctAnswer: "a", explanation: "because" }]],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "POST",
      url: `/v1/quiz/${QUIZ_ID}/check`,
      headers: DEV_BEARER,
      payload: { questionId: Q1, answer: " A " },
    });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { correct: boolean; correctAnswer: string; explanation?: string };
    assert.equal(body.correct, true);
    assert.equal(body.correctAnswer, "a");
    assert.equal(body.explanation, "because");
  } finally {
    await app.close();
  }
});

test("POST /v1/quiz/:id/check reports incorrect without recording an attempt", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows(
    [schema.profiles, []],
    [schema.quizInstances, [{ id: QUIZ_ID, userId: DEV_USER_ID, stepId: STEP_ID }]],
    [schema.quizQuestions, [{ id: Q1, quizId: QUIZ_ID, ordinal: 0, correctAnswer: "a", explanation: null }]],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "POST",
      url: `/v1/quiz/${QUIZ_ID}/check`,
      headers: DEV_BEARER,
      payload: { questionId: Q1, answer: "b" },
    });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { correct: boolean; correctAnswer: string; explanation?: string };
    assert.equal(body.correct, false);
    assert.equal(body.correctAnswer, "a");
    assert.equal(body.explanation, undefined);
  } finally {
    await app.close();
  }
});

test("POST /v1/quiz/:id/check is 404 for a quiz owned by another user", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows(
    [schema.profiles, []],
    [schema.quizInstances, [{ id: QUIZ_ID, userId: "77777777-7777-4777-8777-777777777777", stepId: STEP_ID }]],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "POST",
      url: `/v1/quiz/${QUIZ_ID}/check`,
      headers: DEV_BEARER,
      payload: { questionId: Q1, answer: "a" },
    });
    assert.equal(res.statusCode, 404);
  } finally {
    await app.close();
  }
});

test("POST /v1/quiz/:id/check requires auth (401)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "POST", url: `/v1/quiz/${QUIZ_ID}/check`, payload: { questionId: Q1, answer: "a" } });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("POST /v1/quiz/:id/submit is 404 for a quiz owned by another user", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows(
    [schema.profiles, []],
    [schema.quizInstances, [{ id: QUIZ_ID, userId: "77777777-7777-4777-8777-777777777777", stepId: STEP_ID }]],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "POST",
      url: `/v1/quiz/${QUIZ_ID}/submit`,
      headers: DEV_BEARER,
      payload: { answers: [{ questionId: Q1, answer: "a" }] },
    });
    assert.equal(res.statusCode, 404);
  } finally {
    await app.close();
  }
});
