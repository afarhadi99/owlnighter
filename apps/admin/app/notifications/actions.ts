"use server";
import { api, ApiRequestError } from "@/lib/api";
import type { AdminPushTestResponse, PushType } from "@/lib/api";

// See app/books/actions.ts for why this indirection exists: lib/api.ts now
// forwards the admin session cookie via next/headers, so it can no longer be
// imported from a Client Component. This Server Action is the proxy.
export type SendTestPushResult =
  | { ok: true; data: AdminPushTestResponse }
  | { ok: false; error: string };

export async function sendTestPushAction(
  userId: string,
  type: PushType,
): Promise<SendTestPushResult> {
  try {
    const data = await api.sendTestPush(userId, type);
    return { ok: true, data };
  } catch (err) {
    const error =
      err instanceof ApiRequestError
        ? `${err.status}: ${err.body?.error.message ?? err.message}`
        : (err as Error).message;
    return { ok: false, error };
  }
}
