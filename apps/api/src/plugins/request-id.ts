import type { FastifyInstance } from "fastify";
import { newRequestId } from "@owlnighter/shared";

/**
 * Attach a stable request id to every request and echo it back in a header.
 * Clients log this id; the error envelope also carries it so a failing call is
 * traceable end-to-end. We honour an inbound `x-request-id` when present.
 */
export function registerRequestId(app: FastifyInstance): void {
  app.addHook("onRequest", async (req, reply) => {
    const inbound = req.headers["x-request-id"];
    const id = typeof inbound === "string" && inbound.length > 0 ? inbound : newRequestId();
    req.requestId = id;
    reply.header("x-request-id", id);
  });
}
