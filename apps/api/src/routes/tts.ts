import type { FastifyInstance } from "fastify";
import { eq } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import { contentHash } from "@owlnighter/shared";
import { type TtsGenerateRequest, type TtsGenerateResponse } from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { requireUser } from "../plugins/auth.js";
import { notFound, unavailable } from "../plugins/errors.js";
import { register } from "./helpers.js";

export function registerTtsRoutes(app: FastifyInstance, deps: Deps): void {
  register<TtsGenerateRequest, TtsGenerateResponse>(app, deps, "generateTts", async ({ req, body }) => {
    requireUser(req);

    // Cache key: provider + voice + rate + locale + normalized text. Identical
    // requests dedupe to one generated asset (see @owlnighter/jobs.ensureTtsAsset).
    const assetKey = contentHash([
      "deepgram",
      body.voiceModel,
      body.speakingRate ?? 1,
      body.locale,
      body.text.trim(),
    ]);

    // Fast path: already generated.
    const existing = await deps.db
      .select()
      .from(schema.ttsAssets)
      .where(eq(schema.ttsAssets.assetKey, assetKey))
      .limit(1);
    if (existing[0]) {
      const a = existing[0];
      return {
        assetId: a.id,
        assetKey: a.assetKey,
        cached: true,
        storagePath: a.storagePath,
        ...(a.durationMs != null ? { durationMs: a.durationMs } : {}),
      };
    }

    // Generation needs a Deepgram key. Degrade with a clear error rather than
    // returning a fake success.
    if (deps.config.env.DEEPGRAM_API_KEY.length === 0) {
      throw unavailable("TTS unavailable: DEEPGRAM_API_KEY is not configured.");
    }

    // Delegate real generation + storage upload + metadata persistence to the
    // jobs package. It returns the persisted asset row.
    const asset = await deps.ensureTtsAsset(deps as never, {
      assetKey,
      text: body.text,
      voiceModel: body.voiceModel,
      ...(body.speakingRate != null ? { speakingRate: body.speakingRate } : {}),
      locale: body.locale,
      ...(body.stepId ? { stepId: body.stepId } : {}),
    } as never);

    const a = asset as unknown as {
      id: string;
      assetKey: string;
      storagePath: string;
      durationMs?: number | null;
    };
    if (!a?.id) throw notFound("TTS asset generation returned no asset.");

    // Link the asset to a plan step for prefetch, if requested.
    if (body.stepId) {
      await deps.db
        .update(schema.readingPlanSteps)
        .set({ ttsAssetId: a.id })
        .where(eq(schema.readingPlanSteps.id, body.stepId));
    }

    return {
      assetId: a.id,
      assetKey: a.assetKey,
      cached: false,
      storagePath: a.storagePath,
      ...(a.durationMs != null ? { durationMs: a.durationMs } : {}),
    };
  });
}
