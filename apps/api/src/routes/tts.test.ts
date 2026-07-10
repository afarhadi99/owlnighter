import { test } from "node:test";
import assert from "node:assert/strict";
import type { ensureTtsAsset as EnsureTtsAsset } from "@owlnighter/jobs";
import { buildApp } from "../app.js";
import { DEV_BEARER, fakeDeps, tableRows } from "../test/helpers.js";

const ASSET_ID = "abababab-abab-4bab-8bab-abababababab";

test("POST /v1/tts/generate returns the asset when Deepgram + Supabase are configured", async () => {
  const { schema } = await import("@owlnighter/db");
  // Stub the jobs seam so no Deepgram call / upload happens.
  const stubEnsure = (async () => ({
    status: "created",
    asset: { id: ASSET_ID, assetKey: "key-1", provider: "deepgram", voiceModel: "aura-2-thalia-en", locale: "en", storagePath: "tts/key-1.mp3", durationMs: 4200 },
  })) as unknown as typeof EnsureTtsAsset;

  const app = await buildApp(
    fakeDeps({
      byTable: tableRows([schema.profiles, []]),
      env: { DEEPGRAM_API_KEY: "dg-key" },
      supabase: {}, // truthy stands in for a configured client
      ensureTtsAsset: stubEnsure,
    }),
  );
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/tts/generate",
      headers: DEV_BEARER,
      payload: { text: "Good night, reader." },
    });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { assetId: string; assetKey: string; cached: boolean; durationMs?: number };
    assert.equal(body.assetId, ASSET_ID);
    assert.equal(body.assetKey, "key-1");
    assert.equal(body.cached, false); // status 'created' → not a cache hit
    assert.equal(body.durationMs, 4200);
  } finally {
    await app.close();
  }
});

test("POST /v1/tts/generate is 503 when DEEPGRAM_API_KEY is unset", async () => {
  const { schema } = await import("@owlnighter/db");
  const app = await buildApp(fakeDeps({ byTable: tableRows([schema.profiles, []]), env: { DEEPGRAM_API_KEY: "" } }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/tts/generate",
      headers: DEV_BEARER,
      payload: { text: "hello" },
    });
    assert.equal(res.statusCode, 503);
    assert.equal(res.json().error.code, "service_unavailable");
  } finally {
    await app.close();
  }
});

test("POST /v1/tts/generate requires auth (401)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "POST", url: "/v1/tts/generate", payload: { text: "hi" } });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});
