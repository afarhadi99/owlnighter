import { createLogger, loadEnv, resolveFlags } from "@owlnighter/shared";
import { ensureTtsAsset } from "@owlnighter/jobs";
import type { Db } from "@owlnighter/db";
import type { AiRouter, Deps, GenerateObjectResult } from "../deps.js";

/**
 * Shared test rig for the route-level `app.inject` suites. Everything here is a
 * fake — no live Postgres, no AI provider, no network. Keeping it in one place
 * means the per-route suites stay short and consistent.
 */

export type Rows = Record<string, unknown>[];

/** Fixed dev user id the DEV bearer resolves to (mirrors config.ts). */
export const DEV_USER_ID = "00000000-0000-4000-8000-0000000000de";
export const DEV_BEARER = { authorization: "Bearer DEV" } as const;

/**
 * A tiny Drizzle stand-in: every builder method returns the same chain, and
 * awaiting it resolves to the rows registered for the table passed to `.from()`
 * (which `insert`/`update`/`delete` also route through). This is intentionally
 * simple — it cannot model a real join, so a suite registers the already-joined
 * row shape under the driving (`.from`) table. Enough to exercise route wiring,
 * auth, validation, and response mapping without a database.
 */
export function fakeDb(byTable: Map<unknown, Rows> = new Map(), executeResults: unknown[][] = []): Db {
  const makeChain = () => {
    let table: unknown;
    const chain = {
      from(t: unknown) {
        table = t;
        return chain;
      },
      where: () => chain,
      innerJoin: () => chain,
      leftJoin: () => chain,
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
    execute: async () => executeResults.shift() ?? [],
  };
  return db as unknown as Db;
}

export interface FakeDepsOptions {
  /** Rows keyed by drizzle table object; consulted on `.from(table)`. */
  byTable?: Map<unknown, Rows>;
  /** Partial AI router; unspecified methods throw if called. */
  ai?: Partial<AiRouter>;
  /** Env overrides merged over loadEnv() (e.g. blank a provider key). */
  env?: Record<string, unknown>;
  /** Truthy value stands in for a configured Supabase client. */
  supabase?: unknown;
  /** Override the TTS job seam (default: the real, side-effect-free export). */
  ensureTtsAsset?: typeof ensureTtsAsset;
  /** Canned results for deps.db.execute(), consumed in call order (pgcrypto hash/verify). */
  executeResults?: unknown[][];
}

/** Assemble a Deps object good enough for `buildApp`. Dev bearer auth requires
 * NODE_ENV==='development', which we force here. */
export function fakeDeps(opts: FakeDepsOptions = {}): Deps {
  return {
    config: {
      env: { ...loadEnv(), NODE_ENV: "development", ...(opts.env ?? {}) },
      flags: resolveFlags(),
      logger: createLogger("fatal"),
    },
    db: fakeDb(opts.byTable, opts.executeResults ?? []),
    ai: (opts.ai ?? {}) as AiRouter,
    supabase: opts.supabase as Deps["supabase"],
    ensureTtsAsset: opts.ensureTtsAsset ?? ensureTtsAsset,
  } as Deps;
}

/** An AiRouter whose generateObject always returns `data` (no provider call).
 * `data` is cast to the caller's expected schema type — tests own its shape. */
export function fakeAi(data: unknown, extra: Record<string, unknown> = {}): AiRouter {
  return {
    async generateObject<T>() {
      return {
        data: data as T,
        provider: "gemini",
        model: "gemini-test",
        citations: [],
        attempts: 1,
        ...extra,
      } as GenerateObjectResult<T>;
    },
    async generateText() {
      return { text: "", provider: "gemini" as const, model: "gemini-test" };
    },
  };
}

/** Convenience: a Map of table→rows from tuples. */
export function tableRows(...entries: Array<[unknown, Rows]>): Map<unknown, Rows> {
  return new Map(entries);
}
