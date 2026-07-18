import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "./app.js";
import { fakeDeps, tableRows } from "./test/helpers.js";

test("GET /healthz returns ok with injected deps", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "GET", url: "/healthz" });
    assert.equal(res.statusCode, 200);
    assert.equal(res.json().status, "ok");
    assert.equal(res.json().env, "development");
  } finally {
    await app.close();
  }
});

test("GET /openapi.json serves the generated contract document", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "GET", url: "/openapi.json" });
    assert.equal(res.statusCode, 200);
    const doc = res.json() as { openapi: string; paths: Record<string, unknown> };
    assert.equal(doc.openapi, "3.1.0");
    // The library list + all other endpoints must be present.
    assert.ok(doc.paths["/v1/library/books"], "library path present");
    assert.ok(doc.paths["/v1/plans"], "list-plans path present");
    assert.equal(Object.keys(doc.paths).length, 32);
  } finally {
    await app.close();
  }
});

test("unknown route returns the 404 ApiError envelope", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "GET", url: "/v1/does-not-exist" });
    assert.equal(res.statusCode, 404);
    assert.equal(res.json().error.code, "not_found");
    assert.ok(res.json().error.requestId, "carries a request id");
  } finally {
    await app.close();
  }
});

test("a user-auth route rejects a missing bearer with the unauthorized envelope", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "GET", url: "/v1/library/books" });
    assert.equal(res.statusCode, 401);
    assert.equal(res.json().error.code, "unauthorized");
  } finally {
    await app.close();
  }
});

test("a bogus (non-DEV) bearer is rejected 401 when Supabase is unconfigured", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({
      method: "GET",
      url: "/v1/library/books",
      headers: { authorization: "Bearer not-a-dev-token" },
    });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("the DEV bearer can impersonate a specific user id (DEV:<uuid>)", async () => {
  const { schema } = await import("@owlnighter/db");
  const OTHER = "99999999-9999-4999-8999-999999999999";
  const byTable = tableRows(
    [schema.profiles, []],
    [
      schema.userBooks,
      [
        {
          id: "11111111-1111-4111-8111-111111111111",
          bookId: "22222222-2222-4222-8222-222222222222",
          status: "active",
          currentPage: 3,
          targetNightlyPages: 10,
          title: "Impersonated Read",
          authors: ["A. Author"],
          coverUrl: null,
          groundingStatus: "grounded",
          pageCount: 200,
        },
      ],
    ],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "GET",
      url: "/v1/library/books",
      headers: { authorization: `Bearer DEV:${OTHER}` },
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.json().books.length, 1);
  } finally {
    await app.close();
  }
});
