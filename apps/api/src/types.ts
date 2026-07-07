import "fastify";
import type { Deps } from "./deps.js";

/** The authenticated principal attached to a request after the auth plugin. */
export interface AuthUser {
  id: string;
  email?: string;
  isAdmin: boolean;
}

declare module "fastify" {
  interface FastifyRequest {
    requestId: string;
    /** Present only after the auth plugin has run for a protected route. */
    user?: AuthUser;
  }
  interface FastifyInstance {
    deps: Deps;
  }
}
