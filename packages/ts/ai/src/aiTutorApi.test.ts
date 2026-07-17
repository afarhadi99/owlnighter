import { test } from "node:test";
import assert from "node:assert/strict";
import { AiTutorApiAdapter } from "./aiTutorApi.js";
import type { GenerateObjectOptions, GenerateTextOptions } from "./types.js";

/** A captured outgoing request: the URL and the parsed JSON request body. */
type FetchCall = { url: string; body: Record<string, unknown> | undefined };
/** The restore function, with the captured calls hung off it so tests can
 * assert exactly what the adapter sent without a second helper. */
type Restore = (() => void) & { calls: FetchCall[] };

function scriptFetch(body: unknown, status = 200): Restore {
  const original = globalThis.fetch;
  const calls: FetchCall[] = [];
  globalThis.fetch = (async (input: unknown, init?: { body?: unknown }) => {
    const raw = init?.body;
    calls.push({
      url: String(input),
      body: typeof raw === "string" ? (JSON.parse(raw) as Record<string, unknown>) : undefined,
    });
    return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
  }) as typeof fetch;
  const restore = (() => {
    globalThis.fetch = original;
  }) as Restore;
  restore.calls = calls;
  return restore;
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
const baseTextOpts = { system: "sys", user: "usr" };

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

test("generateObjectRaw sends the variables map verbatim as the request body when provided", async () => {
  const restore = scriptFetch({ success: true, result: JSON.stringify({ answer: "ok" }) });
  try {
    const adapter = new AiTutorApiAdapter({ apiKey: "k", workflowIds: { quiz_generation: "wf_123" } });
    const variables = {
      stepTitle: "Chapter 1",
      chapterHint: "Ch. 1",
      pageRange: "1-10",
      quizMode: "grounded",
      questionCount: "3",
      readerContext: "",
    };
    await adapter.generateObjectRaw({ task: "quiz_generation", ...baseOpts, variables } as GenerateObjectOptions<unknown>);
    assert.equal(restore.calls.length, 1);
    const sent = restore.calls[0]!.body!;
    // The body IS the variable map — and carries neither the system nor user key.
    assert.deepEqual(sent, variables);
    assert.ok(!("system" in sent), "variable-map body must not contain a system key");
    assert.ok(!("user" in sent), "variable-map body must not contain a user key");
  } finally {
    restore();
  }
});

test("generateObjectRaw falls back to {system,user} body when variables are absent", async () => {
  const restore = scriptFetch({ success: true, result: JSON.stringify({ answer: "ok" }) });
  try {
    const adapter = new AiTutorApiAdapter({ apiKey: "k", workflowIds: { quiz_generation: "wf_123" } });
    await adapter.generateObjectRaw({ task: "quiz_generation", ...baseOpts } as GenerateObjectOptions<unknown>);
    assert.deepEqual(restore.calls[0]!.body, { system: "sys", user: "usr" });
  } finally {
    restore();
  }
});

test("generateObjectRaw falls back to {system,user} body when variables is an empty map", async () => {
  const restore = scriptFetch({ success: true, result: JSON.stringify({ answer: "ok" }) });
  try {
    const adapter = new AiTutorApiAdapter({ apiKey: "k", workflowIds: { quiz_generation: "wf_123" } });
    await adapter.generateObjectRaw({ task: "quiz_generation", ...baseOpts, variables: {} } as GenerateObjectOptions<unknown>);
    assert.deepEqual(restore.calls[0]!.body, { system: "sys", user: "usr" });
  } finally {
    restore();
  }
});

test("generateText falls back to {system,user} body when variables are absent (rewrite path)", async () => {
  const restore = scriptFetch({ success: true, result: JSON.stringify("done") });
  try {
    const adapter = new AiTutorApiAdapter({ apiKey: "k", workflowIds: { rewrite: "wf_456" } });
    await adapter.generateText({ task: "rewrite", ...baseTextOpts } as GenerateTextOptions);
    assert.deepEqual(restore.calls[0]!.body, { system: "sys", user: "usr" });
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

test("generateText unwraps a JSON-encoded string result", async () => {
  const restore = scriptFetch({
    success: true,
    result: JSON.stringify("Here is the rewritten paragraph."),
  });
  try {
    const adapter = new AiTutorApiAdapter({ apiKey: "k", workflowIds: { rewrite: "wf_456" } });
    const { text } = await adapter.generateText({ task: "rewrite", ...baseTextOpts } as GenerateTextOptions);
    assert.equal(text, "Here is the rewritten paragraph.");
  } finally {
    restore();
  }
});

test("generateText falls back to the raw string when result isn't valid JSON", async () => {
  const restore = scriptFetch({
    success: true,
    result: "plain text that is not JSON",
  });
  try {
    const adapter = new AiTutorApiAdapter({ apiKey: "k", workflowIds: { rewrite: "wf_456" } });
    const { text } = await adapter.generateText({ task: "rewrite", ...baseTextOpts } as GenerateTextOptions);
    assert.equal(text, "plain text that is not JSON");
  } finally {
    restore();
  }
});

test("a citation with neither title nor url falls back to a generic placeholder", async () => {
  const restore = scriptFetch({
    success: true,
    result: JSON.stringify({ answer: "ok" }),
    citations: [{}],
  });
  try {
    const adapter = new AiTutorApiAdapter({ apiKey: "k", workflowIds: { quiz_generation: "wf_123" } });
    const { citations } = await adapter.generateObjectRaw({
      task: "quiz_generation",
      ...baseOpts,
    } as GenerateObjectOptions<unknown>);
    assert.deepEqual(citations, [
      { title: "source", url: "", reason: "Cited by AI Tutor API web search." },
    ]);
  } finally {
    restore();
  }
});
