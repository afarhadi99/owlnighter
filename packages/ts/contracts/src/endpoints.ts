import type { z } from "zod";
import {
  BookGroundRequest,
  BookGroundResponse,
  BookSearchRequest,
  BookSearchResponse,
} from "./book.js";
import { PlanGenerateRequest, PlanResponse } from "./plan.js";
import { QuizGenerateRequest, QuizInstance, QuizSubmitRequest, QuizSubmitResponse } from "./quiz.js";
import { AdminGroundingResponse, AdminOverrideRequest } from "./grounding.js";
import {
  AdminMetricsResponse,
  AdminQuizInvalidateRequest,
  AdminQuizInvalidateResponse,
  AdminTtsResponse,
} from "./admin.js";
import {
  AddLibraryBookRequest,
  LibraryBook,
  LibraryBooksResponse,
  PushRegisterRequest,
  StepStartResponse,
  TtsGenerateRequest,
  TtsGenerateResponse,
} from "./misc.js";

export type HttpMethod = "get" | "post" | "put" | "delete";

export interface EndpointDef {
  method: HttpMethod;
  /** Express-style path with `:param`. Converted to `{param}` for OpenAPI. */
  path: string;
  operationId: string;
  summary: string;
  tag: string;
  auth: "user" | "admin" | "none";
  request?: z.ZodType;
  response?: z.ZodType;
}

/**
 * The single source of truth for the HTTP surface. Both the Fastify server and
 * the OpenAPI generator read this list, so the spec cannot drift from the code.
 */
export const ENDPOINTS: readonly EndpointDef[] = [
  {
    method: "post",
    path: "/v1/books/search",
    operationId: "searchBooks",
    summary: "Deterministic Google Books + Open Library search and candidate merge.",
    tag: "books",
    auth: "user",
    request: BookSearchRequest,
    response: BookSearchResponse,
  },
  {
    method: "post",
    path: "/v1/books/ground",
    operationId: "groundBook",
    summary: "Gemini Search Grounding enrichment / edition reconciliation.",
    tag: "books",
    auth: "user",
    request: BookGroundRequest,
    response: BookGroundResponse,
  },
  {
    method: "get",
    path: "/v1/library/books",
    operationId: "listLibraryBooks",
    summary: "List the authenticated user's library books.",
    tag: "library",
    auth: "user",
    response: LibraryBooksResponse,
  },
  {
    method: "post",
    path: "/v1/library/books",
    operationId: "addLibraryBook",
    summary: "Add a grounded book to the user's library.",
    tag: "library",
    auth: "user",
    request: AddLibraryBookRequest,
    response: LibraryBook,
  },
  {
    method: "post",
    path: "/v1/plans/generate",
    operationId: "generatePlan",
    summary: "Create or refresh a nightly reading path.",
    tag: "plans",
    auth: "user",
    request: PlanGenerateRequest,
    response: PlanResponse,
  },
  {
    method: "get",
    path: "/v1/plans/:id",
    operationId: "getPlan",
    summary: "Fetch a plan and its step states.",
    tag: "plans",
    auth: "user",
    response: PlanResponse,
  },
  {
    method: "post",
    path: "/v1/steps/:id/start",
    operationId: "startStep",
    summary: "Open (or reuse) a reading session for a step.",
    tag: "steps",
    auth: "user",
    response: StepStartResponse,
  },
  {
    method: "post",
    path: "/v1/steps/:id/quiz",
    operationId: "generateStepQuiz",
    summary: "Generate or fetch tonight's quiz for a step.",
    tag: "quiz",
    auth: "user",
    request: QuizGenerateRequest,
    response: QuizInstance,
  },
  {
    method: "post",
    path: "/v1/quiz/:id/submit",
    operationId: "submitQuiz",
    summary: "Score answers, mark the reading complete, update streak.",
    tag: "quiz",
    auth: "user",
    request: QuizSubmitRequest,
    response: QuizSubmitResponse,
  },
  {
    method: "post",
    path: "/v1/push/register",
    operationId: "registerPushToken",
    summary: "Register or update a device push token.",
    tag: "push",
    auth: "user",
    request: PushRegisterRequest,
  },
  {
    method: "post",
    path: "/v1/tts/generate",
    operationId: "generateTts",
    summary: "Request background TTS generation (hash-deduped + cached).",
    tag: "tts",
    auth: "user",
    request: TtsGenerateRequest,
    response: TtsGenerateResponse,
  },
  {
    method: "get",
    path: "/v1/admin/books/:id/grounding",
    operationId: "adminGetGrounding",
    summary: "Inspect grounding sources, facts, and diffs for a book.",
    tag: "admin",
    auth: "admin",
    response: AdminGroundingResponse,
  },
  {
    method: "post",
    path: "/v1/admin/books/:id/override",
    operationId: "adminOverrideBook",
    summary: "Manual correction / trust lock on a book's grounded fields.",
    tag: "admin",
    auth: "admin",
    request: AdminOverrideRequest,
  },
  {
    method: "get",
    path: "/v1/admin/metrics",
    operationId: "adminGetMetrics",
    summary: "Dashboard tiles: grounding buckets, quiz pass rate, TTS assets, book count.",
    tag: "admin",
    auth: "admin",
    response: AdminMetricsResponse,
  },
  {
    method: "get",
    path: "/v1/admin/tts",
    operationId: "adminGetTts",
    summary: "List cached TTS assets for the cache inspector.",
    tag: "admin",
    auth: "admin",
    response: AdminTtsResponse,
  },
  {
    method: "post",
    path: "/v1/admin/quiz/:id/invalidate",
    operationId: "adminInvalidateQuiz",
    summary: "Mark a quiz invalid so it is not reused; records a reason.",
    tag: "admin",
    auth: "admin",
    request: AdminQuizInvalidateRequest,
    response: AdminQuizInvalidateResponse,
  },
] as const;
