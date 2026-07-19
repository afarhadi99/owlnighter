import type { FastifyInstance } from "fastify";
import type {
  AdminCreateReferralCodeRequest,
  AdminListReferralCodesResponse,
  AdminReferralCode,
  AdminUpdateReferralCodeRequest,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { requireAdminAccount } from "../plugins/admin-session.js";
import { badRequest } from "../plugins/errors.js";
import { adminCreateReferralCode, adminListReferralCodes, adminUpdateReferralCode } from "../services/referral.js";
import { register } from "./helpers.js";

export function registerAdminReferralRoutes(app: FastifyInstance, deps: Deps): void {
  register<never, AdminListReferralCodesResponse>(app, deps, "adminListReferralCodes", async () => {
    return adminListReferralCodes(deps);
  });

  register<AdminCreateReferralCodeRequest, AdminReferralCode>(app, deps, "adminCreateReferralCode", async ({ req, body }) => {
    const admin = requireAdminAccount(req);
    return adminCreateReferralCode(deps, admin, body);
  });

  register<AdminUpdateReferralCodeRequest, AdminReferralCode>(app, deps, "adminUpdateReferralCode", async ({ req, body, params }) => {
    requireAdminAccount(req);
    const id = params["id"];
    if (!id) throw badRequest("Missing referral code id.");
    return adminUpdateReferralCode(deps, id, body);
  });
}
