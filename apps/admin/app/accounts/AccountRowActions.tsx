"use client";
import { useActionState } from "react";
import { approveAccountAction, rejectAccountAction, type AccountActionState } from "./actions";

const initialState: AccountActionState = {};

export function AccountRowActions({ id }: { id: string }) {
  const boundApprove = approveAccountAction.bind(null, id);
  const boundReject = rejectAccountAction.bind(null, id);
  const [approveState, approveFormAction, approvePending] = useActionState(boundApprove, initialState);
  const [rejectState, rejectFormAction, rejectPending] = useActionState(boundReject, initialState);
  const pending = approvePending || rejectPending;

  return (
    <div>
      <div className="flex gap-2">
        <form action={approveFormAction}>
          <button
            type="submit"
            disabled={pending}
            className="rounded border border-good/40 bg-good/10 px-2 py-1 text-xs text-good disabled:opacity-50"
          >
            {approvePending ? "Approving..." : "Approve"}
          </button>
        </form>
        <form action={rejectFormAction}>
          <button
            type="submit"
            disabled={pending}
            className="rounded border border-bad/40 bg-bad/10 px-2 py-1 text-xs text-bad disabled:opacity-50"
          >
            {rejectPending ? "Rejecting..." : "Reject"}
          </button>
        </form>
      </div>
      {approveState.error ? <div className="mt-1 text-xs text-bad">{approveState.error}</div> : null}
      {rejectState.error ? <div className="mt-1 text-xs text-bad">{rejectState.error}</div> : null}
    </div>
  );
}
