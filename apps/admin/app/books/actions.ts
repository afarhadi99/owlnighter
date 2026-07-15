"use server";
import { api, ApiRequestError } from "@/lib/api";
import type { BookSearchRequest, BookSearchResponse } from "@/lib/api";

// Client Components can't import lib/api.ts directly once it forwards the
// admin session cookie (that pulls in next/headers, which Next.js refuses to
// bundle into client code). This thin Server Action re-exports the same call
// so BooksPage keeps its existing fetch/loading/error UI unchanged.
export type SearchBooksResult =
  | { ok: true; data: BookSearchResponse }
  | { ok: false; error: string };

export async function searchBooksAction(
  body: BookSearchRequest,
): Promise<SearchBooksResult> {
  try {
    const data = await api.searchBooks(body);
    return { ok: true, data };
  } catch (err) {
    const error =
      err instanceof ApiRequestError
        ? `${err.status}: ${err.body?.error.message ?? err.message}`
        : (err as Error).message;
    return { ok: false, error };
  }
}
