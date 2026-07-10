import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../app.js";
import { DEV_BEARER, DEV_USER_ID, fakeAi, fakeDeps, tableRows } from "../test/helpers.js";

const BOOK_ID = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
const PLAN_ID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const STEP_ID = "dddddddd-dddd-4ddd-8ddd-dddddddddddd";

const GENERATED_PLAN = {
  book: { canonicalTitle: "Dune", authors: ["Frank Herbert"], confidence: 0.95 },
  pacingMode: "standard",
  nightlyGoalPages: 12,
  rationale: "steady nightly habit",
  steps: [
    { stepIndex: 0, title: "Night 1", quizMode: "grounded", prompt: "Read the opening", confidence: 0.9 },
  ],
  citations: [],
};

test("POST /v1/plans/generate persists a plan and returns steps + states", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows(
    [schema.profiles, []],
    [schema.books, [{ id: BOOK_ID, canonicalTitle: "Dune", canonicalAuthor: ["Frank Herbert"], metadataConfidence: "0.95", groundingStatus: "grounded", pageCount: 412 }]],
    [schema.readingPlans, [{ id: PLAN_ID }]], // prior-version select + insert-returning both land here
    [schema.readingPlanSteps, [{ id: STEP_ID }]],
  );
  const app = await buildApp(fakeDeps({ byTable, ai: fakeAi(GENERATED_PLAN), env: { GEMINI_API_KEY: "test-key" } }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/plans/generate",
      headers: DEV_BEARER,
      payload: { bookId: BOOK_ID, provider: "gemini" },
    });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { planId: string; steps: unknown[]; stepStates: Array<{ status: string }> };
    assert.equal(body.planId, PLAN_ID);
    assert.equal(body.steps.length, 1);
    assert.equal(body.stepStates[0]?.status, "available"); // first step available
  } finally {
    await app.close();
  }
});

test("POST /v1/plans/generate is 404 when the book does not exist", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows([schema.profiles, []], [schema.books, []]);
  const app = await buildApp(fakeDeps({ byTable, env: { GEMINI_API_KEY: "test-key" } }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/plans/generate",
      headers: DEV_BEARER,
      payload: { bookId: BOOK_ID },
    });
    assert.equal(res.statusCode, 404);
  } finally {
    await app.close();
  }
});

test("POST /v1/plans/generate requires auth (401)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "POST", url: "/v1/plans/generate", payload: { bookId: BOOK_ID } });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("GET /v1/plans/:id returns the plan for its owner", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows(
    [schema.profiles, []],
    [schema.readingPlans, [{ id: PLAN_ID, userId: DEV_USER_ID, bookId: BOOK_ID, provider: "gemini", providerModel: "gemini-test", planVersion: 1, pacingMode: "standard", nightlyGoalPages: 12, startsOn: "2026-07-01" }]],
    [schema.books, [{ metadataConfidence: "0.95" }]],
    [schema.readingPlanSteps, [{ id: STEP_ID, stepIndex: 0, title: "Night 1", quizMode: "grounded", shortPrompt: "Read" }]],
    [schema.readingSessions, []],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "GET", url: `/v1/plans/${PLAN_ID}`, headers: DEV_BEARER });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { planId: string; steps: unknown[]; stepStates: Array<{ status: string }> };
    assert.equal(body.planId, PLAN_ID);
    assert.equal(body.steps.length, 1);
    assert.equal(body.stepStates[0]?.status, "available");
  } finally {
    await app.close();
  }
});

test("GET /v1/plans/:id is 404 for a plan owned by another user", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows(
    [schema.profiles, []],
    [schema.readingPlans, [{ id: PLAN_ID, userId: "77777777-7777-4777-8777-777777777777", bookId: BOOK_ID }]],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "GET", url: `/v1/plans/${PLAN_ID}`, headers: DEV_BEARER });
    assert.equal(res.statusCode, 404);
  } finally {
    await app.close();
  }
});
