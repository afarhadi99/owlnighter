import type { FastifyInstance } from "fastify";
import type {
  AdminAccountActionResponse,
  AdminLoginRequest,
  AdminLoginResponse,
  AdminMeResponse,
  AdminPendingAccountsResponse,
  AdminSignupRequest,
  AdminSignupResponse,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { bearer, requireAdminAccount } from "../plugins/admin-session.js";
import { badRequest } from "../plugins/errors.js";
import { approveAccount, listPendingAccounts, login, logout, me, rejectAccount, signup } from "../services/admin-auth.js";
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

  register<never, AdminPendingAccountsResponse>(app, deps, "adminListPendingAccounts", async () => {
    return listPendingAccounts(deps);
  });

  register<never, AdminAccountActionResponse>(app, deps, "adminApproveAccount", async ({ req, params }) => {
    const admin = requireAdminAccount(req);
    const id = params["id"];
    if (!id) throw badRequest("Missing account id.");
    return approveAccount(deps, admin, id);
  });

  register<never, AdminAccountActionResponse>(app, deps, "adminRejectAccount", async ({ req, params }) => {
    const admin = requireAdminAccount(req);
    const id = params["id"];
    if (!id) throw badRequest("Missing account id.");
    return rejectAccount(deps, admin, id);
  });
}
