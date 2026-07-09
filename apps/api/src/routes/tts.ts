import type { FastifyInstance } from "fastify";
import { eq } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import { type EnsureTtsInput } from "@owlnighter/jobs";
import { type TtsGenerateRequest, type TtsGenerateResponse } from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { requireUser } from "../plugins/auth.js";
import { unavailable } from "../plugins/errors.js";
import { generateTtsAsset } from "../services/tts.js";
import { register } from "./helpers.js";

export function registerTtsRoutes(app: FastifyInstance, deps: Deps): void {
  register<TtsGenerateRequest, TtsGenerateResponse>(app, deps, "generateTts", async ({ req, body }) => {
    requireUser(req);

    // ensureTtsAsset owns the cache key (content hash of every param that changes
    // the audio), the cache lookup, the Deepgram synthesis, and the upload.
    const input: EnsureTtsInput = {
      text: body.text,
      voiceModel: body.voiceModel,
      locale: body.locale,
      ...(body.speakingRate != null ? { speakingRate: body.speakingRate } : {}),
    };

    const result = await generateTtsAsset(deps, input);
    // generateTtsAsset already 503s when unconfigured; this guards the union
    // exhaustively so a future "not_configured" path can't slip through as 200.
    if (result.status === "not_configured") throw unavailable(`TTS unavailable: ${result.reason}`);

    const a = result.asset;

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
      cached: result.status === "cached",
      storagePath: a.storagePath,
      ...(a.durationMs != null ? { durationMs: a.durationMs } : {}),
    };
  });
}
