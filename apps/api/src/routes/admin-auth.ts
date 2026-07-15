import type { FastifyInstance } from "fastify";
import type {
  AdminLoginRequest,
  AdminLoginResponse,
  AdminMeResponse,
  AdminSignupRequest,
  AdminSignupResponse,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { bearer, requireAdminAccount } from "../plugins/admin-session.js";
import { badRequest } from "../plugins/errors.js";
import { login, logout, me, signup } from "../services/admin-auth.js";
import { register } from "./helpers.js";

export function registerAdminAuthRoutes(app: FastifyInstance, deps: Deps): void {
  register<AdminSignupRequest, AdminSignupResponse>(app, deps, "adminSignup", async ({ body }) => {
    return signup(deps, body);
  });

  register<AdminLoginRequest, AdminLoginResponse>(app, deps, "adminLogin", async ({ body }) => {
    return login(deps, body);
  });

  register<never, void>(app, deps, "adminLogout", async ({ req }) => {
    const token = bearer(req);
    if (!token) throw badRequest("Missing bearer token.");
    await logout(deps, token);
  });

  register<never, AdminMeResponse>(app, deps, "adminMe", async ({ req }) => {
    return me(requireAdminAccount(req));
  });
}
