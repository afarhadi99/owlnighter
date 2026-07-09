import { test } from "node:test";
import assert from "node:assert/strict";
import type { Env, Logger } from "@owlnighter/shared";
import { searchCatalog } from "./catalog.js";

const log = { warn() {}, info() {} } as unknown as Logger;
const env = {
  GOOGLE_BOOKS_API_KEY: "",
  OPEN_LIBRARY_BASE_URL: "https://openlibrary.org",
} as unknown as Env;

const googleBody = {
  items: [
    {
      id: "g1",
      volumeInfo: {
        title: "The Hobbit",
        authors: ["J.R.R. Tolkien"],
        industryIdentifiers: [{ type: "ISBN_13", identifier: "9780000000001" }],
        // deliberately NO pageCount — must be backfilled from Open Library
        publishedDate: "1937",
        language: "en",
        infoLink: "https://books.google.example/g1",
      },
    },
    {
      id: "g2",
      volumeInfo: {
        title: "Dune",
        authors: ["Frank Herbert"],
        industryIdentifiers: [{ type: "ISBN_13", identifier: "9780000000002" }],
        pageCount: 412,
        publishedDate: "1965",
        language: "en",
      },
    },
  ],
};

const openLibBody = {
  docs: [
    {
      key: "/works/OL1W",
      title: "The Hobbit",
      author_name: ["J.R.R. Tolkien"],
      first_publish_year: 1937,
      number_of_pages_median: 310,
      isbn: ["9780000000001"],
      language: ["eng"],
      cover_i: 111,
    },
  ],
};

/** Stub global fetch, dispatching by host. Restores on the returned callback. */
function stubFetch(): () => void {
  const original = globalThis.fetch;
  globalThis.fetch = (async (input: unknown) => {
    const url = String(input);
    const body = url.includes("googleapis.com") ? googleBody : openLibBody;
    return new Response(JSON.stringify(body), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
  return () => {
    globalThis.fetch = original;
  };
}

test("searchCatalog merges Google + Open Library, dedupes by ISBN-13", async () => {
  const restore = stubFetch();
  try {
    const candidates = await searchCatalog(env, log, { title: "The Hobbit", limit: 10 });
    // Hobbit collapses to one row; Dune stays separate → 2 total.
    assert.equal(candidates.length, 2);

    const hobbit = candidates.find((c) => c.title === "The Hobbit");
    assert.ok(hobbit, "expected a merged Hobbit candidate");
    // Google wins as the primary record on an ISBN collision.
    assert.equal(hobbit.source, "google_books");
    assert.equal(hobbit.isbn13, "9780000000001");
    // pageCount was missing from Google and backfilled from Open Library.
    assert.equal(hobbit.pageCount, 310);

    const dune = candidates.find((c) => c.title === "Dune");
    assert.ok(dune, "expected the Dune candidate");
    assert.equal(dune.pageCount, 412);
  } finally {
    restore();
  }
});

test("searchCatalog tolerates a source returning nothing", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (async (input: unknown) => {
    const url = String(input);
    // Google errors; Open Library still returns its one doc.
    if (url.includes("googleapis.com")) return new Response("nope", { status: 500 });
    return new Response(JSON.stringify(openLibBody), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
  try {
    const candidates = await searchCatalog(env, log, { title: "The Hobbit", limit: 10 });
    assert.equal(candidates.length, 1);
    assert.equal(candidates[0]?.source, "open_library");
  } finally {
    globalThis.fetch = original;
  }
});
