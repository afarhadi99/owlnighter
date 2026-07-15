import { test } from "node:test";
import assert from "node:assert/strict";
import { AiTutorApiAdapter } from "./aiTutorApi.js";
import type { GenerateObjectOptions } from "./types.js";

function scriptFetch(body: unknown, status = 200): () => void {
  const original = globalThis.fetch;
  globalThis.fetch = (async () =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } })) as typeof fetch;
  return () => {
    globalThis.fetch = original;
  };
}

/** Variant of scriptFetch that returns a raw (non-JSON) text body, for
 * exercising the non-ok error path where upstream returns plain text. */
function scriptFetchText(text: string, status: number): () => void {
  const original = globalThis.fetch;
  globalThis.fetch = (async () => new Response(text, { status })) as typeof fetch;
  return () => {
    globalThis.fetch = original;
  };
}

const baseOpts = { schemaName: "s", schema: undefined as never, system: "sys", user: "usr" };

test("throws when no workflow_id is configured for the task", async () => {
  const adapter = new AiTutorApiAdapter({ apiKey: "k", workflowIds: {} });
  await assert.rejects(
    () => adapter.generateObjectRaw({ task: "quiz_generation", ...baseOpts } as GenerateObjectOptions<unknown>),
    /no workflow_id configured/i,
  );
});

test("generateObjectRaw parses the JSON-string result and maps citations", async () => {
  const restore = scriptFetch({
    success: true,
    result: JSON.stringify({ answer: "ok" }),
    citations: [{ title: "Source A", url: "https://example.com/a" }],
  });
  try {
    const adapter = new AiTutorApiAdapter({ apiKey: "k", workflowIds: { quiz_generation: "wf_123" } });
    const { raw, citations, model } = await adapter.generateObjectRaw({
      task: "quiz_generation",
      ...baseOpts,
    } as GenerateObjectOptions<unknown>);
    assert.deepEqual(raw, { answer: "ok" });
    assert.equal(citations.length, 1);
    assert.equal(citations[0]?.url, "https://example.com/a");
    assert.equal(model, "ai_tutor_api:wf_123");
  } finally {
    restore();
  }
});

test("throws when the API reports success: false", async () => {
  const restore = scriptFetch({ success: false, result: "" });
  try {
    const adapter = new AiTutorApiAdapter({ apiKey: "k", workflowIds: { quiz_generation: "wf_123" } });
    await assert.rejects(() =>
      adapter.generateObjectRaw({ task: "quiz_generation", ...baseOpts } as GenerateObjectOptions<unknown>),
    );
  } finally {
    restore();
  }
});

test("redacts the API key out of a thrown error message on a non-ok response", async () => {
  const restore = scriptFetchText("invalid credentials for key: secret-key-123", 401);
  try {
    const adapter = new AiTutorApiAdapter({ apiKey: "secret-key-123", workflowIds: { quiz_generation: "wf_123" } });
    await assert.rejects(
      () => adapter.generateObjectRaw({ task: "quiz_generation", ...baseOpts } as GenerateObjectOptions<unknown>),
      (err: unknown) => {
        assert.ok(err instanceof Error);
        assert.ok(!err.message.includes("secret-key-123"), `error message leaked the API key: ${err.message}`);
        assert.ok(err.message.includes("[redacted]"), `error message missing redaction marker: ${err.message}`);
        return true;
      },
    );
  } finally {
    restore();
  }
});
