import { test } from "node:test";
import assert from "node:assert/strict";
import { createLogger, loadEnv, resolveFlags } from "@owlnighter/shared";
import { ensureTtsAsset } from "@owlnighter/jobs";
import type { Db } from "@owlnighter/db";
import { buildApp } from "./app.js";
import type { AiRouter, Deps } from "./deps.js";

type Rows = Record<string, unknown>[];

/**
 * A tiny Drizzle stand-in: every builder method returns the same chain, and
 * awaiting it resolves to the rows registered for the table passed to `.from()`.
 * Enough to exercise route wiring without a live Postgres.
 */
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
      // Dev bearer auth requires NODE_ENV==='development'.
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

test("GET /healthz returns ok with injected deps", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "GET", url: "/healthz" });
    assert.equal(res.statusCode, 200);
    assert.equal(res.json().status, "ok");
  } finally {
    await app.close();
  }
});

test("GET /v1/library/books requires auth (401 without a bearer)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "GET", url: "/v1/library/books" });
    assert.equal(res.statusCode, 401);
    assert.equal(res.json().error.code, "unauthorized");
  } finally {
    await app.close();
  }
});

test("GET /v1/library/books returns the user's books with a dev bearer", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = new Map<unknown, Rows>([
    [schema.profiles, []], // isAdmin lookup → not an admin
    [
      schema.userBooks,
      [
        {
          id: "11111111-1111-1111-1111-111111111111",
          bookId: "22222222-2222-2222-2222-222222222222",
          status: "active",
          currentPage: 42,
          targetNightlyPages: 10,
          createdAt: new Date(),
        },
      ],
    ],
  ]);
  const app = await buildApp(fakeDeps(byTable));
  try {
    const res = await app.inject({
      method: "GET",
      url: "/v1/library/books",
      headers: { authorization: "Bearer DEV" },
    });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { books: Array<{ bookId: string; currentPage?: number }> };
    assert.equal(body.books.length, 1);
    assert.equal(body.books[0]?.bookId, "22222222-2222-2222-2222-222222222222");
    assert.equal(body.books[0]?.currentPage, 42);
  } finally {
    await app.close();
  }
});
