"use client";
import { useActionState } from "react";
import { signupAction, type SignupActionState } from "./actions";

const initialState: SignupActionState = {};

export default function SignupPage() {
  const [state, formAction, pending] = useActionState(signupAction, initialState);

  if (state.success) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="w-full max-w-sm rounded-md border border-line bg-ink-800 p-6 text-center">
          <h1 className="font-mono text-lg font-semibold text-slate-100">Request submitted</h1>
          <p className="mt-2 text-sm text-muted">
            An existing admin needs to approve this account before you can log in.
          </p>
          <a href="/login" className="mt-4 inline-block text-sm text-accent">
            Back to login
          </a>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen items-center justify-center">
      <form action={formAction} className="w-full max-w-sm space-y-4 rounded-md border border-line bg-ink-800 p-6">
        <h1 className="font-mono text-lg font-semibold text-slate-100">Request admin access</h1>
        <p className="text-sm text-muted">Only @mytsi.org email addresses may request access.</p>
        {state.error ? (
          <div className="rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">{state.error}</div>
        ) : null}
        <label className="block text-sm text-muted">
          Email
          <input
            name="email"
            type="email"
            required
            placeholder="you@mytsi.org"
            className="mt-1 w-full rounded border border-line bg-ink-700 px-3 py-2 text-slate-100"
          />
        </label>
        <label className="block text-sm text-muted">
          Password
          <input
            name="password"
            type="password"
            required
            minLength={8}
            className="mt-1 w-full rounded border border-line bg-ink-700 px-3 py-2 text-slate-100"
          />
        </label>
        <button
          type="submit"
          disabled={pending}
          className="w-full rounded bg-accent px-3 py-2 text-sm font-semibold text-ink-900 disabled:opacity-50"
        >
          {pending ? "Submitting..." : "Request access"}
        </button>
        <a href="/login" className="block text-center text-sm text-accent">
          Back to login
        </a>
      </form>
    </div>
  );
}
