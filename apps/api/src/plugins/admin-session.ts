import type { FastifyReply, FastifyRequest } from "fastify";
import { eq } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import type { Deps } from "../deps.js";
import { hashToken } from "../utils/admin-crypto.js";
import { unauthorized } from "./errors.js";
import type { AdminPrincipal } from "../types.js";

function bearer(req: FastifyRequest): string | undefined {
  const header = req.headers.authorization;
  if (!header) return undefined;
  const [scheme, token] = header.split(" ");
  if (!scheme || scheme.toLowerCase() !== "bearer" || !token) return undefined;
  return token;
}

/** Resolve the admin-panel bearer token into an AdminPrincipal, or throw 401. */
export async function resolveAdmin(deps: Deps, req: FastifyRequest): Promise<AdminPrincipal> {
  const token = bearer(req);
  if (!token) throw unauthorized("Missing admin session token.");

  const sessionRows = await deps.db
    .select({ adminAccountId: schema.adminSessions.adminAccountId, expiresAt: schema.adminSessions.expiresAt })
    .from(schema.adminSessions)
    .where(eq(schema.adminSessions.tokenHash, hashToken(token)))
    .limit(1);
  const session = sessionRows[0];
  if (!session) throw unauthorized("Invalid admin session.");
  if (session.expiresAt.getTime() <= Date.now()) throw unauthorized("Admin session expired.");

  const accountRows = await deps.db
    .select({ id: schema.adminAccounts.id, email: schema.adminAccounts.email, isAdmin: schema.adminAccounts.isAdmin, status: schema.adminAccounts.status })
    .from(schema.adminAccounts)
    .where(eq(schema.adminAccounts.id, session.adminAccountId))
    .limit(1);
  const account = accountRows[0];
  if (!account || account.status !== "approved" || !account.isAdmin) {
    throw unauthorized("Admin account is no longer active.");
  }

  return { id: account.id, email: account.email, isAdmin: account.isAdmin };
}

/** Guard for `auth: "admin_panel"` routes. Attaches req.adminAccount. */
export function adminPanelGuard(deps: Deps) {
  return async (req: FastifyRequest, _reply: FastifyReply): Promise<void> => {
    req.adminAccount = await resolveAdmin(deps, req);
  };
}

/** Convenience: assert req.adminAccount is present (routes run behind adminPanelGuard). */
export function requireAdminAccount(req: FastifyRequest): AdminPrincipal {
  if (!req.adminAccount) throw unauthorized();
  return req.adminAccount;
}
