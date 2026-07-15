"use client";
import { useActionState } from "react";
import { loginAction, type LoginActionState } from "./actions";

const initialState: LoginActionState = {};

export default function LoginPage() {
  const [state, formAction, pending] = useActionState(loginAction, initialState);

  return (
    <div className="flex min-h-screen items-center justify-center">
      <form action={formAction} className="w-full max-w-sm space-y-4 rounded-md border border-line bg-ink-800 p-6">
        <h1 className="font-mono text-lg font-semibold text-slate-100">owlnighter admin</h1>
        {state.error ? (
          <div className="rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">{state.error}</div>
        ) : null}
        <label className="block text-sm text-muted">
          Email
          <input
            name="email"
            type="email"
            required
            className="mt-1 w-full rounded border border-line bg-ink-700 px-3 py-2 text-slate-100"
          />
        </label>
        <label className="block text-sm text-muted">
          Password
          <input
            name="password"
            type="password"
            required
            className="mt-1 w-full rounded border border-line bg-ink-700 px-3 py-2 text-slate-100"
          />
        </label>
        <button
          type="submit"
          disabled={pending}
          className="w-full rounded bg-accent px-3 py-2 text-sm font-semibold text-ink-900 disabled:opacity-50"
        >
          {pending ? "Logging in..." : "Log in"}
        </button>
        <a href="/signup" className="block text-center text-sm text-accent">
          Request access
        </a>
      </form>
    </div>
  );
}
