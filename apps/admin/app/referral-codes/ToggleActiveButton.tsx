"use client";
import { useActionState } from "react";
import { toggleReferralCodeAction, type ToggleCodeState } from "./actions";

const initialState: ToggleCodeState = {};

export function ToggleActiveButton({ id, isActive }: { id: string; isActive: boolean }) {
  const boundAction = toggleReferralCodeAction.bind(null, id, !isActive);
  const [state, formAction, pending] = useActionState(boundAction, initialState);

  return (
    <div>
      <form action={formAction}>
        <button
          type="submit"
          disabled={pending}
          className={
            isActive
              ? "rounded border border-bad/40 bg-bad/10 px-2 py-1 text-xs text-bad disabled:opacity-50"
              : "rounded border border-good/40 bg-good/10 px-2 py-1 text-xs text-good disabled:opacity-50"
          }
        >
          {pending ? "Saving..." : isActive ? "Deactivate" : "Activate"}
        </button>
      </form>
      {state.error ? <div className="mt-1 text-xs text-bad">{state.error}</div> : null}
    </div>
  );
}
