import type { FastifyReply, FastifyRequest } from "fastify";
import { eq } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import type { Deps } from "../deps.js";
import { DEV_USER_ID } from "../config.js";
import { forbidden, unauthorized } from "./errors.js";
import type { AuthUser } from "../types.js";

/**
 * The DEV bearer. In development, a request with `Authorization: Bearer DEV`
 * (or `DEV:<uuid>` to impersonate a specific user) authenticates as a fixed dev
 * user WITHOUT contacting Supabase. This is the only way to exercise the API
 * locally before a Supabase project is wired up. It is hard-gated to
 * NODE_ENV==='development' so it can never authenticate in prod/test.
 */
const DEV_PREFIX = "DEV";

function bearer(req: FastifyRequest): string | undefined {
  const header = req.headers.authorization;
  if (!header) return undefined;
  const [scheme, token] = header.split(" ");
  if (!scheme || scheme.toLowerCase() !== "bearer" || !token) return undefined;
  return token;
}

async function isAdmin(deps: Deps, userId: string): Promise<boolean> {
  const rows = await deps.db
    .select({ isAdmin: schema.profiles.isAdmin })
    .from(schema.profiles)
    .where(eq(schema.profiles.id, userId))
    .limit(1);
  return rows[0]?.isAdmin ?? false;
}

/**
 * Resolve the caller into an AuthUser or throw. Shared by the `user` and
 * `admin` guards below. Verification order:
 *   1. dev bearer (development only)
 *   2. Supabase getUser(token)
 */
async function resolveUser(deps: Deps, req: FastifyRequest): Promise<AuthUser> {
  const token = bearer(req);
  if (!token) throw unauthorized();

  const isDev = deps.config.env.NODE_ENV === "development";
  if (isDev && (token === DEV_PREFIX || token.startsWith(`${DEV_PREFIX}:`))) {
    const impersonated = token.includes(":") ? token.slice(token.indexOf(":") + 1) : DEV_USER_ID;
    const id = impersonated.length > 0 ? impersonated : DEV_USER_ID;
    return { id, isAdmin: await isAdmin(deps, id) };
  }

  if (!deps.supabase) {
    // No dev token and no Supabase → we cannot verify anyone. Fail closed with a
    // clear message rather than pretending the request is authenticated.
    throw unauthorized(
      "Auth unavailable: Supabase is not configured. In development use `Authorization: Bearer DEV`.",
    );
  }

  const { data, error } = await deps.supabase.auth.getUser(token);
  if (error || !data.user) throw unauthorized("Invalid or expired token.");

  const user: AuthUser = {
    id: data.user.id,
    isAdmin: await isAdmin(deps, data.user.id),
  };
  if (data.user.email) user.email = data.user.email;
  return user;
}

/** Guard for `auth: "user"` routes. Attaches req.user. */
export function userGuard(deps: Deps) {
  return async (req: FastifyRequest, _reply: FastifyReply): Promise<void> => {
    req.user = await resolveUser(deps, req);
  };
}

/** Guard for `auth: "admin"` routes. Attaches req.user and enforces is_admin. */
export function adminGuard(deps: Deps) {
  return async (req: FastifyRequest, _reply: FastifyReply): Promise<void> => {
    const user = await resolveUser(deps, req);
    if (!user.isAdmin) throw forbidden();
    req.user = user;
  };
}

/** Convenience: assert req.user is present (routes run behind a guard). */
export function requireUser(req: FastifyRequest): AuthUser {
  if (!req.user) throw unauthorized();
  return req.user;
}
