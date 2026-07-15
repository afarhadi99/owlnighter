"use server";
import { api, ApiRequestError } from "@/lib/api";
import type { AdminOverrideRequest } from "@/lib/api";

// See app/books/actions.ts for why this indirection exists.
export type OverrideBookResult = { ok: true } | { ok: false; error: string };

export async function overrideBookAction(
  bookId: string,
  body: AdminOverrideRequest,
): Promise<OverrideBookResult> {
  try {
    await api.overrideBook(bookId, body);
    return { ok: true };
  } catch (err) {
    const error =
      err instanceof ApiRequestError
        ? `${err.status}: ${err.body?.error.message ?? err.message}`
        : (err as Error).message;
    return { ok: false, error };
  }
}
