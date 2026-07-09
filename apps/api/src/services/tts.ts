import { eq } from "drizzle-orm";
import type { SupabaseClient } from "@supabase/supabase-js";
import { schema } from "@owlnighter/db";
import {
  type EnsureTtsInput,
  type EnsureTtsResult,
  type TtsRepo,
  type TtsStorage,
} from "@owlnighter/jobs";
import type { Deps } from "../deps.js";
import { unavailable } from "../plugins/errors.js";

/** Supabase Storage bucket holding generated TTS audio (bucket-relative paths). */
const TTS_BUCKET = "tts";

/** Real Supabase Storage upload seam for @owlnighter/jobs.ensureTtsAsset. */
function supabaseStorage(supabase: SupabaseClient): TtsStorage {
  return {
    async upload(path, bytes, contentType) {
      // upsert so a re-run after a partial failure overwrites rather than 409s.
      const { error } = await supabase.storage.from(TTS_BUCKET).upload(path, bytes, {
        contentType,
        upsert: true,
      });
      if (error) throw new Error(`Supabase Storage upload failed: ${error.message}`);
      return `${TTS_BUCKET}/${path}`;
    },
  };
}

/** tts_assets repo seam backed by the request's Drizzle client. */
function dbRepo(deps: Deps): TtsRepo {
  return {
    async findByKey(assetKey) {
      const rows = await deps.db
        .select()
        .from(schema.ttsAssets)
        .where(eq(schema.ttsAssets.assetKey, assetKey))
        .limit(1);
      const a = rows[0];
      if (!a) return undefined;
      return {
        id: a.id,
        assetKey: a.assetKey,
        provider: a.provider,
        voiceModel: a.voiceModel,
        locale: a.locale,
        storagePath: a.storagePath,
        durationMs: a.durationMs,
      };
    },
    async insert(row) {
      const inserted = await deps.db.insert(schema.ttsAssets).values(row).returning();
      const a = inserted[0]!;
      return {
        id: a.id,
        assetKey: a.assetKey,
        provider: a.provider,
        voiceModel: a.voiceModel,
        locale: a.locale,
        storagePath: a.storagePath,
        durationMs: a.durationMs,
      };
    },
  };
}

/**
 * Cache-first TTS generation. Delegates hashing/dedupe/Deepgram synthesis/upload
 * to @owlnighter/jobs.ensureTtsAsset, injecting real Supabase Storage + DB seams.
 * Degrades with a 503 when Deepgram or Supabase is unconfigured — never fakes a
 * success.
 */
export async function generateTtsAsset(deps: Deps, input: EnsureTtsInput): Promise<EnsureTtsResult> {
  if (deps.config.env.DEEPGRAM_API_KEY.length === 0) {
    throw unavailable("TTS unavailable: DEEPGRAM_API_KEY is not configured.");
  }
  if (!deps.supabase) {
    throw unavailable("TTS unavailable: Supabase Storage is not configured.");
  }

  // deps.ensureTtsAsset is the real jobs export (typeof ensureTtsAsset), so this
  // call is fully type-checked — no structural casts.
  return deps.ensureTtsAsset(
    {
      deepgramApiKey: deps.config.env.DEEPGRAM_API_KEY,
      storage: supabaseStorage(deps.supabase),
      repo: dbRepo(deps),
      logger: deps.config.logger,
    },
    input,
  );
}
