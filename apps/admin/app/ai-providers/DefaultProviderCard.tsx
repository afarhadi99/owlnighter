"use client";
import { useActionState } from "react";
import { saveDefaultProviderAction, type SaveProviderState } from "./actions";

const initialState: SaveProviderState = {};
const PROVIDERS = ["gemini", "groq", "openrouter", "ai_tutor_api"] as const;

function OverrideSelect({ name, label, value }: { name: string; label: string; value: string }) {
  return (
    <label className="block text-sm text-muted">
      {label}
      <select
        key={value}
        name={name}
        defaultValue={value}
        className="mt-1 w-full rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
      >
        <option value="">use the default provider above</option>
        {PROVIDERS.map((p) => (
          <option key={p} value={p}>
            {p}
          </option>
        ))}
      </select>
    </label>
  );
}

export function DefaultProviderCard({
  defaultProvider,
  groundingOverride,
  planOverride,
  quizOverride,
  rewriteOverride,
}: {
  defaultProvider: string;
  groundingOverride: string;
  planOverride: string;
  quizOverride: string;
  rewriteOverride: string;
}) {
  const [state, formAction, pending] = useActionState(saveDefaultProviderAction, initialState);

  return (
    <div className="mb-6 rounded-md border border-line bg-ink-800 p-4">
      <h2 className="mb-1 font-mono text-sm font-semibold text-slate-200">Default provider &amp; task overrides</h2>
      <p className="mb-3 text-xs text-muted">
        Every task routes to the default provider unless a per-task override is set below. Nothing is hardcoded
        to a specific model — an override without a working API key/workflow for that task falls back to Gemini
        automatically.
      </p>
      <form action={formAction} className="space-y-3">
        <label className="block text-sm text-muted">
          Default provider
          <select
            key={defaultProvider}
            name="ai_provider.default"
            defaultValue={defaultProvider}
            className="mt-1 w-full rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
          >
            {PROVIDERS.map((p) => (
              <option key={p} value={p}>
                {p}
              </option>
            ))}
          </select>
        </label>
        <OverrideSelect
          name="ai_provider.task_override.book_grounding"
          label="Book grounding provider override"
          value={groundingOverride}
        />
        <OverrideSelect
          name="ai_provider.task_override.plan_generation"
          label="Plan generation provider override"
          value={planOverride}
        />
        <OverrideSelect
          name="ai_provider.task_override.quiz_generation"
          label="Quiz generation provider override"
          value={quizOverride}
        />
        <OverrideSelect name="ai_provider.task_override.rewrite" label="Rewrite provider override" value={rewriteOverride} />
        <div className="flex items-center gap-2">
          <button
            type="submit"
            disabled={pending}
            className="rounded border border-accent/40 bg-accent/10 px-3 py-1 text-xs text-accent disabled:opacity-50"
          >
            {pending ? "Saving..." : "Save"}
          </button>
          {state.success ? <span className="text-xs text-good">saved</span> : null}
          {state.error ? <span className="text-xs text-bad">{state.error}</span> : null}
        </div>
      </form>
    </div>
  );
}
