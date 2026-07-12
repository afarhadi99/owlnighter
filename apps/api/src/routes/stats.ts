import type { FastifyInstance } from "fastify";
import { type MyStatsResponse } from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { requireUser } from "../plugins/auth.js";
import { getMyStats } from "../services/stats.js";
import { register } from "./helpers.js";

export function registerStatsRoutes(app: FastifyInstance, deps: Deps): void {
  register<undefined, MyStatsResponse>(app, deps, "getMyStats", async ({ req }) => {
    const user = requireUser(req);
    return getMyStats(deps, user);
  });
}
