import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../app.js";
import { DEV_BEARER, fakeDeps, tableRows } from "../test/helpers.js";

test("POST /v1/push/register returns 204 (no content) on success", async () => {
  const { schema } = await import("@owlnighter/db");
  // No existing token row → the insert branch runs; the fake insert is a no-op.
  const byTable = tableRows([schema.profiles, []], [schema.pushTokens, []]);
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/push/register",
      headers: DEV_BEARER,
      payload: { token: "device-token-abc", platform: "android", appVersion: "1.0.0" },
    });
    assert.equal(res.statusCode, 204);
    assert.equal(res.body, "");
  } finally {
    await app.close();
  }
});

test("POST /v1/push/register requires auth (401)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/push/register",
      payload: { token: "t", platform: "ios" },
    });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("POST /v1/push/register rejects an invalid platform (400)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/push/register",
      headers: DEV_BEARER,
      payload: { token: "t", platform: "blackberry" },
    });
    assert.equal(res.statusCode, 400);
  } finally {
    await app.close();
  }
});
