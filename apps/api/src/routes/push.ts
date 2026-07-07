import type { FastifyInstance } from "fastify";
import { eq } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import { type PushRegisterRequest } from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { requireUser } from "../plugins/auth.js";
import { register } from "./helpers.js";

export function registerPushRoutes(app: FastifyInstance, deps: Deps): void {
  // No response schema → the helper replies 204 on success.
  register<PushRegisterRequest, void>(app, deps, "registerPushToken", async ({ req, body }) => {
    const user = requireUser(req);

    // Tokens are globally unique. Upsert on the token so re-registering from the
    // same device (or moving a device between users) updates the owner in place.
    const existing = await deps.db
      .select({ id: schema.pushTokens.id })
      .from(schema.pushTokens)
      .where(eq(schema.pushTokens.token, body.token))
      .limit(1);

    if (existing[0]) {
      await deps.db
        .update(schema.pushTokens)
        .set({
          userId: user.id,
          platform: body.platform,
          appVersion: body.appVersion ?? null,
          updatedAt: new Date(),
        })
        .where(eq(schema.pushTokens.id, existing[0].id));
    } else {
      await deps.db.insert(schema.pushTokens).values({
        userId: user.id,
        token: body.token,
        platform: body.platform,
        appVersion: body.appVersion ?? null,
      });
    }
  });
}
