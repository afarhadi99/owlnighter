"use server";
import { api, ApiRequestError } from "@/lib/api";
import type { AdminQuizInvalidateResponse } from "@/lib/api";

// See app/books/actions.ts for why this indirection exists.
export type InvalidateQuizResult =
  | { ok: true; data: AdminQuizInvalidateResponse }
  | { ok: false; error: string };

export async function invalidateQuizAction(
  quizId: string,
  reason: string,
): Promise<InvalidateQuizResult> {
  try {
    const data = await api.invalidateQuiz(quizId, { reason });
    return { ok: true, data };
  } catch (err) {
    const error =
      err instanceof ApiRequestError
        ? `${err.status}: ${err.body?.error.message ?? err.message}`
        : (err as Error).message;
    return { ok: false, error };
  }
}
