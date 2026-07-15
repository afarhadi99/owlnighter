import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../app.js";
import { fakeDeps, fakeSettings, tableRows } from "../test/helpers.js";

const ADMIN_ACCOUNT_ID = "90000000-0000-4000-8000-000000000002";
const ADMIN_BEARER = { authorization: "Bearer settings-test-token" } as const;

async function adminAuthTables() {
  const { schema } = await import("@owlnighter/db");
  return tableRows(
    [schema.adminSessions, [{ adminAccountId: ADMIN_ACCOUNT_ID, expiresAt: new Date(Date.now() + 86_400_000) }]],
    [schema.adminAccounts, [{ id: ADMIN_ACCOUNT_ID, email: "settings-admin@mytsi.org", isAdmin: true, status: "approved" }]],
  );
}

test("GET /v1/admin/settings requires admin_panel auth (401)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "GET", url: "/v1/admin/settings" });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("GET /v1/admin/settings masks secret values", async () => {
  const byTable = await adminAuthTables();
  const settings = fakeSettings({
    rows: [
      { key: "max_books_per_user", value: 3, isSecret: false },
      { key: "ai_provider.groq.api_key", value: "sk-real-secret-value", isSecret: true },
    ],
  });
  const app = await buildApp(fakeDeps({ byTable, settings }));
  try {
    const res = await app.inject({ method: "GET", url: "/v1/admin/settings", headers: ADMIN_BEARER });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { settings: Array<Record<string, unknown>> };
    const plain = body.settings.find((s) => s["key"] === "max_books_per_user")!;
    assert.equal(plain["value"], 3);
    const secret = body.settings.find((s) => s["key"] === "ai_provider.groq.api_key")!;
    assert.equal(secret["configured"], true);
    assert.equal(secret["value"], undefined);
    assert.ok(!JSON.stringify(secret).includes("sk-real-secret-value"));
  } finally {
    await app.close();
  }
});

test("PUT /v1/admin/settings/:key rejects an invalid value (400)", async () => {
  const byTable = await adminAuthTables();
  const app = await buildApp(fakeDeps({ byTable, settings: fakeSettings() }));
  try {
    const res = await app.inject({
      method: "PUT",
      url: "/v1/admin/settings/max_books_per_user",
      headers: ADMIN_BEARER,
      payload: { value: -1 },
    });
    assert.equal(res.statusCode, 400);
  } finally {
    await app.close();
  }
});

test("PUT /v1/admin/settings/:key rejects an unknown key (404)", async () => {
  const byTable = await adminAuthTables();
  const app = await buildApp(fakeDeps({ byTable, settings: fakeSettings() }));
  try {
    const res = await app.inject({
      method: "PUT",
      url: "/v1/admin/settings/not_a_real_key",
      headers: ADMIN_BEARER,
      payload: { value: 1 },
    });
    assert.equal(res.statusCode, 404);
  } finally {
    await app.close();
  }
});

test("PUT /v1/admin/settings/:key updates a valid value (200)", async () => {
  const byTable = await adminAuthTables();
  const app = await buildApp(fakeDeps({ byTable, settings: fakeSettings() }));
  try {
    const res = await app.inject({
      method: "PUT",
      url: "/v1/admin/settings/max_books_per_user",
      headers: ADMIN_BEARER,
      payload: { value: 5 },
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.json().key, "max_books_per_user");
  } finally {
    await app.close();
  }
});
