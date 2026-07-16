"use client";
import { useActionState } from "react";
import { saveDefaultProviderAction, type SaveProviderState } from "./actions";

const initialState: SaveProviderState = {};
const PROVIDERS = ["gemini", "groq", "openrouter", "ai_tutor_api"] as const;

export function DefaultProviderCard({
  defaultProvider,
  quizOverride,
  rewriteOverride,
}: {
  defaultProvider: string;
  quizOverride: string;
  rewriteOverride: string;
}) {
  const [state, formAction, pending] = useActionState(saveDefaultProviderAction, initialState);

  return (
    <div className="mb-6 rounded-md border border-line bg-ink-800 p-4">
      <h2 className="mb-1 font-mono text-sm font-semibold text-slate-200">Default provider &amp; task overrides</h2>
      <p className="mb-3 text-xs text-muted">
        The default only pre-selects a provider in this UI. Book grounding and plan generation always stay
        Gemini-first for accuracy; only quiz generation and rewrite may be reassigned below.
      </p>
      <form action={formAction} className="space-y-3">
        <label className="block text-sm text-muted">
          Default provider (UI pre-selection only)
          <select
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
        <label className="block text-sm text-muted">
          Quiz generation provider override
          <select
            name="ai_provider.task_override.quiz_generation"
            defaultValue={quizOverride}
            className="mt-1 w-full rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
          >
            <option value="">use built-in routing (Groq-first)</option>
            {PROVIDERS.map((p) => (
              <option key={p} value={p}>
                {p}
              </option>
            ))}
          </select>
        </label>
        <label className="block text-sm text-muted">
          Rewrite provider override
          <select
            name="ai_provider.task_override.rewrite"
            defaultValue={rewriteOverride}
            className="mt-1 w-full rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
          >
            <option value="">use built-in routing (Groq-first)</option>
            {PROVIDERS.map((p) => (
              <option key={p} value={p}>
                {p}
              </option>
            ))}
          </select>
        </label>
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
