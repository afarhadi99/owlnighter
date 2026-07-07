import { test } from "node:test";
import assert from "node:assert/strict";
import { z } from "zod";
import type { Env } from "@owlnighter/shared";
import { createAiRouter } from "./router.js";

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

const Schema = z.object({ answer: z.string() });

/** Swap global fetch with a scripted sequence of JSON bodies. */
function scriptFetch(bodies: unknown[]): () => void {
  const original = globalThis.fetch;
  let i = 0;
  globalThis.fetch = (async () => {
    const body = bodies[Math.min(i++, bodies.length - 1)];
    return new Response(JSON.stringify(body), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
  return () => {
    globalThis.fetch = original;
  };
}

function groqBody(obj: unknown) {
  return { choices: [{ message: { content: JSON.stringify(obj) } }] };
}
function geminiBody(obj: unknown) {
  return { candidates: [{ content: { parts: [{ text: JSON.stringify(obj) }] } }] };
}

test("groq quiz output validates on first try", async () => {
  const restore = scriptFetch([groqBody({ answer: "ok" })]);
  try {
    const router = createAiRouter(fakeEnv());
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
  const restore = scriptFetch([
    groqBody({ wrong: 1 }),
    groqBody({ wrong: 2 }),
    geminiBody({ answer: "rescued" }),
  ]);
  try {
    const router = createAiRouter(fakeEnv());
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
  const restore = scriptFetch([geminiBody({ answer: "grounded" })]);
  try {
    const router = createAiRouter(fakeEnv());
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
  const restore = scriptFetch([geminiBody({ answer: "only-gemini" })]);
  try {
    const router = createAiRouter(fakeEnv({ GROQ_API_KEY: "" }));
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
