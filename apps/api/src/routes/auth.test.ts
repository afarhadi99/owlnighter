import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../app.js";
import { DEV_BEARER, DEV_USER_ID, fakeDeps, tableRows } from "../test/helpers.js";

// ---- POST /v1/auth/validate-referral-code ----

test("validateReferralCode is invalid when no code matches (empty table)", async () => {
  const { schema } = await import("@owlnighter/db");
  const { validateReferralCode } = await import("../services/referral.js");
  const deps = fakeDeps({ byTable: tableRows([schema.referralCodes, []]) });
  const res = await validateReferralCode(deps, { code: "NOPE" });
  assert.equal(res.valid, false);
  assert.equal(res.reason, "Code not found.");
});

test("validateReferralCode is invalid for an inactive code", async () => {
  const { schema } = await import("@owlnighter/db");
  const { validateReferralCode } = await import("../services/referral.js");
  const deps = fakeDeps({
    byTable: tableRows([schema.referralCodes, [{ code: "STALE", isActive: false, maxUses: null, useCount: 0, expiresAt: null }]]),
  });
  const res = await validateReferralCode(deps, { code: "STALE" });
  assert.equal(res.valid, false);
  assert.equal(res.reason, "This code is no longer active.");
});

test("validateReferralCode is invalid for an exhausted code", async () => {
  const { schema } = await import("@owlnighter/db");
  const { validateReferralCode } = await import("../services/referral.js");
  const deps = fakeDeps({
    byTable: tableRows([schema.referralCodes, [{ code: "FULL", isActive: true, maxUses: 5, useCount: 5, expiresAt: null }]]),
  });
  const res = await validateReferralCode(deps, { code: "FULL" });
  assert.equal(res.valid, false);
  assert.equal(res.reason, "This code has reached its usage limit.");
});

test("validateReferralCode is valid for an active, unlimited-use code", async () => {
  const { schema } = await import("@owlnighter/db");
  const { validateReferralCode } = await import("../services/referral.js");
  const deps = fakeDeps({
    byTable: tableRows([schema.referralCodes, [{ code: "GOOD", isActive: true, maxUses: null, useCount: 0, expiresAt: null }]]),
  });
  const res = await validateReferralCode(deps, { code: "GOOD" });
  assert.deepEqual(res, { valid: true });
});

// ---- GET /v1/auth/status ----

test("GET /v1/auth/status requires auth (401 with no token)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "GET", url: "/v1/auth/status" });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("GET /v1/auth/status reports activated=false when no profile row exists", async () => {
  const { schema } = await import("@owlnighter/db");
  const app = await buildApp(fakeDeps({ byTable: tableRows([schema.profiles, []]) }));
  try {
    const res = await app.inject({ method: "GET", url: "/v1/auth/status", headers: DEV_BEARER });
    assert.equal(res.statusCode, 200);
    assert.equal(res.json().activated, false);
  } finally {
    await app.close();
  }
});

test("GET /v1/auth/status reports activated=true once a profile row exists", async () => {
  const { schema } = await import("@owlnighter/db");
  const app = await buildApp(
    fakeDeps({ byTable: tableRows([schema.profiles, [{ id: DEV_USER_ID, isAdmin: false }]]) }),
  );
  try {
    const res = await app.inject({ method: "GET", url: "/v1/auth/status", headers: DEV_BEARER });
    assert.equal(res.statusCode, 200);
    assert.equal(res.json().activated, true);
  } finally {
    await app.close();
  }
});

// ---- POST /v1/auth/activate ----

test("activateAccount is idempotent: an already-activated caller gets their existing profile back", async () => {
  const { schema } = await import("@owlnighter/db");
  const { activateAccount } = await import("../services/referral.js");
  const deps = fakeDeps({
    byTable: tableRows([schema.profiles, [{ id: DEV_USER_ID, displayName: "Already Here", isAdmin: false }]]),
  });
  const res = await activateAccount(deps, { id: DEV_USER_ID, isAdmin: false }, { referralCode: "IRRELEVANT" });
  assert.equal(res.id, DEV_USER_ID);
  assert.equal(res.displayName, "Already Here");
});

test("activateAccount rejects a code that doesn't consume (400)", async () => {
  const { schema } = await import("@owlnighter/db");
  const { activateAccount } = await import("../services/referral.js");
  const deps = fakeDeps({
    byTable: tableRows([schema.profiles, []], [schema.referralCodes, []]),
  });
  await assert.rejects(
    () => activateAccount(deps, { id: DEV_USER_ID, isAdmin: false }, { referralCode: "BADCODE" }),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 400);
      return true;
    },
  );
});

test("activateAccount creates a profile once the code is consumed", async () => {
  const { schema } = await import("@owlnighter/db");
  const { activateAccount } = await import("../services/referral.js");
  const deps = fakeDeps({
    byTable: tableRows(
      [schema.profiles, []],
      [schema.referralCodes, [{ id: "cccccccc-0000-4000-8000-000000000001", code: "GOOD" }]],
      [schema.referralRedemptions, []],
    ),
  });
  const res = await activateAccount(deps, { id: DEV_USER_ID, isAdmin: false }, { referralCode: "GOOD", displayName: "New Reader" });
  assert.equal(res.id, DEV_USER_ID);
  assert.equal(res.displayName, "New Reader");
  assert.equal(res.isAdmin, false);
});
