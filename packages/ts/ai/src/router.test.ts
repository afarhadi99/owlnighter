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
 * (e.g. which API key ended up in the Authorization header, or which
 * provider endpoint was hit). */
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
// AI Tutor API run endpoint returns a JSON-string `result` (the documented contract).
function aiTutorBody(obj: unknown) {
  return { success: true, result: JSON.stringify(obj) };
}

// ---- preferredProvider: pure resolution (override wins, else default, else fallback) ----

test("preferredProvider: a task_override is now honored for ANY task, including book_grounding/plan_generation", () => {
  // The old lock forced these two tasks to gemini regardless of the override.
  // That guarantee is intentionally removed — the override must win now.
  assert.equal(
    preferredProvider("book_grounding", { taskOverrides: { book_grounding: "groq" }, default: "ai_tutor_api" }),
    "groq",
  );
  assert.equal(
    preferredProvider("plan_generation", { taskOverrides: { plan_generation: "openrouter" }, default: "ai_tutor_api" }),
    "openrouter",
  );
});

test("preferredProvider: with no override, the task routes to the global default", () => {
  assert.equal(preferredProvider("book_grounding", { taskOverrides: {}, default: "ai_tutor_api" }), "ai_tutor_api");
  assert.equal(preferredProvider("quiz_generation", { taskOverrides: {}, default: "gemini" }), "gemini");
});

test("preferredProvider: falls back to ai_tutor_api when no default is configured", () => {
  assert.equal(preferredProvider("plan_generation", { taskOverrides: {} }), "ai_tutor_api");
});

// ---- routing through the full router ----

test("with default=ai_tutor_api and a configured grounding workflow_id, book_grounding routes to ai_tutor_api", async () => {
  const { restore, calls } = scriptFetch([aiTutorBody({ answer: "grounded-via-tutor" })]);
  try {
    const router = createAiRouter(
      fakeEnv(),
      fakeSettings({
        default: "ai_tutor_api",
        aiTutorApi: { apiKey: "tutor-key", workflowIds: { book_grounding: "wf_bg" } },
      }),
    );
    const res = await router.generateObject({
      task: "book_grounding",
      schemaName: "Schema",
      schema: Schema,
      system: "s",
      user: "u",
      requireGrounding: true, // no longer forces gemini
    });
    assert.equal(res.provider, "ai_tutor_api");
    assert.equal(res.data.answer, "grounded-via-tutor");
    assert.equal(res.attempts, 1);
    // Confirm the AI Tutor run endpoint (with the configured workflow id) was hit.
    assert.match(calls[0]!.url, /\/api\/v1\/run\/wf_bg$/);
  } finally {
    restore();
  }
});

test("SAFETY: default=ai_tutor_api but NO workflow_id for book_grounding falls back to Gemini", async () => {
  // Proves grounding keeps working during setup: ai_tutor_api is the default,
  // but with no workflow_id it cannot serve the task, so the router degrades to
  // Gemini (attempts === 1 proves Gemini was tried directly, not after a failed
  // ai_tutor_api call).
  const { restore, calls } = scriptFetch([geminiBody({ answer: "rescued-by-gemini" })]);
  try {
    const router = createAiRouter(
      fakeEnv(),
      fakeSettings({
        default: "ai_tutor_api",
        aiTutorApi: { apiKey: "tutor-key", workflowIds: {} }, // key present, but no workflow for the task
      }),
    );
    const res = await router.generateObject({
      task: "book_grounding",
      schemaName: "Schema",
      schema: Schema,
      system: "s",
      user: "u",
      requireGrounding: true,
    });
    assert.equal(res.provider, "gemini");
    assert.equal(res.data.answer, "rescued-by-gemini");
    assert.equal(res.attempts, 1);
    // Only Gemini was ever contacted — no doomed AI Tutor call was attempted.
    assert.equal(calls.length, 1);
    assert.match(calls[0]!.url, /generativelanguage\.googleapis\.com/);
  } finally {
    restore();
  }
});

test("grounding requirement no longer forces gemini — it runs on the resolved provider", async () => {
  // book_grounding overridden to groq; requireGrounding is set but must NOT
  // re-route to gemini anymore.
  const { restore } = scriptFetch([groqBody({ answer: "grounded-on-groq" })]);
  try {
    const router = createAiRouter(
      fakeEnv(),
      fakeSettings({ default: "ai_tutor_api", taskOverrides: { book_grounding: "groq" } }),
    );
    const res = await router.generateObject({
      task: "book_grounding",
      schemaName: "Schema",
      schema: Schema,
      system: "s",
      user: "u",
      requireGrounding: true,
    });
    assert.equal(res.provider, "groq");
    assert.equal(res.data.answer, "grounded-on-groq");
  } finally {
    restore();
  }
});

test("a task_override to ai_tutor_api routes quiz_generation there", async () => {
  const { restore } = scriptFetch([aiTutorBody({ answer: "quiz-via-tutor" })]);
  try {
    const router = createAiRouter(
      fakeEnv(),
      fakeSettings({
        default: "gemini",
        aiTutorApi: { apiKey: "tutor-key", workflowIds: { quiz_generation: "wf_quiz" } },
        taskOverrides: { quiz_generation: "ai_tutor_api" },
      }),
    );
    const res = await router.generateObject({
      task: "quiz_generation",
      schemaName: "Schema",
      schema: Schema,
      system: "s",
      user: "u",
    });
    assert.equal(res.provider, "ai_tutor_api");
    assert.equal(res.data.answer, "quiz-via-tutor");
  } finally {
    restore();
  }
});

test("invalid preferred-provider output retries then falls back to gemini", async () => {
  // groq is the resolved provider (override); it returns bad twice (retry), then
  // gemini rescues. Confirms validate-and-retry + one fallback still hold.
  const { restore } = scriptFetch([
    groqBody({ wrong: 1 }),
    groqBody({ wrong: 2 }),
    geminiBody({ answer: "rescued" }),
  ]);
  try {
    const router = createAiRouter(
      fakeEnv(),
      fakeSettings({ default: "ai_tutor_api", taskOverrides: { quiz_generation: "groq" } }),
    );
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

test("admin setting for groq api key wins over the env var when both are present", async () => {
  const { restore, calls } = scriptFetch([groqBody({ answer: "ok" })]);
  try {
    const router = createAiRouter(
      fakeEnv({ GROQ_API_KEY: "env-key" }),
      fakeSettings({
        default: "ai_tutor_api",
        groq: { apiKey: "admin-key", model: "admin-model" },
        taskOverrides: { quiz_generation: "groq" },
      }),
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

test("missing preferred-provider key skips it and uses the next configured provider", async () => {
  // quiz overridden to groq, but groq has no key anywhere → skipped, gemini serves.
  const { restore } = scriptFetch([geminiBody({ answer: "only-gemini" })]);
  try {
    const router = createAiRouter(
      fakeEnv({ GROQ_API_KEY: "" }),
      fakeSettings({ default: "ai_tutor_api", taskOverrides: { quiz_generation: "groq" } }),
    );
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

test("throws a clear error when no provider is configured for the task", async () => {
  const { restore } = scriptFetch([geminiBody({ answer: "unused" })]);
  try {
    // No provider is usable: no gemini/groq env keys, ai_tutor_api has no key,
    // openrouter unset.
    const router = createAiRouter(
      fakeEnv({ GEMINI_API_KEY: "", GROQ_API_KEY: "" }),
      fakeSettings({ default: "ai_tutor_api" }),
    );
    await assert.rejects(
      router.generateObject({
        task: "book_grounding",
        schemaName: "Schema",
        schema: Schema,
        system: "s",
        user: "u",
      }),
      /No AI provider is configured/,
    );
  } finally {
    restore();
  }
});
