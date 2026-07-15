import "fastify";
import type { Deps } from "./deps.js";

/** The authenticated principal attached to a request after the auth plugin. */
export interface AuthUser {
  id: string;
  email?: string;
  isAdmin: boolean;
}

/** The resolved admin-panel operator, attached after adminPanelGuard runs. */
export interface AdminPrincipal {
  id: string;
  email: string;
  isAdmin: boolean;
}

declare module "fastify" {
  interface FastifyRequest {
    requestId: string;
    /** Present only after the auth plugin has run for a protected route. */
    user?: AuthUser;
    /** Present only after adminPanelGuard has run for an `admin_panel` route. */
    adminAccount?: AdminPrincipal;
  }
  interface FastifyInstance {
    deps: Deps;
  }
}
