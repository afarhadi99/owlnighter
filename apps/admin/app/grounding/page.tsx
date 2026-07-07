"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { PageHeader } from "@/components/PageHeader";

// The detail view is keyed by bookId. There is no "list grounding runs"
// endpoint in the contract, so this page is just a jump-to form. Reach
// individual books via Books & Reconciliation (which links here per candidate).
export default function GroundingIndexPage() {
  const router = useRouter();
  const [bookId, setBookId] = useState("");

  return (
    <div>
      <PageHeader
        title="Grounding Review"
        subtitle="Inspect Gemini citations, confidence, extracted facts, and full source provenance for a specific book."
      />

      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (bookId.trim())
            router.push(`/grounding/${encodeURIComponent(bookId.trim())}`);
        }}
        className="flex max-w-xl items-end gap-3 rounded-md border border-line bg-ink-800 p-4"
      >
        <label className="flex flex-1 flex-col gap-1">
          <span className="text-[11px] uppercase tracking-widest text-muted">
            Book ID (UUID or ISBN-13)
          </span>
          <input
            value={bookId}
            onChange={(e) => setBookId(e.target.value)}
            placeholder="9780141439600"
            className="h-9 rounded border border-line bg-ink-900 px-2 font-mono text-sm text-slate-100 outline-none focus:border-accent"
          />
        </label>
        <button
          type="submit"
          disabled={!bookId.trim()}
          className="h-9 rounded bg-accent px-4 text-sm font-medium text-ink-900 disabled:opacity-40"
        >
          Inspect
        </button>
      </form>

      <p className="mt-4 text-sm text-muted">
        Tip: the Books &amp; Reconciliation page links each candidate straight to
        its grounding detail.
      </p>
    </div>
  );
}
