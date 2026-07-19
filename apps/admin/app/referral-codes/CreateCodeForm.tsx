"use client";
import { useActionState } from "react";
import { createReferralCodeAction, type CreateCodeState } from "./actions";

const initialState: CreateCodeState = {};

export function CreateCodeForm() {
  const [state, formAction, pending] = useActionState(createReferralCodeAction, initialState);

  return (
    <div className="mb-6 rounded-md border border-line bg-ink-800 p-4">
      <h2 className="mb-3 font-mono text-sm font-semibold text-slate-200">Mint a new code</h2>
      <form action={formAction} className="flex flex-wrap items-end gap-3">
        <label className="block text-sm text-muted">
          Code (blank = auto-generated)
          <input
            key={state.success ? Date.now() : "code"}
            name="code"
            type="text"
            placeholder="e.g. BETA-WAVE-2"
            className="mt-1 w-48 rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
          />
        </label>
        <label className="block text-sm text-muted">
          Label
          <input
            key={state.success ? Date.now() : "label"}
            name="label"
            type="text"
            placeholder="e.g. Beta wave 2"
            className="mt-1 w-48 rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
          />
        </label>
        <label className="block text-sm text-muted">
          Max uses (blank = unlimited)
          <input
            key={state.success ? Date.now() : "maxUses"}
            name="maxUses"
            type="number"
            min={1}
            max={1000000}
            className="mt-1 w-32 rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
          />
        </label>
        <label className="block text-sm text-muted">
          Expires (blank = never)
          <input
            key={state.success ? Date.now() : "expiresAt"}
            name="expiresAt"
            type="date"
            className="mt-1 rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
          />
        </label>
        <button
          type="submit"
          disabled={pending}
          className="rounded border border-accent/40 bg-accent/10 px-3 py-1.5 text-xs text-accent disabled:opacity-50"
        >
          {pending ? "Creating..." : "Create code"}
        </button>
      </form>
      {state.error ? <div className="mt-2 text-xs text-bad">{state.error}</div> : null}
      {state.success ? <div className="mt-2 text-xs text-good">Code created.</div> : null}
    </div>
  );
}
