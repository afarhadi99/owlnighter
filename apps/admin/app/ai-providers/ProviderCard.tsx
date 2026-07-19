"use client";
import type { ReactNode } from "react";
import { useActionState } from "react";
import { saveProviderAction, type SaveProviderState } from "./actions";

const initialState: SaveProviderState = {};

export interface ProviderField {
  key: string;
  label: string;
  type: "text" | "password" | "textarea";
  defaultValue?: string;
  placeholder?: string;
}

export function ProviderCard({
  title,
  fields,
  children,
}: {
  title: string;
  fields: ProviderField[];
  children?: ReactNode;
}) {
  const boundAction = saveProviderAction.bind(
    null,
    fields.map((f) => f.key),
  );
  const [state, formAction, pending] = useActionState(boundAction, initialState);

  return (
    <div className="mb-6 rounded-md border border-line bg-ink-800 p-4">
      <h2 className="mb-3 font-mono text-sm font-semibold text-slate-200">{title}</h2>
      <form action={formAction} className="space-y-3">
        {fields.map((f) => (
          <label key={f.key} className="block text-sm text-muted">
            {f.label}
            {f.type === "textarea" ? (
              <textarea
                key={f.defaultValue}
                name={f.key}
                defaultValue={f.defaultValue}
                placeholder={f.placeholder}
                rows={3}
                className="mt-1 w-full rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
              />
            ) : (
              <input
                key={f.type === "password" ? undefined : f.defaultValue}
                name={f.key}
                type={f.type}
                defaultValue={f.type === "password" ? undefined : f.defaultValue}
                placeholder={f.placeholder}
                className="mt-1 w-full rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
              />
            )}
          </label>
        ))}
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
      {children}
    </div>
  );
}
