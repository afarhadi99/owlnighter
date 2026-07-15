"use client";
import { useActionState } from "react";
import { updateSettingAction, type UpdateSettingState } from "./actions";

const initialState: UpdateSettingState = {};

export function SettingField({
  settingKey,
  label,
  type,
  initialValue,
  configured,
}: {
  settingKey: string;
  label: string;
  type: "string" | "number" | "boolean" | "secret";
  initialValue: unknown;
  configured?: boolean;
}) {
  const boundAction = updateSettingAction.bind(null, settingKey);
  const [state, formAction, pending] = useActionState(boundAction, initialState);

  return (
    <form action={formAction} className="flex items-center gap-3 border-b border-line py-2 last:border-b-0">
      <input type="hidden" name="__type" value={type} />
      <label className="w-64 shrink-0 text-sm text-muted">{label}</label>
      {type === "boolean" ? (
        <select
          name="value"
          defaultValue={String(initialValue)}
          className="rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
        >
          <option value="true">true</option>
          <option value="false">false</option>
        </select>
      ) : type === "secret" ? (
        <input
          name="value"
          type="password"
          placeholder={configured ? "•••• configured — enter a new value to replace" : "not set"}
          className="flex-1 rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
        />
      ) : (
        <input
          name="value"
          type={type === "number" ? "number" : "text"}
          step={type === "number" ? "any" : undefined}
          defaultValue={type === "number" ? Number(initialValue) : String(initialValue ?? "")}
          className="flex-1 rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
        />
      )}
      <button
        type="submit"
        disabled={pending}
        className="shrink-0 rounded border border-accent/40 bg-accent/10 px-2 py-1 text-xs text-accent disabled:opacity-50"
      >
        {pending ? "Saving..." : "Save"}
      </button>
      {state.success ? <span className="text-xs text-good">saved</span> : null}
      {state.error ? <span className="text-xs text-bad">{state.error}</span> : null}
    </form>
  );
}
