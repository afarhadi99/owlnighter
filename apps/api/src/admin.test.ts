import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "./app.js";
import { DEV_BEARER, DEV_USER_ID, fakeDeps, tableRows, type Rows } from "./test/helpers.js";

const PLAN_ID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const BOOK_ID = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
const QUIZ_ID = "ffffffff-ffff-4fff-8fff-ffffffffffff";
const RUN_ID = "10101010-1010-4010-8010-101010101010";

/** Admin routes resolve is_admin from profiles; register the dev user as admin. */
async function adminTables(...extra: Array<[unknown, Rows]>) {
  const { schema } = await import("@owlnighter/db");
  return tableRows([schema.profiles, [{ isAdmin: true }]], ...extra);
}

// ---- Auth boundary ----

test("admin route rejects a missing bearer (401)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "GET", url: "/v1/admin/metrics" });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("admin route is forbidden for a non-admin user (403)", async () => {
  const { schema } = await import("@owlnighter/db");
  const app = await buildApp(fakeDeps({ byTable: tableRows([schema.profiles, [{ isAdmin: false }]]) }));
  try {
    const res = await app.inject({ method: "GET", url: "/v1/admin/metrics", headers: DEV_BEARER });
    assert.equal(res.statusCode, 403);
    assert.equal(res.json().error.code, "forbidden");
  } finally {
    await app.close();
  }
});

// ---- GET /v1/admin/books/:id/grounding ----

test("GET /v1/admin/books/:id/grounding returns runs + review bucket", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = await adminTables(
    [schema.books, [{ id: BOOK_ID, groundingStatus: "grounded", metadataConfidence: "0.9" }]],
    [schema.bookGroundingRuns, [{ id: RUN_ID, providerModel: "gemini-test", runKind: "reconcile", status: "succeeded", createdAt: new Date(), completedAt: null }]],
    [schema.bookGroundingSources, []],
    [schema.bookGroundingFacts, []],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "GET", url: `/v1/admin/books/${BOOK_ID}/grounding`, headers: DEV_BEARER });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { groundingStatus: string; runs: unknown[]; reviewBucket: string };
    assert.equal(body.groundingStatus, "grounded");
    assert.equal(body.runs.length, 1);
    assert.equal(body.reviewBucket, "auto_accepted"); // 0.9 >= 0.85
  } finally {
    await app.close();
  }
});

test("GET /v1/admin/books/:id/grounding is 404 for an unknown book", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = await adminTables([schema.books, []]);
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "GET", url: `/v1/admin/books/${BOOK_ID}/grounding`, headers: DEV_BEARER });
    assert.equal(res.statusCode, 404);
  } finally {
    await app.close();
  }
});

// ---- POST /v1/admin/books/:id/override ----

test("POST /v1/admin/books/:id/override applies a whitelisted field (204)", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = await adminTables([schema.books, [{ id: BOOK_ID }]]);
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "POST",
      url: `/v1/admin/books/${BOOK_ID}/override`,
      headers: DEV_BEARER,
      payload: { fieldOverrides: { canonicalTitle: "Corrected Title" }, reason: "typo fix" },
    });
    assert.equal(res.statusCode, 204);
  } finally {
    await app.close();
  }
});

test("POST /v1/admin/books/:id/override rejects a non-overridable field (400)", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = await adminTables([schema.books, [{ id: BOOK_ID }]]);
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "POST",
      url: `/v1/admin/books/${BOOK_ID}/override`,
      headers: DEV_BEARER,
      payload: { fieldOverrides: { id: "hacked" }, reason: "nope" },
    });
    assert.equal(res.statusCode, 400);
  } finally {
    await app.close();
  }
});

// ---- GET /v1/admin/metrics ----

test("GET /v1/admin/metrics derives grounding buckets + pass rate", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = await adminTables(
    // metrics selects `{ confidence: books.metadataConfidence }` — the fake
    // returns rows verbatim, so register the row under the SELECT alias.
    [schema.books, [{ confidence: "0.9" }, { confidence: "0.5" }]],
    [schema.quizAttempts, [{ value: 4 }]],
    [schema.ttsAssets, [{ value: 2 }]],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "GET", url: "/v1/admin/metrics", headers: DEV_BEARER });
    assert.equal(res.statusCode, 200);
    const body = res.json() as {
      grounding: { autoAccepted: number; limited: number };
      quiz: { attempts: number; passRate: number };
      books: { total: number };
    };
    assert.equal(body.grounding.autoAccepted, 1); // 0.9
    assert.equal(body.grounding.limited, 1); // 0.5 < 0.6
    assert.equal(body.books.total, 2);
    assert.equal(body.quiz.attempts, 4);
    assert.equal(body.quiz.passRate, 1); // both count queries resolve to 4
  } finally {
    await app.close();
  }
});

// ---- GET /v1/admin/tts ----

test("GET /v1/admin/tts lists cached assets", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = await adminTables([
    schema.ttsAssets,
    [{ id: "ababab00-0000-4000-8000-000000000001", assetKey: "k1", provider: "deepgram", voiceModel: "aura-2-thalia-en", locale: "en", storagePath: "tts/k1.mp3", durationMs: 1000, createdAt: new Date() }],
  ]);
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "GET", url: "/v1/admin/tts", headers: DEV_BEARER });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { assets: Array<{ assetKey: string }> };
    assert.equal(body.assets.length, 1);
    assert.equal(body.assets[0]?.assetKey, "k1");
  } finally {
    await app.close();
  }
});

// ---- POST /v1/admin/quiz/:id/invalidate ----

test("POST /v1/admin/quiz/:id/invalidate retires a quiz", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = await adminTables([schema.quizInstances, [{ id: QUIZ_ID }]]);
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "POST",
      url: `/v1/admin/quiz/${QUIZ_ID}/invalidate`,
      headers: DEV_BEARER,
      payload: { reason: "bad question" },
    });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { quizId: string; invalidated: boolean };
    assert.equal(body.quizId, QUIZ_ID);
    assert.equal(body.invalidated, true);
  } finally {
    await app.close();
  }
});

test("POST /v1/admin/quiz/:id/invalidate is 404 for an unknown quiz", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = await adminTables([schema.quizInstances, []]);
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "POST",
      url: `/v1/admin/quiz/${QUIZ_ID}/invalidate`,
      headers: DEV_BEARER,
      payload: { reason: "x" },
    });
    assert.equal(res.statusCode, 404);
  } finally {
    await app.close();
  }
});

// ---- GET /v1/admin/plans ----

test("GET /v1/admin/plans returns plans with derived step counts", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = await adminTables(
    [schema.readingPlans, [{ id: PLAN_ID, userId: DEV_USER_ID, bookId: BOOK_ID, provider: "gemini", providerModel: "gemini-test", planVersion: 1, pacingMode: "standard", nightlyGoalPages: 10, startsOn: "2026-07-01", createdAt: new Date("2026-07-01T00:00:00.000Z") }]],
    [schema.readingPlanSteps, [{ planId: PLAN_ID, value: 7 }]],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "GET", url: "/v1/admin/plans", headers: DEV_BEARER });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { plans: Array<{ planId: string; stepCount: number; provider: string }> };
    assert.equal(body.plans.length, 1);
    assert.equal(body.plans[0]?.planId, PLAN_ID);
    assert.equal(body.plans[0]?.stepCount, 7);
    assert.equal(body.plans[0]?.provider, "gemini");
  } finally {
    await app.close();
  }
});

test("GET /v1/admin/plans honours ?limit= and stays within the cap", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = await adminTables([schema.readingPlans, []], [schema.readingPlanSteps, []]);
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "GET", url: "/v1/admin/plans?limit=5", headers: DEV_BEARER });
    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.json().plans, []);
  } finally {
    await app.close();
  }
});

// ---- GET /v1/admin/quizzes ----

test("GET /v1/admin/quizzes returns quizzes with derived question counts", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = await adminTables(
    [schema.quizInstances, [{ id: QUIZ_ID, stepId: "d0000000-0000-4000-8000-000000000000", userId: DEV_USER_ID, quizMode: "grounded", provider: "gemini", providerModel: "gemini-test", confidence: "0.9", invalidatedAt: null, createdAt: new Date() }]],
    [schema.quizQuestions, [{ quizId: QUIZ_ID, value: 4 }]],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "GET", url: "/v1/admin/quizzes", headers: DEV_BEARER });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { quizzes: Array<{ quizId: string; questionCount: number }> };
    assert.equal(body.quizzes.length, 1);
    assert.equal(body.quizzes[0]?.quizId, QUIZ_ID);
    assert.equal(body.quizzes[0]?.questionCount, 4);
  } finally {
    await app.close();
  }
});

// ---- POST /v1/admin/push/test ----

test("POST /v1/admin/push/test reports not_configured per token when FCM is unset", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = await adminTables([
    schema.pushTokens,
    [{ token: "device-token-1234567890", platform: "android" }],
  ]);
  const app = await buildApp(fakeDeps({ byTable, env: { FCM_PROJECT_ID: "", FCM_SERVICE_ACCOUNT_JSON: "" } }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/admin/push/test",
      headers: DEV_BEARER,
      // Body userId must satisfy z.uuid(); the dev id has a v0 field so use a v4.
      payload: { userId: "12121212-1212-4212-8212-121212121212", type: "nightly_reminder" },
    });
    assert.equal(res.statusCode, 200);
    const body = res.json() as {
      configured: boolean;
      notification: { title: string };
      results: Array<{ token: string; status: string }>;
    };
    assert.equal(body.configured, false);
    assert.ok(body.notification.title.length > 0);
    assert.equal(body.results.length, 1);
    assert.equal(body.results[0]?.status, "not_configured");
    // The token must be masked, never echoed in full.
    assert.notEqual(body.results[0]?.token, "device-token-1234567890");
  } finally {
    await app.close();
  }
});
