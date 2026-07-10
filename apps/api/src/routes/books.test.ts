import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../app.js";
import { DEV_BEARER, fakeAi, fakeDeps, tableRows } from "../test/helpers.js";

/** Stub global fetch so books/search resolves without hitting a catalog API. */
function stubCatalogFetch(): () => void {
  const original = globalThis.fetch;
  globalThis.fetch = (async (input: unknown) => {
    const url = String(input);
    const body = url.includes("googleapis.com")
      ? {
          items: [
            {
              id: "g1",
              volumeInfo: {
                title: "Dune",
                authors: ["Frank Herbert"],
                industryIdentifiers: [{ type: "ISBN_13", identifier: "9780441172719" }],
                pageCount: 412,
                publishedDate: "1965",
                language: "en",
              },
            },
          ],
        }
      : { docs: [] };
    return new Response(JSON.stringify(body), { status: 200, headers: { "content-type": "application/json" } });
  }) as typeof fetch;
  return () => {
    globalThis.fetch = original;
  };
}

test("POST /v1/books/search returns merged candidates + a suggestion", async () => {
  const restore = stubCatalogFetch();
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/books/search",
      headers: DEV_BEARER,
      payload: { title: "Dune" },
    });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { candidates: Array<{ title: string }>; suggested?: { canonicalTitle: string } };
    assert.equal(body.candidates.length, 1);
    assert.equal(body.candidates[0]?.title, "Dune");
    assert.equal(body.suggested?.canonicalTitle, "Dune");
  } finally {
    await app.close();
    restore();
  }
});

test("POST /v1/books/search requires auth (401)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "POST", url: "/v1/books/search", payload: { title: "Dune" } });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("POST /v1/books/search rejects a body that fails schema validation (400)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/books/search",
      headers: DEV_BEARER,
      payload: { title: "" }, // min(1) violated
    });
    assert.equal(res.statusCode, 400);
    assert.equal(res.json().error.code, "bad_request");
  } finally {
    await app.close();
  }
});

test("POST /v1/books/ground persists and returns a bookId + grounding status", async () => {
  const { schema } = await import("@owlnighter/db");
  // Identity with no strong keys → findExistingBook short-circuits → insert path.
  const grounded = {
    identity: {
      canonicalTitle: "Dune",
      authors: ["Frank Herbert"],
      pageCount: 412,
      confidence: 0.95,
    },
    pageLevelUnsafe: false,
    sources: [],
    facts: [],
  };
  const byTable = tableRows(
    [schema.profiles, []],
    [schema.books, [{ id: "33333333-3333-4333-8333-333333333333" }]],
    [schema.bookGroundingRuns, [{ id: "44444444-4444-4444-8444-444444444444" }]],
  );
  const app = await buildApp(
    fakeDeps({ byTable, ai: fakeAi(grounded), env: { GEMINI_API_KEY: "test-key" } }),
  );
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/books/ground",
      headers: DEV_BEARER,
      // Pre-supply a candidate so the route skips the network catalog search.
      payload: {
        title: "Dune",
        candidates: [{ source: "google_books", sourceId: "g1", title: "Dune", authors: ["Frank Herbert"] }],
      },
    });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { bookId: string; groundingStatus: string; pageLevelUnsafe: boolean };
    assert.equal(body.bookId, "33333333-3333-4333-8333-333333333333");
    // confidence 0.95 (>= auto-accept 0.85) + page-level safe → grounded.
    assert.equal(body.groundingStatus, "grounded");
    assert.equal(body.pageLevelUnsafe, false);
  } finally {
    await app.close();
  }
});

test("POST /v1/books/ground is 503 when GEMINI_API_KEY is unset", async () => {
  const app = await buildApp(fakeDeps({ env: { GEMINI_API_KEY: "" } }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/books/ground",
      headers: DEV_BEARER,
      payload: {
        title: "Dune",
        candidates: [{ source: "google_books", sourceId: "g1", title: "Dune", authors: ["Frank Herbert"] }],
      },
    });
    assert.equal(res.statusCode, 503);
    assert.equal(res.json().error.code, "service_unavailable");
  } finally {
    await app.close();
  }
});
