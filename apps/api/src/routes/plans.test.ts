import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../app.js";
import type { AiRouter } from "../deps.js";
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

test("GET /v1/plans returns [] when the caller has no plans", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows([schema.profiles, []], [schema.readingPlans, []]);
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "GET", url: "/v1/plans", headers: DEV_BEARER });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { plans: unknown[] };
    assert.deepEqual(body.plans, []);
  } finally {
    await app.close();
  }
});

test("GET /v1/plans?bookId= returns the caller's plan summaries", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows(
    [schema.profiles, []],
    [
      schema.readingPlans,
      [
        {
          id: PLAN_ID,
          bookId: BOOK_ID,
          planVersion: 2,
          pacingMode: "standard",
          nightlyGoalPages: 12,
          startsOn: "2026-07-01",
          createdAt: new Date("2026-07-01T00:00:00.000Z"),
        },
      ],
    ],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "GET", url: `/v1/plans?bookId=${BOOK_ID}`, headers: DEV_BEARER });
    assert.equal(res.statusCode, 200);
    const body = res.json() as {
      plans: Array<{ planId: string; bookId: string; planVersion: number; createdAt: string; steps?: unknown }>;
    };
    assert.equal(body.plans.length, 1);
    assert.equal(body.plans[0]?.planId, PLAN_ID);
    assert.equal(body.plans[0]?.bookId, BOOK_ID);
    assert.equal(body.plans[0]?.planVersion, 2);
    assert.equal(body.plans[0]?.createdAt, "2026-07-01T00:00:00.000Z");
    assert.equal(body.plans[0]?.steps, undefined); // summary is lightweight — no steps
  } finally {
    await app.close();
  }
});

test("GET /v1/plans requires auth (401)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "GET", url: "/v1/plans" });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("POST /v1/plans/generate with ifExists:reuse returns the existing plan without calling the AI", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows(
    [schema.profiles, []],
    [
      schema.books,
      [{ id: BOOK_ID, canonicalTitle: "Dune", canonicalAuthor: ["Frank Herbert"], metadataConfidence: "0.95", groundingStatus: "grounded", pageCount: 412 }],
    ],
    [
      schema.readingPlans,
      [
        {
          id: PLAN_ID,
          userId: DEV_USER_ID,
          bookId: BOOK_ID,
          provider: "gemini",
          providerModel: "gemini-test",
          planVersion: 3,
          pacingMode: "standard",
          nightlyGoalPages: 12,
          startsOn: "2026-07-01",
        },
      ],
    ],
    [schema.readingPlanSteps, [{ id: STEP_ID, stepIndex: 0, title: "Night 1", quizMode: "grounded", shortPrompt: "Read" }]],
    [schema.readingSessions, []],
  );
  let aiCalled = false;
  const ai: Partial<AiRouter> = {
    generateObject: (async () => {
      aiCalled = true;
      throw new Error("AI must not run on reuse");
    }) as AiRouter["generateObject"],
  };
  const app = await buildApp(fakeDeps({ byTable, ai, env: { GEMINI_API_KEY: "test-key" } }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/plans/generate",
      headers: DEV_BEARER,
      payload: { bookId: BOOK_ID, ifExists: "reuse" },
    });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { planId: string; planVersion: number };
    assert.equal(body.planId, PLAN_ID);
    assert.equal(body.planVersion, 3); // the LATEST existing version, unchanged
    assert.equal(aiCalled, false, "the AI router must not be invoked when reusing");
  } finally {
    await app.close();
  }
});

test("POST /v1/plans/generate with ifExists:regenerate authors a new version via the AI", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows(
    [schema.profiles, []],
    [
      schema.books,
      [{ id: BOOK_ID, canonicalTitle: "Dune", canonicalAuthor: ["Frank Herbert"], metadataConfidence: "0.95", groundingStatus: "grounded", pageCount: 412 }],
    ],
    [schema.readingPlans, [{ id: PLAN_ID }]],
    [schema.readingPlanSteps, [{ id: STEP_ID }]],
  );
  let aiCalled = false;
  const ai = fakeAi(GENERATED_PLAN);
  const orig = ai.generateObject.bind(ai);
  ai.generateObject = ((args) => {
    aiCalled = true;
    return orig(args);
  }) as AiRouter["generateObject"];
  const app = await buildApp(fakeDeps({ byTable, ai, env: { GEMINI_API_KEY: "test-key" } }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/plans/generate",
      headers: DEV_BEARER,
      payload: { bookId: BOOK_ID, provider: "gemini", ifExists: "regenerate" },
    });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { planId: string; steps: unknown[] };
    assert.equal(body.planId, PLAN_ID);
    assert.equal(body.steps.length, 1);
    assert.equal(aiCalled, true, "the AI router must run when regenerating");
  } finally {
    await app.close();
  }
});
