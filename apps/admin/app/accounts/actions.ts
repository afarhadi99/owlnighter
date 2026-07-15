"use server";
import { revalidatePath } from "next/cache";
import { api, ApiRequestError } from "@/lib/api";

export interface AccountActionState {
  error?: string;
}

// Signature is (id, prevState, ...) rather than plain (id) so these can be
// bound with .bind(null, id) and driven by useActionState from a Client
// Component row (matching the SettingField pattern in app/settings) — that's
// what lets an expired-session failure surface as inline row state instead of
// an uncaught Server Action exception (which would otherwise blow away the
// whole page, since this app has no error.tsx boundary).
export async function approveAccountAction(
  id: string,
  _prevState: AccountActionState,
): Promise<AccountActionState> {
  try {
    await api.adminApproveAccount(id);
  } catch (err) {
    return { error: err instanceof ApiRequestError ? (err.body?.error.message ?? "Approve failed.") : "Approve failed." };
  }
  revalidatePath("/accounts");
  return {};
}

export async function rejectAccountAction(
  id: string,
  _prevState: AccountActionState,
): Promise<AccountActionState> {
  try {
    await api.adminRejectAccount(id);
  } catch (err) {
    return { error: err instanceof ApiRequestError ? (err.body?.error.message ?? "Reject failed.") : "Reject failed." };
  }
  revalidatePath("/accounts");
  return {};
}
