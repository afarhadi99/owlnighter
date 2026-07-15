import { test } from "node:test";
import assert from "node:assert/strict";
import { getAiModels } from "./ai-models.js";
import { fakeDeps, fakeSettings } from "../test/helpers.js";

function scriptFetch(body: unknown, status = 200): () => void {
  const original = globalThis.fetch;
  globalThis.fetch = (async () =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } })) as typeof fetch;
  return () => {
    globalThis.fetch = original;
  };
}

test("rejects an unknown provider", async () => {
  await assert.rejects(() => getAiModels(fakeDeps(), "not-a-provider"));
});

test("fetches and normalizes Groq models, sorted by id", async () => {
  const restore = scriptFetch({
    data: [
      { id: "z-model", context_window: 8192 },
      { id: "a-model", context_window: 4096 },
    ],
  });
  try {
    const deps = fakeDeps({ settings: fakeSettings({ rows: [{ key: "ai_provider.groq.api_key", value: "gk" }] }) });
    const result = await getAiModels(deps, "groq");
    assert.equal(result.provider, "groq");
    assert.equal(result.models.length, 2);
    assert.equal(result.models[0]?.id, "a-model");
  } finally {
    restore();
  }
});

test("groq catalog is unavailable with no key configured", async () => {
  const deps = fakeDeps({ env: { GROQ_API_KEY: "" }, settings: fakeSettings() });
  await assert.rejects(() => getAiModels(deps, "groq"));
});

test("fetches and normalizes OpenRouter models", async () => {
  const restore = scriptFetch({
    data: [
      {
        id: "vendor/model-1",
        name: "Model One",
        context_length: 128000,
        pricing: { prompt: "0.001", completion: "0.002" },
        architecture: { modality: "text->text" },
      },
    ],
  });
  try {
    const result = await getAiModels(fakeDeps(), "openrouter");
    assert.equal(result.provider, "openrouter");
    assert.equal(result.models[0]?.name, "Model One");
    assert.equal(result.models[0]?.modality, "text->text");
  } finally {
    restore();
  }
});
