/**
 * Tiny typed fetch client for the owlnighter Fastify API.
 *
 * Types here are hand-written mirrors of the Zod contracts in
 * @owlnighter/contracts. We deliberately do NOT depend on that workspace
 * package: the admin console is a standalone Next app and keeping it
 * dependency-light avoids dragging the pnpm workspace's NodeNext/ESM build
 * rules into a bundler-resolution Next project. If a contract changes, update
 * the matching shape below. The shapes are kept structurally identical so a
 * copy-paste from openapi.json stays valid.
 */

export const API_BASE =
  process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8787";

// ---- shared scalars ----
export type Confidence = number; // 0..1
export type GroundingStatus = "pending" | "grounded" | "partial" | "blocked";
export type QuizMode = "grounded" | "preview" | "user_text" | "fallback";
export type PacingMode = "gentle" | "standard" | "intensive";

// ---- books ----
export interface CatalogCandidate {
  source: "google_books" | "open_library";
  sourceId: string;
  title: string;
  authors: string[];
  isbn13?: string;
  pageCount?: number;
  publishedYear?: number;
  languageCode?: string;
  coverUrl?: string;
  rawUrl?: string;
}

export interface BookIdentity {
  canonicalTitle: string;
  authors: string[];
  editionLabel?: string;
  isbn13?: string;
  googleBooksId?: string;
  openLibraryKey?: string;
  pageCount?: number;
  languageCode?: string;
  publishedYear?: number;
  coverUrl?: string;
  confidence: Confidence;
}

export interface BookSearchRequest {
  title: string;
  author?: string;
  isbn13?: string;
  locale?: string;
  limit?: number;
}

export interface BookSearchResponse {
  candidates: CatalogCandidate[];
  suggested?: BookIdentity;
}

// ---- grounding (admin) ----
export interface GroundingSource {
  id: string;
  sourceType: "google_books" | "open_library" | "web";
  sourceUrl?: string;
  sourceTitle?: string;
  sourceSnippet?: string;
  citationIndex: number;
  trustScore: Confidence;
}

export interface GroundingFact {
  id: string;
  factType: "page_count" | "chapter_map" | "character" | "theme" | "preview_segment";
  key: string;
  value: unknown;
  confidence: Confidence;
  provenanceSourceIds: string[];
}

export interface GroundingRun {
  id: string;
  bookId: string;
  provider: "gemini";
  providerModel: string;
  runKind: "identify" | "enrich" | "reconcile" | "preview_extract";
  status: "running" | "succeeded" | "failed";
  createdAt: string;
  completedAt?: string;
}

export interface AdminGroundingResponse {
  bookId: string;
  groundingStatus: GroundingStatus;
  runs: GroundingRun[];
  sources: GroundingSource[];
  facts: GroundingFact[];
  reviewBucket: "auto_accepted" | "needs_review" | "limited";
}

export interface AdminOverrideRequest {
  fieldOverrides: Record<string, unknown>;
  trustLock?: boolean;
  reason: string;
}

// ---- admin metrics (Overview) ----
export interface AdminMetricsResponse {
  grounding: {
    autoAccepted: number;
    needsReview: number;
    limited: number;
  };
  quiz: {
    attempts: number;
    passRate: number;
  };
  tts: {
    assets: number;
  };
  books: {
    total: number;
  };
}

// ---- admin TTS cache inspector ----
export interface AdminTtsAsset {
  [key: string]: unknown;
  assetId: string;
  assetKey: string;
  voiceModel: string;
  locale: string;
  storagePath: string;
  durationMs: number;
  createdAt: string;
}

export interface AdminTtsResponse {
  assets: AdminTtsAsset[];
}

// ---- admin quiz QA ----
export interface AdminQuizInvalidateRequest {
  reason: string;
}

export interface AdminQuizInvalidateResponse {
  quizId: string;
  invalidated: boolean;
}

export interface AdminQuizListItem {
  [key: string]: unknown;
  quizId: string;
  stepId: string;
  userId: string;
  quizMode: QuizMode;
  provider: string;
  providerModel: string;
  confidence: Confidence;
  invalidatedAt?: string | null;
  questionCount: number;
  createdAt: string;
}

export interface AdminQuizzesResponse {
  quizzes: AdminQuizListItem[];
}

export interface AdminQuizzesParams {
  stepId?: string;
  limit?: number;
}

// ---- admin plans QA ----
export interface AdminPlanListItem {
  [key: string]: unknown;
  planId: string;
  userId: string;
  bookId: string;
  provider: string;
  providerModel: string;
  planVersion: number;
  pacingMode: PacingMode;
  nightlyGoalPages: number;
  startsOn: string;
  createdAt: string;
  stepCount: number;
}

export interface AdminPlansResponse {
  plans: AdminPlanListItem[];
}

// ---- library (support page lookups) ----
export interface LibraryBook {
  id: string;
  [key: string]: unknown;
}

export interface LibraryBooksResponse {
  books: LibraryBook[];
}

// ---- error envelope ----
export interface ApiError {
  error: {
    code: string;
    message: string;
    requestId?: string;
    details?: unknown;
  };
}

export class ApiRequestError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly body?: ApiError,
  ) {
    super(message);
    this.name = "ApiRequestError";
  }
}

async function request<T>(
  path: string,
  init?: RequestInit & { admin?: boolean },
): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers: {
      "content-type": "application/json",
      // TODO wire real admin auth: forward a Supabase JWT / service token here.
      ...(init?.admin ? { "x-admin": "1" } : {}),
      ...init?.headers,
    },
    cache: "no-store",
  });

  const text = await res.text();
  const body = text ? (JSON.parse(text) as unknown) : undefined;

  if (!res.ok) {
    throw new ApiRequestError(
      `${init?.method ?? "GET"} ${path} -> ${res.status}`,
      res.status,
      body as ApiError,
    );
  }
  return body as T;
}

export const api = {
  searchBooks(body: BookSearchRequest) {
    return request<BookSearchResponse>("/v1/books/search", {
      method: "POST",
      body: JSON.stringify(body),
    });
  },

  getGrounding(bookId: string) {
    return request<AdminGroundingResponse>(
      `/v1/admin/books/${encodeURIComponent(bookId)}/grounding`,
      { admin: true },
    );
  },

  overrideBook(bookId: string, body: AdminOverrideRequest) {
    return request<void>(
      `/v1/admin/books/${encodeURIComponent(bookId)}/override`,
      { method: "POST", admin: true, body: JSON.stringify(body) },
    );
  },

  getMetrics() {
    return request<AdminMetricsResponse>("/v1/admin/metrics", { admin: true });
  },

  getTtsAssets() {
    return request<AdminTtsResponse>("/v1/admin/tts", { admin: true });
  },

  invalidateQuiz(quizId: string, body: AdminQuizInvalidateRequest) {
    return request<AdminQuizInvalidateResponse>(
      `/v1/admin/quiz/${encodeURIComponent(quizId)}/invalidate`,
      { method: "POST", admin: true, body: JSON.stringify(body) },
    );
  },

  getQuizzes(params?: AdminQuizzesParams) {
    const qs = new URLSearchParams();
    if (params?.stepId) qs.set("stepId", params.stepId);
    if (params?.limit != null) qs.set("limit", String(params.limit));
    const suffix = qs.toString() ? `?${qs.toString()}` : "";
    return request<AdminQuizzesResponse>(`/v1/admin/quizzes${suffix}`, {
      admin: true,
    });
  },

  getPlans(limit?: number) {
    const suffix = limit != null ? `?limit=${limit}` : "";
    return request<AdminPlansResponse>(`/v1/admin/plans${suffix}`, {
      admin: true,
    });
  },

  getLibraryBooks() {
    return request<LibraryBooksResponse>("/v1/library/books");
  },
};
