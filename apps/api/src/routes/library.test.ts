import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../app.js";
import { DEV_BEARER, fakeDeps, tableRows } from "../test/helpers.js";

const BOOK_ID = "22222222-2222-4222-8222-222222222222";
const ENTRY_ID = "11111111-1111-4111-8111-111111111111";

test("GET /v1/library/books returns entries enriched with book identity", async () => {
  const { schema } = await import("@owlnighter/db");
  // The fake db can't model a join, so register the already-joined row shape.
  const byTable = tableRows(
    [schema.profiles, []],
    [
      schema.userBooks,
      [
        {
          id: ENTRY_ID,
          bookId: BOOK_ID,
          status: "active",
          currentPage: 42,
          targetNightlyPages: 10,
          title: "Dune",
          authors: ["Frank Herbert"],
          coverUrl: "https://covers.example/dune.jpg",
          groundingStatus: "grounded",
          pageCount: 412,
        },
      ],
    ],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "GET", url: "/v1/library/books", headers: DEV_BEARER });
    assert.equal(res.statusCode, 200);
    const book = (res.json() as { books: Array<Record<string, unknown>> }).books[0]!;
    assert.equal(book["bookId"], BOOK_ID);
    assert.equal(book["title"], "Dune");
    assert.deepEqual(book["authors"], ["Frank Herbert"]);
    assert.equal(book["coverUrl"], "https://covers.example/dune.jpg");
    assert.equal(book["groundingStatus"], "grounded");
    assert.equal(book["pageCount"], 412);
    assert.equal(book["currentPage"], 42);
  } finally {
    await app.close();
  }
});

test("GET /v1/library/books requires auth (401)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "GET", url: "/v1/library/books" });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("POST /v1/library/books re-activates an existing entry (idempotent add)", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows(
    [schema.profiles, []],
    [schema.books, [{ id: BOOK_ID }]],
    [schema.userBooks, [{ id: ENTRY_ID, bookId: BOOK_ID, status: "archived", currentPage: 5, targetNightlyPages: 8 }]],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/library/books",
      headers: DEV_BEARER,
      payload: { bookId: BOOK_ID, targetNightlyPages: 15 },
    });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { id: string; status: string; targetNightlyPages: number };
    assert.equal(body.id, ENTRY_ID);
    assert.equal(body.status, "active");
    assert.equal(body.targetNightlyPages, 15);
  } finally {
    await app.close();
  }
});

test("POST /v1/library/books is 404 when the book was never grounded", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows([schema.profiles, []], [schema.books, []]);
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/library/books",
      headers: DEV_BEARER,
      payload: { bookId: BOOK_ID },
    });
    assert.equal(res.statusCode, 404);
    assert.equal(res.json().error.code, "not_found");
  } finally {
    await app.close();
  }
});
