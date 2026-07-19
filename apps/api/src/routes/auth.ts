import type { FastifyInstance } from "fastify";
import type {
  ActivateAccountRequest,
  ActivateAccountResponse,
  AuthStatusResponse,
  ValidateReferralCodeRequest,
  ValidateReferralCodeResponse,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { requireUser } from "../plugins/auth.js";
import { activateAccount, getAuthStatus, validateReferralCode } from "../services/referral.js";
import { register } from "./helpers.js";

export function registerAuthRoutes(app: FastifyInstance, deps: Deps): void {
  register<ValidateReferralCodeRequest, ValidateReferralCodeResponse>(app, deps, "validateReferralCode", async ({ body }) => {
    return validateReferralCode(deps, body);
  });

  register<never, AuthStatusResponse>(app, deps, "getAuthStatus", async ({ req }) => {
    return getAuthStatus(deps, requireUser(req));
  });

  register<ActivateAccountRequest, ActivateAccountResponse>(app, deps, "activateAccount", async ({ req, body }) => {
    return activateAccount(deps, requireUser(req), body);
  });
}
