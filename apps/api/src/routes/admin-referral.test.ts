import { test } from "node:test";
import assert from "node:assert/strict";
import { fakeDeps, tableRows } from "../test/helpers.js";

test("adminListReferralCodes maps rows to the DTO shape (ISO dates, nulls preserved)", async () => {
  const { schema } = await import("@owlnighter/db");
  const { adminListReferralCodes } = await import("../services/referral.js");
  const createdAt = new Date("2026-01-01T00:00:00.000Z");
  const deps = fakeDeps({
    byTable: tableRows([
      schema.referralCodes,
      [
        {
          id: "cccccccc-0000-4000-8000-000000000010",
          code: "WAVE1",
          label: "Beta wave 1",
          maxUses: 50,
          useCount: 3,
          isActive: true,
          expiresAt: null,
          createdAt,
        },
      ],
    ]),
  });
  const res = await adminListReferralCodes(deps);
  assert.equal(res.codes.length, 1);
  assert.equal(res.codes[0]?.code, "WAVE1");
  assert.equal(res.codes[0]?.createdAt, createdAt.toISOString());
  assert.equal(res.codes[0]?.expiresAt, null);
});

test("adminCreateReferralCode rejects a custom code that already exists (400)", async () => {
  const { schema } = await import("@owlnighter/db");
  const { adminCreateReferralCode } = await import("../services/referral.js");
  const deps = fakeDeps({ byTable: tableRows([schema.referralCodes, [{ code: "TAKEN" }]]) });
  const admin = { id: "aaaaaaaa-0000-4000-8000-000000000030", email: "admin@mytsi.org", isAdmin: true };
  await assert.rejects(
    () => adminCreateReferralCode(deps, admin, { code: "TAKEN" }),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 400);
      return true;
    },
  );
});

test("adminCreateReferralCode mints a custom code with the given limits", async () => {
  const { schema } = await import("@owlnighter/db");
  const { adminCreateReferralCode } = await import("../services/referral.js");
  // byTable stays empty for referralCodes so the pre-insert collision check
  // (a plain select) correctly reports "no such code yet". The shared fake db
  // rig resolves every `.from(table)` chain — select AND insert/returning —
  // from that same registered array, so it can't also produce a synthesized
  // post-insert row here; we replace `insert` for just this test to capture
  // the values passed in without depending on that shared array.
  const deps = fakeDeps({ byTable: tableRows([schema.referralCodes, []]) });
  const admin = { id: "aaaaaaaa-0000-4000-8000-000000000031", email: "admin@mytsi.org", isAdmin: true };

  let inserted: Record<string, unknown> | undefined;
  const dbSpy = deps.db as unknown as { insert: (t: unknown) => unknown };
  dbSpy.insert = (_t: unknown) => ({
    values(v: Record<string, unknown>) {
      inserted = v;
      return {
        returning: () =>
          Promise.resolve([
            { id: "generated-id", useCount: 0, isActive: true, expiresAt: null, createdAt: new Date(), ...v },
          ]),
      };
    },
  });

  const created = await adminCreateReferralCode(deps, admin, { code: "FRESH1", label: "Wave 2", maxUses: 10 });

  assert.ok(inserted, "insert().values() was called");
  assert.equal(inserted?.code, "FRESH1");
  assert.equal(inserted?.label, "Wave 2");
  assert.equal(inserted?.maxUses, 10);
  assert.equal(inserted?.createdBy, admin.id);
  assert.equal(created.code, "FRESH1");
});

test("adminUpdateReferralCode is 404 for an unknown id", async () => {
  const { schema } = await import("@owlnighter/db");
  const { adminUpdateReferralCode } = await import("../services/referral.js");
  const deps = fakeDeps({ byTable: tableRows([schema.referralCodes, []]) });
  await assert.rejects(
    () => adminUpdateReferralCode(deps, "bbbbbbbb-0000-4000-8000-000000000097", { isActive: false }),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 404);
      return true;
    },
  );
});

test("adminUpdateReferralCode only patches fields present in the request", async () => {
  const { schema } = await import("@owlnighter/db");
  const { adminUpdateReferralCode } = await import("../services/referral.js");
  const id = "cccccccc-0000-4000-8000-000000000020";
  const deps = fakeDeps({
    byTable: tableRows([
      schema.referralCodes,
      [{ id, code: "WAVE1", label: "Beta wave 1", maxUses: 50, useCount: 3, isActive: true, expiresAt: null, createdAt: new Date() }],
    ]),
  });

  let patched: Record<string, unknown> | undefined;
  const dbSpy = deps.db as unknown as { update: (t: unknown) => { set: (v: Record<string, unknown>) => unknown } };
  const originalUpdate = dbSpy.update.bind(dbSpy);
  dbSpy.update = (t: unknown) => {
    const chain = originalUpdate(t);
    const originalSet = chain.set.bind(chain);
    chain.set = (v: Record<string, unknown>) => {
      patched = v;
      return originalSet(v);
    };
    return chain;
  };

  await adminUpdateReferralCode(deps, id, { isActive: false });

  assert.ok(patched, "update().set() was called");
  assert.deepEqual(patched, { isActive: false });
});
