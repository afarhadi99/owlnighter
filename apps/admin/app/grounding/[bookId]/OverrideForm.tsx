"use client";

import { useState } from "react";
import { api, ApiRequestError } from "@/lib/api";

// POST /v1/admin/books/:id/override — manual correction / trust lock.
// fieldOverrides is a free-form record in the contract, so we take raw JSON
// and validate it parses before sending. reason is required.
export function OverrideForm({ bookId }: { bookId: string }) {
  const [fieldsJson, setFieldsJson] = useState('{\n  "pageCount": 336\n}');
  const [reason, setReason] = useState("");
  const [trustLock, setTrustLock] = useState(false);
  const [status, setStatus] = useState<
    { kind: "idle" | "ok" | "err"; msg?: string }
  >({ kind: "idle" });
  const [submitting, setSubmitting] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setStatus({ kind: "idle" });

    let fieldOverrides: Record<string, unknown>;
    try {
      fieldOverrides = JSON.parse(fieldsJson) as Record<string, unknown>;
      if (typeof fieldOverrides !== "object" || fieldOverrides === null)
        throw new Error("must be a JSON object");
    } catch (err) {
      setStatus({ kind: "err", msg: `Invalid JSON: ${(err as Error).message}` });
      return;
    }

    setSubmitting(true);
    try {
      await api.overrideBook(bookId, { fieldOverrides, trustLock, reason });
      setStatus({ kind: "ok", msg: "Override applied." });
    } catch (err) {
      setStatus({
        kind: "err",
        msg:
          err instanceof ApiRequestError
            ? `${err.status}: ${err.body?.error.message ?? err.message}`
            : (err as Error).message,
      });
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={onSubmit} className="space-y-3">
      <label className="flex flex-col gap-1">
        <span className="text-[11px] uppercase tracking-widest text-muted">
          Field overrides (JSON)
        </span>
        <textarea
          value={fieldsJson}
          onChange={(e) => setFieldsJson(e.target.value)}
          rows={5}
          spellCheck={false}
          className="rounded border border-line bg-ink-900 px-2 py-1.5 font-mono text-[13px] text-slate-100 outline-none focus:border-accent"
        />
      </label>

      <label className="flex flex-col gap-1">
        <span className="text-[11px] uppercase tracking-widest text-muted">
          Reason (required — audit trail)
        </span>
        <input
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          required
          placeholder="Publisher confirmed page count; catalog was wrong."
          className="h-9 rounded border border-line bg-ink-900 px-2 text-sm text-slate-100 outline-none focus:border-accent"
        />
      </label>

      <label className="flex items-center gap-2 text-sm text-slate-300">
        <input
          type="checkbox"
          checked={trustLock}
          onChange={(e) => setTrustLock(e.target.checked)}
        />
        Trust-lock these fields (future grounding runs won&apos;t overwrite)
      </label>

      {status.kind === "ok" ? (
        <div className="rounded border border-good/40 bg-good/10 px-3 py-2 text-xs text-good">
          {status.msg}
        </div>
      ) : null}
      {status.kind === "err" ? (
        <div className="rounded border border-bad/40 bg-bad/10 px-3 py-2 text-xs text-bad">
          {status.msg}
        </div>
      ) : null}

      <button
        type="submit"
        disabled={submitting || !reason.trim()}
        className="h-9 rounded bg-accent px-4 text-sm font-medium text-ink-900 disabled:opacity-40"
      >
        {submitting ? "Applying…" : "Apply override"}
      </button>
    </form>
  );
}
