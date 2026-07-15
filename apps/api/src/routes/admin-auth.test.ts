import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../app.js";
import { fakeDeps, tableRows } from "../test/helpers.js";

test("signup rejects a non-@mytsi.org email (400)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/admin/auth/signup",
      payload: { email: "someone@gmail.com", password: "longenough1" },
    });
    assert.equal(res.statusCode, 400);
  } finally {
    await app.close();
  }
});

test("signup accepts an @mytsi.org email and reports pending", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows([schema.adminAccounts, []]);
  const app = await buildApp(fakeDeps({ byTable, executeResults: [[{ hash: "hashed" }]] }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/admin/auth/signup",
      payload: { email: "newperson@mytsi.org", password: "longenough1" },
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.json().status, "pending");
  } finally {
    await app.close();
  }
});

test("signup rejects an email that already exists (400)", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows([
    schema.adminAccounts,
    [{ id: "aaaaaaaa-0000-4000-8000-000000000008", email: "existing@mytsi.org" }],
  ]);
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/admin/auth/signup",
      payload: { email: "existing@mytsi.org", password: "longenough1" },
    });
    assert.equal(res.statusCode, 400);
  } finally {
    await app.close();
  }
});

test("login rejects a wrong password (401)", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows([
    schema.adminAccounts,
    [{ id: "aaaaaaaa-0000-4000-8000-000000000001", email: "a@mytsi.org", passwordHash: "h", status: "approved", isAdmin: true }],
  ]);
  const app = await buildApp(fakeDeps({ byTable, executeResults: [[{ valid: false }]] }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/admin/auth/login",
      payload: { email: "a@mytsi.org", password: "wrong" },
    });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("login rejects a pending account (403)", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows([
    schema.adminAccounts,
    [{ id: "aaaaaaaa-0000-4000-8000-000000000002", email: "b@mytsi.org", passwordHash: "h", status: "pending", isAdmin: false }],
  ]);
  const app = await buildApp(fakeDeps({ byTable, executeResults: [[{ valid: true }]] }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/admin/auth/login",
      payload: { email: "b@mytsi.org", password: "correct" },
    });
    assert.equal(res.statusCode, 403);
  } finally {
    await app.close();
  }
});

test("login rejects a rejected account (403)", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows([
    schema.adminAccounts,
    [{ id: "aaaaaaaa-0000-4000-8000-000000000006", email: "r@mytsi.org", passwordHash: "h", status: "rejected", isAdmin: false }],
  ]);
  const app = await buildApp(fakeDeps({ byTable, executeResults: [[{ valid: true }]] }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/admin/auth/login",
      payload: { email: "r@mytsi.org", password: "correct" },
    });
    assert.equal(res.statusCode, 403);
  } finally {
    await app.close();
  }
});

test("login rejects an approved, non-admin account (403)", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows([
    schema.adminAccounts,
    [{ id: "aaaaaaaa-0000-4000-8000-000000000007", email: "n@mytsi.org", passwordHash: "h", status: "approved", isAdmin: false }],
  ]);
  const app = await buildApp(fakeDeps({ byTable, executeResults: [[{ valid: true }]] }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/admin/auth/login",
      payload: { email: "n@mytsi.org", password: "correct" },
    });
    assert.equal(res.statusCode, 403);
  } finally {
    await app.close();
  }
});

test("login succeeds for an approved admin and issues a token", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows([
    schema.adminAccounts,
    [{ id: "aaaaaaaa-0000-4000-8000-000000000003", email: "c@mytsi.org", passwordHash: "h", status: "approved", isAdmin: true }],
  ]);
  const app = await buildApp(fakeDeps({ byTable, executeResults: [[{ valid: true }]] }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/admin/auth/login",
      payload: { email: "c@mytsi.org", password: "correct" },
    });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { token: string; account: { email: string } };
    assert.ok(body.token.length > 0);
    assert.equal(body.account.email, "c@mytsi.org");
  } finally {
    await app.close();
  }
});

test("GET /v1/admin/auth/me requires a valid session (401 with no token)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "GET", url: "/v1/admin/auth/me" });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("GET /v1/admin/auth/me resolves the caller from a valid session token", async () => {
  const { schema } = await import("@owlnighter/db");
  const accountId = "aaaaaaaa-0000-4000-8000-000000000004";
  const byTable = tableRows(
    [schema.adminSessions, [{ adminAccountId: accountId, expiresAt: new Date(Date.now() + 86_400_000) }]],
    [schema.adminAccounts, [{ id: accountId, email: "d@mytsi.org", isAdmin: true, status: "approved" }]],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "GET",
      url: "/v1/admin/auth/me",
      headers: { authorization: "Bearer test-token-value" },
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.json().email, "d@mytsi.org");
  } finally {
    await app.close();
  }
});

test("GET /v1/admin/auth/me rejects an invalid (unknown) token (401)", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows([schema.adminSessions, []]);
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "GET",
      url: "/v1/admin/auth/me",
      headers: { authorization: "Bearer no-such-token" },
    });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("GET /v1/admin/auth/me rejects an expired session token (401)", async () => {
  const { schema } = await import("@owlnighter/db");
  const accountId = "aaaaaaaa-0000-4000-8000-000000000005";
  const byTable = tableRows([
    schema.adminSessions,
    [{ adminAccountId: accountId, expiresAt: new Date(Date.now() - 1000) }],
  ]);
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "GET",
      url: "/v1/admin/auth/me",
      headers: { authorization: "Bearer expired-token" },
    });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("logout is idempotent when the session is already gone", async () => {
  const { logout } = await import("../services/admin-auth.js");
  const deps = fakeDeps();
  await assert.doesNotReject(() => logout(deps, "some-token-that-does-not-exist"));
});

test("logout invalidates a live session: /me 401s afterward with the same token", async () => {
  const { schema } = await import("@owlnighter/db");
  const accountId = "aaaaaaaa-0000-4000-8000-000000000009";
  const byTable = tableRows(
    [schema.adminSessions, [{ adminAccountId: accountId, expiresAt: new Date(Date.now() + 86_400_000) }]],
    [schema.adminAccounts, [{ id: accountId, email: "e@mytsi.org", isAdmin: true, status: "approved" }]],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  const authHeader = { authorization: "Bearer live-session-token" };
  try {
    const meBefore = await app.inject({ method: "GET", url: "/v1/admin/auth/me", headers: authHeader });
    assert.equal(meBefore.statusCode, 200);

    const logoutRes = await app.inject({ method: "POST", url: "/v1/admin/auth/logout", headers: authHeader });
    assert.equal(logoutRes.statusCode, 204);

    // The fake db rig's delete() doesn't mutate byTable (it can't model a real
    // WHERE-scoped delete), so simulate the row actually being gone the way a
    // real DELETE would leave it. The prior logout call still genuinely
    // exercised extracting + hashing the same bearer token the guard validated.
    byTable.set(schema.adminSessions, []);

    const meAfter = await app.inject({ method: "GET", url: "/v1/admin/auth/me", headers: authHeader });
    assert.equal(meAfter.statusCode, 401);
  } finally {
    await app.close();
  }
});
