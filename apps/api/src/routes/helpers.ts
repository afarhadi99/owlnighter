import type { FastifyInstance, FastifyReply, FastifyRequest, RouteHandlerMethod, preHandlerHookHandler } from "fastify";
import type { z } from "zod";
import { ENDPOINTS, type EndpointDef } from "@owlnighter/contracts";
import { adminGuard, userGuard } from "../plugins/auth.js";
import { adminPanelGuard } from "../plugins/admin-session.js";
import { badRequest } from "../plugins/errors.js";
import type { Deps } from "../deps.js";

/** Look up an endpoint definition by operationId (fails loudly if renamed). */
export function endpoint(operationId: string): EndpointDef {
  const ep = ENDPOINTS.find((e) => e.operationId === operationId);
  if (!ep) throw new Error(`Unknown operationId: ${operationId}`);
  return ep;
}

function guardFor(deps: Deps, auth: EndpointDef["auth"]): preHandlerHookHandler | undefined {
  if (auth === "user") return userGuard(deps) as preHandlerHookHandler;
  if (auth === "admin") return adminGuard(deps) as preHandlerHookHandler;
  if (auth === "admin_panel") return adminPanelGuard(deps) as preHandlerHookHandler;
  return undefined;
}

/**
 * Register a route from its contract definition. The path/method/auth all come
 * from the ENDPOINTS registry so the server cannot drift from the OpenAPI spec.
 * The body is validated with the endpoint's request schema before the handler
 * runs, and the handler returns a typed value that Fastify serialises.
 */
export function register<Req, Res>(
  app: FastifyInstance,
  deps: Deps,
  operationId: string,
  handler: (ctx: { req: FastifyRequest; reply: FastifyReply; body: Req; params: Record<string, string> }) => Promise<Res>,
): void {
  const ep = endpoint(operationId);
  const guard = guardFor(deps, ep.auth);
  const requestSchema = ep.request as z.ZodType<Req> | undefined;

  const routeHandler: RouteHandlerMethod = async (req, reply) => {
    let body: Req = undefined as Req;
    if (requestSchema) {
      const parsed = requestSchema.safeParse(req.body ?? {});
      if (!parsed.success) throw badRequest("Request failed schema validation.", parsed.error.issues);
      body = parsed.data;
    }
    const params = (req.params ?? {}) as Record<string, string>;
    const result = await handler({ req, reply, body, params });
    // Endpoints with no response schema return 204 (e.g. push/register).
    if (ep.response === undefined) {
      reply.code(204).send();
      return;
    }
    return result;
  };

  app.route({
    method: ep.method.toUpperCase() as "GET" | "POST" | "PUT" | "DELETE",
    url: ep.path,
    ...(guard ? { preHandler: guard } : {}),
    handler: routeHandler,
  });
}
