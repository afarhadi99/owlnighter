import type { z } from "zod";
import { getDb, type Db } from "@owlnighter/db";
import { createAiRouter } from "@owlnighter/ai";
import { ensureTtsAsset, createInMemoryQueue } from "@owlnighter/jobs";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { getConfig, type AppConfig } from "./config.js";

/**
 * Structural type for the AI router we build against (public API of
 * @owlnighter/ai). Declared locally so services can be strongly typed even
 * though we only know the router by its documented shape.
 */
export interface GenerateObjectResult<T> {
  data: T;
  provider: "gemini" | "groq" | "openrouter" | "ai_tutor_api";
  model: string;
  citations: Array<{ title: string; url: string; reason: string }>;
  attempts: number;
}

export interface GenerateObjectArgs<T> {
  task: "book_grounding" | "plan_generation" | "quiz_generation" | "rewrite";
  schemaName: string;
  schema: z.ZodType<T>;
  system: string;
  user: string;
  provider?: "gemini" | "groq" | "openrouter" | "ai_tutor_api";
  requireGrounding?: boolean;
  requireStrictSchema?: boolean;
}

export interface AiRouter {
  generateObject<T>(args: GenerateObjectArgs<T>): Promise<GenerateObjectResult<T>>;
  generateText(args: {
    task: string;
    system: string;
    user: string;
    provider?: "gemini" | "groq" | "openrouter" | "ai_tutor_api";
  }): Promise<{ text: string; provider: "gemini" | "groq" | "openrouter" | "ai_tutor_api"; model: string }>;
}

/** Everything a request handler might need, assembled once at boot. */
export interface Deps {
  config: AppConfig;
  db: Db;
  ai: AiRouter;
  supabase: SupabaseClient | undefined;
  ensureTtsAsset: typeof ensureTtsAsset;
}

let cached: Deps | undefined;

export function buildDeps(): Deps {
  if (cached) return cached;
  const config = getConfig();
  const { env } = config;

  const db = getDb(env.DATABASE_URL);

  // The AI router needs env for keys/models; cast the runtime factory result to
  // our structural interface (the package exposes exactly this surface).
  const ai = createAiRouter(env) as unknown as AiRouter;

  // Supabase client is only usable when a service-role key is configured. When
  // absent we leave it undefined and auth degrades to the dev path (guarded by
  // NODE_ENV) or fails closed with a clear error.
  const supabase =
    env.SUPABASE_URL && env.SUPABASE_SERVICE_ROLE_KEY
      ? createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
          auth: { autoRefreshToken: false, persistSession: false },
        })
      : undefined;

  // Warm the in-memory job queue so TTS/prefetch work has somewhere to land in
  // local dev (real deployments swap this for a durable queue in @owlnighter/jobs).
  createInMemoryQueue();

  cached = { config, db, ai, supabase, ensureTtsAsset };
  return cached;
}
