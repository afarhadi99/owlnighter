"use client";

import { useState } from "react";
import Link from "next/link";
import { api, ApiRequestError } from "@/lib/api";
import type { BookSearchResponse, CatalogCandidate } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { DataTable } from "@/components/DataTable";
import { Badge } from "@/components/Badge";
import { Spinner } from "@/components/Spinner";

export default function BooksPage() {
  const [title, setTitle] = useState("");
  const [author, setAuthor] = useState("");
  const [isbn13, setIsbn13] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<BookSearchResponse | null>(null);

  async function onSearch(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    setResult(null);
    try {
      const res = await api.searchBooks({
        title: title.trim(),
        author: author.trim() || undefined,
        isbn13: isbn13.trim() || undefined,
        limit: 15,
      });
      setResult(res);
    } catch (err) {
      setError(
        err instanceof ApiRequestError
          ? `${err.status}: ${err.body?.error.message ?? err.message}`
          : (err as Error).message,
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      <PageHeader
        title="Books & Reconciliation"
        subtitle="Deterministic Google Books + Open Library search. Inspect the raw candidates that feed edition reconciliation before grounding."
      />

      <form
        onSubmit={onSearch}
        className="mb-6 grid grid-cols-1 gap-3 rounded-md border border-line bg-ink-800 p-4 sm:grid-cols-[2fr_2fr_1fr_auto]"
      >
        <Field label="Title" value={title} onChange={setTitle} required />
        <Field label="Author" value={author} onChange={setAuthor} />
        <Field label="ISBN-13" value={isbn13} onChange={setIsbn13} />
        <div className="flex items-end">
          <button
            type="submit"
            disabled={loading || !title.trim()}
            className="h-9 rounded bg-accent px-4 text-sm font-medium text-ink-900 disabled:opacity-40"
          >
            {loading ? (
              <span className="inline-flex items-center gap-1.5">
                <Spinner size={14} /> Searching…
              </span>
            ) : (
              "Search"
            )}
          </button>
        </div>
      </form>

      {error ? (
        <div className="mb-4 rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-xs text-bad">
          POST /v1/books/search failed — {error}
        </div>
      ) : null}

      {result?.suggested ? (
        <div className="mb-4 rounded-md border border-line bg-ink-800 p-4">
          <div className="mb-1 text-[11px] uppercase tracking-widest text-muted">
            Suggested identity (pre-grounding)
          </div>
          <div className="font-mono text-sm text-slate-100">
            {result.suggested.canonicalTitle}
            <span className="text-muted">
              {" "}
              — {result.suggested.authors.join(", ")}
            </span>
          </div>
          <div className="mt-1 text-xs text-muted">
            {result.suggested.publishedYear ?? "—"} ·{" "}
            {result.suggested.pageCount ?? "—"} pp · confidence{" "}
            <Badge
              tone={
                result.suggested.confidence >= 0.85
                  ? "good"
                  : result.suggested.confidence >= 0.6
                    ? "warn"
                    : "bad"
              }
            >
              {result.suggested.confidence.toFixed(2)}
            </Badge>
          </div>
        </div>
      ) : null}

      {result ? (
        <DataTable<CatalogCandidate & Record<string, unknown>>
          rowKey={(r) => `${r.source}:${r.sourceId}`}
          rows={
            (result.candidates as (CatalogCandidate & Record<string, unknown>)[]) ??
            []
          }
          empty="No candidates returned for that query."
          columns={[
            {
              key: "source",
              header: "Source",
              render: (r) => (
                <Badge tone={r.source === "google_books" ? "info" : "neutral"}>
                  {r.source === "google_books" ? "GB" : "OL"}
                </Badge>
              ),
            },
            { key: "title", header: "Title" },
            {
              key: "authors",
              header: "Authors",
              render: (r) => (r.authors.length ? r.authors.join(", ") : "—"),
            },
            { key: "isbn13", header: "ISBN-13", render: (r) => r.isbn13 ?? "—" },
            {
              key: "pageCount",
              header: "Pages",
              render: (r) => r.pageCount ?? "—",
            },
            {
              key: "publishedYear",
              header: "Year",
              render: (r) => r.publishedYear ?? "—",
            },
            {
              key: "actions",
              header: "",
              render: (r) =>
                r.isbn13 ? (
                  <Link
                    href={`/grounding/${encodeURIComponent(r.isbn13)}`}
                    className="text-accent hover:underline"
                  >
                    inspect grounding →
                  </Link>
                ) : (
                  <span className="text-muted">no id</span>
                ),
            },
          ]}
        />
      ) : (
        <p className="text-sm text-muted">
          Enter a title to fetch catalog candidates.
        </p>
      )}
    </div>
  );
}

function Field({
  label,
  value,
  onChange,
  required,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  required?: boolean;
}) {
  return (
    <label className="flex flex-col gap-1">
      <span className="text-[11px] uppercase tracking-widest text-muted">
        {label}
      </span>
      <input
        value={value}
        required={required}
        onChange={(e) => onChange(e.target.value)}
        className="h-9 rounded border border-line bg-ink-900 px-2 font-mono text-sm text-slate-100 outline-none focus:border-accent"
      />
    </label>
  );
}
