import type { FastifyInstance } from "fastify";
import { and, desc, eq } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import { type StepStartResponse } from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { requireUser } from "../plugins/auth.js";
import { badRequest, notFound } from "../plugins/errors.js";
import { register } from "./helpers.js";

export function registerStepRoutes(app: FastifyInstance, deps: Deps): void {
  // Opening a step creates its reading session up front. Previously a session
  // only appeared when a quiz was passed, so a started-but-unfinished reading
  // had no record. This closes that gap.
  register<never, StepStartResponse>(app, deps, "startStep", async ({ req, params }) => {
    const user = requireUser(req);
    const stepId = params["id"];
    if (!stepId) throw badRequest("Missing step id.");

    // The step must exist and belong to the caller (via its plan).
    const stepRows = await deps.db
      .select({ stepId: schema.readingPlanSteps.id, ownerId: schema.readingPlans.userId })
      .from(schema.readingPlanSteps)
      .innerJoin(schema.readingPlans, eq(schema.readingPlanSteps.planId, schema.readingPlans.id))
      .where(eq(schema.readingPlanSteps.id, stepId))
      .limit(1);
    const step = stepRows[0];
    if (!step || step.ownerId !== user.id) throw notFound("Step not found.");

    // Reuse an already-open session (idempotent start) rather than stacking rows.
    const open = await deps.db
      .select()
      .from(schema.readingSessions)
      .where(and(eq(schema.readingSessions.userId, user.id), eq(schema.readingSessions.stepId, stepId)))
      .orderBy(desc(schema.readingSessions.startedAt))
      .limit(1);
    if (open[0] && !open[0].completedAt) {
      return { sessionId: open[0].id, stepId, startedAt: open[0].startedAt.toISOString() };
    }

    const inserted = await deps.db
      .insert(schema.readingSessions)
      .values({ userId: user.id, stepId })
      .returning({ id: schema.readingSessions.id, startedAt: schema.readingSessions.startedAt });
    const row = inserted[0]!;
    return { sessionId: row.id, stepId, startedAt: row.startedAt.toISOString() };
  });
}
