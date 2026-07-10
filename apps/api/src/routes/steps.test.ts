import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../app.js";
import { DEV_BEARER, DEV_USER_ID, fakeDeps, tableRows } from "../test/helpers.js";

const STEP_ID = "dddddddd-dddd-4ddd-8ddd-dddddddddddd";
const SESSION_ID = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee";

test("POST /v1/steps/:id/start reuses an already-open session", async () => {
  const { schema } = await import("@owlnighter/db");
  const started = new Date("2026-07-09T20:00:00.000Z");
  const byTable = tableRows(
    [schema.profiles, []],
    // The step+plan join projects { stepId, ownerId }.
    [schema.readingPlanSteps, [{ stepId: STEP_ID, ownerId: DEV_USER_ID }]],
    [schema.readingSessions, [{ id: SESSION_ID, startedAt: started, completedAt: null }]],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "POST", url: `/v1/steps/${STEP_ID}/start`, headers: DEV_BEARER });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { sessionId: string; stepId: string; startedAt: string };
    assert.equal(body.sessionId, SESSION_ID);
    assert.equal(body.stepId, STEP_ID);
    assert.equal(body.startedAt, started.toISOString());
  } finally {
    await app.close();
  }
});

test("POST /v1/steps/:id/start is 404 for a step owned by another user", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows(
    [schema.profiles, []],
    [schema.readingPlanSteps, [{ stepId: STEP_ID, ownerId: "77777777-7777-4777-8777-777777777777" }]],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "POST", url: `/v1/steps/${STEP_ID}/start`, headers: DEV_BEARER });
    assert.equal(res.statusCode, 404);
  } finally {
    await app.close();
  }
});

test("POST /v1/steps/:id/start is 404 when the step does not exist", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows([schema.profiles, []], [schema.readingPlanSteps, []]);
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "POST", url: `/v1/steps/${STEP_ID}/start`, headers: DEV_BEARER });
    assert.equal(res.statusCode, 404);
  } finally {
    await app.close();
  }
});

test("POST /v1/steps/:id/start requires auth (401)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "POST", url: `/v1/steps/${STEP_ID}/start` });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});
