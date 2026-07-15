import { test } from "node:test";
import assert from "node:assert/strict";
import { z } from "zod";
import type { Env } from "@owlnighter/shared";
import { createAiRouter, preferredProvider } from "./router.js";
import type { SettingsReader, SettingsSnapshot } from "./types.js";

// Minimal Env with only what the router/adapters read.
function fakeEnv(overrides: Partial<Env> = {}): Env {
  return {
    GEMINI_API_KEY: "gk",
    GEMINI_MODEL: "gemini-3.5-flash",
    GROQ_API_KEY: "grk",
    GROQ_MODEL: "qwen-3.6-32b",
    ...overrides,
  } as Env;
}

function fakeSettings(overrides: Partial<SettingsSnapshot> = {}): SettingsReader {
  return {
    async snapshot(): Promise<SettingsSnapshot> {
      return {
        groq: { apiKey: "", model: "" },
        openrouter: { apiKey: "", model: "" },
        aiTutorApi: { apiKey: "", workflowIds: {} },
        taskOverrides: {},
        ...overrides,
      };
    },
  };
}

const Schema = z.object({ answer: z.string() });

interface FetchCall {
  url: string;
  init: RequestInit;
}

/** Swap global fetch with a scripted sequence of JSON bodies. Also records
 * every call's (url, init) so tests can assert on what was actually sent
 * (e.g. which API key ended up in the Authorization header). */
function scriptFetch(bodies: unknown[]): { restore: () => void; calls: FetchCall[] } {
  const original = globalThis.fetch;
  const calls: FetchCall[] = [];
  let i = 0;
  globalThis.fetch = (async (url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), init: init ?? {} });
    const body = bodies[Math.min(i++, bodies.length - 1)];
    return new Response(JSON.stringify(body), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
  return {
    restore: () => {
      globalThis.fetch = original;
    },
    calls,
  };
}

function groqBody(obj: unknown) {
  return { choices: [{ message: { content: JSON.stringify(obj) } }] };
}
function geminiBody(obj: unknown) {
  return { candidates: [{ content: { parts: [{ text: JSON.stringify(obj) }] } }] };
}

test("groq quiz output validates on first try", async () => {
  const { restore } = scriptFetch([groqBody({ answer: "ok" })]);
  try {
    const router = createAiRouter(fakeEnv(), fakeSettings());
    const res = await router.generateObject({
      task: "quiz_generation",
      schemaName: "Schema",
      schema: Schema,
      system: "s",
      user: "u",
    });
    assert.equal(res.provider, "groq");
    assert.equal(res.data.answer, "ok");
    assert.equal(res.attempts, 1);
  } finally {
    restore();
  }
});

test("invalid groq output retries then falls back to gemini", async () => {
  // groq bad, groq bad (retry), gemini good.
  const { restore } = scriptFetch([
    groqBody({ wrong: 1 }),
    groqBody({ wrong: 2 }),
    geminiBody({ answer: "rescued" }),
  ]);
  try {
    const router = createAiRouter(fakeEnv(), fakeSettings());
    const res = await router.generateObject({
      task: "quiz_generation",
      schemaName: "Schema",
      schema: Schema,
      system: "s",
      user: "u",
    });
    assert.equal(res.provider, "gemini");
    assert.equal(res.data.answer, "rescued");
    assert.equal(res.attempts, 3); // 2 groq tries + 1 gemini
  } finally {
    restore();
  }
});

test("grounding requirement routes straight to gemini", async () => {
  const { restore } = scriptFetch([geminiBody({ answer: "grounded" })]);
  try {
    const router = createAiRouter(fakeEnv(), fakeSettings());
    const res = await router.generateObject({
      task: "quiz_generation",
      schemaName: "Schema",
      schema: Schema,
      system: "s",
      user: "u",
      requireGrounding: true,
    });
    assert.equal(res.provider, "gemini");
  } finally {
    restore();
  }
});

test("missing groq key routes quiz to gemini", async () => {
  const { restore } = scriptFetch([geminiBody({ answer: "only-gemini" })]);
  try {
    const router = createAiRouter(fakeEnv({ GROQ_API_KEY: "" }), fakeSettings());
    const res = await router.generateObject({
      task: "quiz_generation",
      schemaName: "Schema",
      schema: Schema,
      system: "s",
      user: "u",
    });
    assert.equal(res.provider, "gemini");
  } finally {
    restore();
  }
});

test("task override routes quiz_generation to openrouter when configured", async () => {
  // OpenRouter's response shape is OpenAI-compatible, identical to Groq's fixture.
  const { restore } = scriptFetch([groqBody({ answer: "from-or" })]);
  try {
    const router = createAiRouter(
      fakeEnv({ GROQ_API_KEY: "" }),
      fakeSettings({
        openrouter: { apiKey: "or-key", model: "some/model" },
        taskOverrides: { quiz_generation: "openrouter" },
      }),
    );
    const res = await router.generateObject({
      task: "quiz_generation",
      schemaName: "Schema",
      schema: Schema,
      system: "s",
      user: "u",
    });
    assert.equal(res.provider, "openrouter");
    assert.equal(res.data.answer, "from-or");
  } finally {
    restore();
  }
});

test("admin setting for groq api key wins over the env var when both are present", async () => {
  const { restore, calls } = scriptFetch([groqBody({ answer: "ok" })]);
  try {
    const router = createAiRouter(
      fakeEnv({ GROQ_API_KEY: "env-key" }),
      fakeSettings({ groq: { apiKey: "admin-key", model: "admin-model" } }),
    );
    await router.generateObject({
      task: "quiz_generation",
      schemaName: "Schema",
      schema: Schema,
      system: "s",
      user: "u",
    });
    assert.equal(calls.length, 1);
    const headers = calls[0]!.init.headers as Record<string, string>;
    assert.equal(headers["authorization"], "Bearer admin-key");
  } finally {
    restore();
  }
});

test("preferredProvider ignores a task override for book_grounding/plan_generation", () => {
  // Direct unit test of the router's internal preferredProvider(), calling it
  // with a truthy taskOverride for a non-overridable task — bypassing
  // generateObject's own upstream `TASK_OVERRIDABLE.has(opts.task) ? ... :
  // undefined` filter entirely (that filter is what normally prevents a
  // taskOverride from ever reaching this function for these two tasks).
  // This isolates preferredProvider's OWN guard — the
  // `taskOverride && TASK_OVERRIDABLE.has(opts.task)` check — so a mutation
  // that deletes just that check (e.g. changing it to `if (taskOverride)
  // return taskOverride;`) makes this specific test fail, regardless of
  // whether the upstream filter in generateObject/generateText still exists.
  assert.equal(preferredProvider({ task: "book_grounding" }, "groq"), "gemini");
  assert.equal(preferredProvider({ task: "plan_generation" }, "openrouter"), "gemini");
});

test("task override in settings is never applied to book_grounding, even without requireGrounding set", async () => {
  const { restore } = scriptFetch([geminiBody({ answer: "grounded" })]);
  try {
    const router = createAiRouter(
      fakeEnv(),
      // The real SettingsSnapshot type only allows overrides for quiz_generation/rewrite;
      // this cast simulates a hypothetical upstream bug producing an out-of-contract
      // shape, to prove the router doesn't honor it for book_grounding.
      fakeSettings({ taskOverrides: { book_grounding: "groq" } as never }),
    );
    const res = await router.generateObject({
      task: "book_grounding",
      schemaName: "Schema",
      schema: Schema,
      system: "s",
      user: "u",
      // Deliberately NOT requireGrounding: that flag short-circuits to gemini
      // on preferredProvider's very first line, before the override logic is
      // ever reached — which would make this assertion pass for the wrong
      // reason (that's exactly the confound the previous version of this
      // test had).
    });
    assert.equal(res.provider, "gemini");
    // attempts === 1 proves gemini was the PRIMARY (first-tried) provider —
    // not reached via a groq-fails-then-falls-back-to-gemini path, which
    // would *also* end in "gemini" even if preferredProvider's switch-case
    // had a bug that mistakenly routed book_grounding to groq.
    assert.equal(res.attempts, 1);
  } finally {
    restore();
  }
});
