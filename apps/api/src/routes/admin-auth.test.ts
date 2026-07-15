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

test("logout() deletes the session row from admin_sessions", async () => {
  const { schema } = await import("@owlnighter/db");
  const { logout } = await import("../services/admin-auth.js");
  const deps = fakeDeps();

  // The fake db rig's delete() is a no-op that can't model a real WHERE-scoped
  // delete, so the only way to meaningfully verify logout() targets the right
  // table is to spy on deps.db.delete's argument directly, rather than trying
  // to observe an after-effect through a follow-up read. Cast to a loosely
  // typed view for the spy — the real Db type's delete() is a generic
  // overload that doesn't accept `unknown`, but the fake rig's runtime
  // implementation is happy to take it.
  let deletedTable: unknown;
  const dbSpy = deps.db as unknown as { delete: (table: unknown) => unknown };
  const originalDelete = dbSpy.delete.bind(dbSpy);
  dbSpy.delete = (table: unknown) => {
    deletedTable = table;
    return originalDelete(table);
  };

  await logout(deps, "some-token-value");

  assert.equal(deletedTable, schema.adminSessions);
});

// ---- GET /v1/admin/accounts/pending ----

test("GET /v1/admin/accounts/pending maps account rows to id/email/status/createdAt (ISO)", async () => {
  const { schema } = await import("@owlnighter/db");
  const adminId = "aaaaaaaa-0000-4000-8000-000000000011";
  const pendingId = "aaaaaaaa-0000-4000-8000-000000000012";
  const createdAt = new Date("2026-01-01T00:00:00.000Z");
  // The fake db rig returns whatever's registered for a table verbatim,
  // ignoring the real WHERE clause — so this array has to double as both the
  // adminPanelGuard's caller lookup (needs an approved+isAdmin row) and the
  // rows listPendingAccounts maps into its response. We only assert on the
  // pending entry's mapped shape, not on the response being filtered to
  // pending-only (that filtering is real-DB behavior this rig can't model).
  const byTable = tableRows(
    [schema.adminSessions, [{ adminAccountId: adminId, expiresAt: new Date(Date.now() + 86_400_000) }]],
    [
      schema.adminAccounts,
      [
        // listPendingAccounts maps every registered row (the fake can't filter
        // on `.where()`), so the caller's own row needs a createdAt too, or
        // the map's r.createdAt.toISOString() throws on undefined.
        { id: adminId, email: "admin@mytsi.org", isAdmin: true, status: "approved", createdAt: new Date() },
        { id: pendingId, email: "waiting@mytsi.org", status: "pending", createdAt },
      ],
    ],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "GET",
      url: "/v1/admin/accounts/pending",
      headers: { authorization: "Bearer pending-list-token" },
    });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { accounts: Array<{ id: string; email: string; status: string; createdAt: string }> };
    const mapped = body.accounts.find((a) => a.id === pendingId);
    assert.ok(mapped, "pending account present in the response");
    assert.equal(mapped?.email, "waiting@mytsi.org");
    assert.equal(mapped?.status, "pending");
    assert.equal(mapped?.createdAt, createdAt.toISOString());
  } finally {
    await app.close();
  }
});

// ---- POST /v1/admin/accounts/:id/approve, /v1/admin/accounts/:id/reject ----

// Note on these 4 tests: they call the service functions directly rather than
// through app.inject. A genuine HTTP-level "empty adminAccounts table" 404
// isn't reachable here — adminPanelGuard's own caller lookup reads the same
// byTable entry for schema.adminAccounts (the fake ignores `.where()`), so an
// empty table 401s at the guard before the handler ever runs. Calling the
// service directly with a hand-built AdminPrincipal isolates exactly the
// behavior these tests care about: the account-id existence check, and
// (below) precisely which fields get written on approve vs. reject.

test("approveAccount() is 404 for an unknown account id", async () => {
  const { schema } = await import("@owlnighter/db");
  const { approveAccount } = await import("../services/admin-auth.js");
  const deps = fakeDeps({ byTable: tableRows([schema.adminAccounts, []]) });
  const admin = { id: "aaaaaaaa-0000-4000-8000-000000000020", email: "admin@mytsi.org", isAdmin: true };
  await assert.rejects(
    () => approveAccount(deps, admin, "bbbbbbbb-0000-4000-8000-000000000099"),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 404);
      return true;
    },
  );
});

test("rejectAccount() is 404 for an unknown account id", async () => {
  const { schema } = await import("@owlnighter/db");
  const { rejectAccount } = await import("../services/admin-auth.js");
  const deps = fakeDeps({ byTable: tableRows([schema.adminAccounts, []]) });
  const admin = { id: "aaaaaaaa-0000-4000-8000-000000000021", email: "admin@mytsi.org", isAdmin: true };
  await assert.rejects(
    () => rejectAccount(deps, admin, "bbbbbbbb-0000-4000-8000-000000000098"),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 404);
      return true;
    },
  );
});

test("approveAccount() sets status=approved, isAdmin=true, approvedBy/approvedAt/updatedAt", async () => {
  const { schema } = await import("@owlnighter/db");
  const { approveAccount } = await import("../services/admin-auth.js");
  const accountId = "cccccccc-0000-4000-8000-000000000001";
  const admin = { id: "aaaaaaaa-0000-4000-8000-000000000022", email: "admin@mytsi.org", isAdmin: true };
  const deps = fakeDeps({ byTable: tableRows([schema.adminAccounts, [{ id: accountId }]]) });

  // Same spy technique as the logout()/deps.db.delete spy above, adapted to
  // deps.db.update(...).set(...): the fake rig hands back a fresh chain
  // object per call, so wrap its .set to capture the values argument.
  let captured: Record<string, unknown> | undefined;
  const dbSpy = deps.db as unknown as {
    update: (table: unknown) => { set: (values: Record<string, unknown>) => unknown };
  };
  const originalUpdate = dbSpy.update.bind(dbSpy);
  dbSpy.update = (table: unknown) => {
    const chain = originalUpdate(table);
    const originalSet = chain.set.bind(chain);
    chain.set = (values: Record<string, unknown>) => {
      captured = values;
      return originalSet(values);
    };
    return chain;
  };

  const result = await approveAccount(deps, admin, accountId);

  assert.equal(result.status, "approved");
  assert.ok(captured, "update().set() was called");
  assert.equal(captured?.status, "approved");
  assert.equal(captured?.isAdmin, true);
  assert.equal(captured?.approvedBy, admin.id);
  assert.ok(captured?.approvedAt instanceof Date);
  assert.ok(captured?.updatedAt instanceof Date);
  assert.equal((captured?.approvedAt as Date).getTime(), (captured?.updatedAt as Date).getTime());
});

test("rejectAccount() sets status=rejected and does NOT grant isAdmin", async () => {
  const { schema } = await import("@owlnighter/db");
  const { rejectAccount } = await import("../services/admin-auth.js");
  const accountId = "cccccccc-0000-4000-8000-000000000002";
  const admin = { id: "aaaaaaaa-0000-4000-8000-000000000023", email: "admin@mytsi.org", isAdmin: true };
  const deps = fakeDeps({ byTable: tableRows([schema.adminAccounts, [{ id: accountId }]]) });

  let captured: Record<string, unknown> | undefined;
  const dbSpy = deps.db as unknown as {
    update: (table: unknown) => { set: (values: Record<string, unknown>) => unknown };
  };
  const originalUpdate = dbSpy.update.bind(dbSpy);
  dbSpy.update = (table: unknown) => {
    const chain = originalUpdate(table);
    const originalSet = chain.set.bind(chain);
    chain.set = (values: Record<string, unknown>) => {
      captured = values;
      return originalSet(values);
    };
    return chain;
  };

  const result = await rejectAccount(deps, admin, accountId);

  assert.equal(result.status, "rejected");
  assert.ok(captured, "update().set() was called");
  assert.equal(captured?.status, "rejected");
  assert.equal(captured?.approvedBy, admin.id);
  // This is the single most important assertion in the file: reject must
  // never grant isAdmin. approve vs. reject differ by exactly this one field,
  // and that difference is the entire authorization model of the feature.
  assert.ok(!("isAdmin" in (captured ?? {})), "rejectAccount must not set isAdmin");
});
