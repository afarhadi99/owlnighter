import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import { ZodError } from "zod";
import type { ApiError } from "@owlnighter/contracts";

/**
 * Application error carrying an HTTP status + stable machine code. Throwing this
 * from a handler yields the contract `ApiError` envelope with the right status.
 */
export class HttpError extends Error {
  readonly statusCode: number;
  readonly code: string;
  readonly details?: unknown;

  constructor(statusCode: number, code: string, message: string, details?: unknown) {
    super(message);
    this.name = "HttpError";
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
  }
}

export const badRequest = (msg: string, details?: unknown) => new HttpError(400, "bad_request", msg, details);
export const unauthorized = (msg = "Missing or invalid credentials.") => new HttpError(401, "unauthorized", msg);
export const forbidden = (msg = "Admin access required.") => new HttpError(403, "forbidden", msg);
export const notFound = (msg = "Not found.") => new HttpError(404, "not_found", msg);
export const conflict = (msg: string) => new HttpError(409, "conflict", msg);
/** Used when an external dependency (Supabase / Deepgram / provider key) is unconfigured. */
export const unavailable = (msg: string) => new HttpError(503, "service_unavailable", msg);

function envelope(code: string, message: string, requestId: string, details?: unknown): ApiError {
  const err: ApiError["error"] = { code, message, requestId };
  if (details !== undefined) err.details = details;
  return { error: err };
}

export function registerErrorHandler(app: FastifyInstance): void {
  app.setNotFoundHandler((req: FastifyRequest, reply: FastifyReply) => {
    reply.code(404).send(envelope("not_found", `No route for ${req.method} ${req.url}`, req.requestId));
  });

  app.setErrorHandler((error, req: FastifyRequest, reply: FastifyReply) => {
    const requestId = req.requestId;

    if (error instanceof HttpError) {
      if (error.statusCode >= 500) req.log.error({ err: error, requestId }, error.message);
      reply.code(error.statusCode).send(envelope(error.code, error.message, requestId, error.details));
      return;
    }

    // Body/params that failed contract validation.
    if (error instanceof ZodError) {
      reply.code(400).send(envelope("validation_error", "Request failed schema validation.", requestId, error.issues));
      return;
    }

    // Fastify's own validation (e.g. malformed JSON) carries a statusCode.
    const status = (error as { statusCode?: number }).statusCode;
    if (typeof status === "number" && status >= 400 && status < 500) {
      const message = error instanceof Error ? error.message : "Bad request";
      reply.code(status).send(envelope("bad_request", message, requestId));
      return;
    }

    req.log.error({ err: error, requestId }, "Unhandled error");
    reply.code(500).send(envelope("internal_error", "An unexpected error occurred.", requestId));
  });
}
