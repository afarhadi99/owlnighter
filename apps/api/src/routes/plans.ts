import type { FastifyInstance } from "fastify";
import { type ListPlansResponse, type PlanGenerateRequest, type PlanResponse } from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { requireUser } from "../plugins/auth.js";
import { badRequest } from "../plugins/errors.js";
import { generatePlan, getPlan, listPlans } from "../services/plans.js";
import { register } from "./helpers.js";

export function registerPlanRoutes(app: FastifyInstance, deps: Deps): void {
  register<never, ListPlansResponse>(app, deps, "listPlans", async ({ req }) => {
    const user = requireUser(req);
    const bookId = (req.query as Record<string, string> | undefined)?.["bookId"];
    return listPlans(deps, user, bookId);
  });

  register<PlanGenerateRequest, PlanResponse>(app, deps, "generatePlan", async ({ req, body }) => {
    const user = requireUser(req);
    return generatePlan(deps, user, body);
  });

  register<never, PlanResponse>(app, deps, "getPlan", async ({ req, params }) => {
    const user = requireUser(req);
    const id = params["id"];
    if (!id) throw badRequest("Missing plan id.");
    return getPlan(deps, user, id);
  });
}
