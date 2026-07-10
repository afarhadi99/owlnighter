import { test } from "node:test";
import assert from "node:assert/strict";
import { createLogger, loadEnv, resolveFlags } from "@owlnighter/shared";
import { ensureTtsAsset } from "@owlnighter/jobs";
import type { Db } from "@owlnighter/db";
import { buildApp } from "./app.js";
import type { AiRouter, Deps } from "./deps.js";

type Rows = Record<string, unknown>[];

// Same tiny Drizzle stand-in used by app.test.ts: builder methods return the
// chain; awaiting resolves to the rows registered for the table in `.from()`.
function fakeDb(byTable: Map<unknown, Rows>): Db {
  const makeChain = () => {
    let table: unknown;
    const chain = {
      from(t: unknown) {
        table = t;
        return chain;
      },
      where: () => chain,
      innerJoin: () => chain,
      orderBy: () => chain,
      limit: () => chain,
      groupBy: () => chain,
      values: () => chain,
      set: () => chain,
      returning: () => chain,
      then: (onF: (rows: Rows) => unknown, onR: (err: unknown) => unknown) =>
        Promise.resolve(byTable.get(table) ?? []).then(onF, onR),
    };
    return chain;
  };
  const db = {
    select: () => makeChain(),
    insert: (t: unknown) => makeChain().from(t),
    update: (t: unknown) => makeChain().from(t),
    delete: (t: unknown) => makeChain().from(t),
  };
  return db as unknown as Db;
}

function fakeDeps(byTable: Map<unknown, Rows> = new Map()): Deps {
  return {
    config: {
      env: { ...loadEnv(), NODE_ENV: "development" },
      flags: resolveFlags(),
      logger: createLogger("fatal"),
    },
    db: fakeDb(byTable),
    ai: {} as unknown as AiRouter,
    supabase: undefined,
    ensureTtsAsset,
  } as Deps;
}

const PLAN_ID = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
const USER_ID = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";
const BOOK_ID = "cccccccc-cccc-cccc-cccc-cccccccccccc";

test("GET /v1/admin/plans returns plans with derived step counts for an admin", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = new Map<unknown, Rows>([
    [schema.profiles, [{ isAdmin: true }]], // dev user resolves as admin
    [
      schema.readingPlans,
      [
        {
          id: PLAN_ID,
          userId: USER_ID,
          bookId: BOOK_ID,
          provider: "gemini",
          providerModel: "gemini-3.5-flash",
          planVersion: 1,
          pacingMode: "standard",
          nightlyGoalPages: 10,
          startsOn: "2026-07-01",
          createdAt: new Date("2026-07-01T00:00:00.000Z"),
        },
      ],
    ],
    [schema.readingPlanSteps, [{ planId: PLAN_ID, value: 7 }]],
  ]);
  const app = await buildApp(fakeDeps(byTable));
  try {
    const res = await app.inject({
      method: "GET",
      url: "/v1/admin/plans",
      headers: { authorization: "Bearer DEV" },
    });
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

test("GET /v1/admin/plans is forbidden for a non-admin user (403)", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = new Map<unknown, Rows>([[schema.profiles, [{ isAdmin: false }]]]);
  const app = await buildApp(fakeDeps(byTable));
  try {
    const res = await app.inject({
      method: "GET",
      url: "/v1/admin/plans",
      headers: { authorization: "Bearer DEV" },
    });
    assert.equal(res.statusCode, 403);
  } finally {
    await app.close();
  }
});
