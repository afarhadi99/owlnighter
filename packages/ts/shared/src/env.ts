import { z } from "zod";

/**
 * Backend environment contract. Fails fast with a readable error if a required
 * secret is missing. Client apps NEVER import this — keys stay on the server.
 */
const EnvSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  API_HOST: z.string().default("0.0.0.0"),
  API_PORT: z.coerce.number().int().default(8787),
  API_PUBLIC_URL: z.string().default("http://localhost:8787"),
  LOG_LEVEL: z.enum(["fatal", "error", "warn", "info", "debug", "trace"]).default("info"),

  GEMINI_API_KEY: z.string().default(""),
  GEMINI_MODEL: z.string().default("gemini-3.5-flash"),
  GROQ_API_KEY: z.string().default(""),
  GROQ_MODEL: z.string().default("qwen-3.6-32b"),

  DEEPGRAM_API_KEY: z.string().default(""),
  DEEPGRAM_TTS_MODEL: z.string().default("aura-2-thalia-en"),

  SUPABASE_URL: z.string().default("http://127.0.0.1:54321"),
  SUPABASE_ANON_KEY: z.string().default(""),
  SUPABASE_SERVICE_ROLE_KEY: z.string().default(""),
  DATABASE_URL: z.string().default("postgresql://postgres:postgres@127.0.0.1:54322/postgres"),

  GOOGLE_BOOKS_API_KEY: z.string().default(""),
  OPEN_LIBRARY_BASE_URL: z.string().default("https://openlibrary.org"),

  FCM_PROJECT_ID: z.string().default(""),
  FCM_SERVICE_ACCOUNT_JSON: z.string().default(""),

  GROUNDING_AUTO_ACCEPT: z.coerce.number().min(0).max(1).default(0.85),
  GROUNDING_REVIEW_FLOOR: z.coerce.number().min(0).max(1).default(0.6),
});

export type Env = z.infer<typeof EnvSchema>;

let cached: Env | undefined;

/** Parse + cache process.env. Throws a readable aggregate error on misconfig. */
export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  if (cached) return cached;
  const parsed = EnvSchema.safeParse(source);
  if (!parsed.success) {
    const issues = parsed.error.issues.map((i) => `  - ${i.path.join(".")}: ${i.message}`);
    throw new Error(`Invalid environment:\n${issues.join("\n")}`);
  }
  cached = parsed.data;
  return cached;
}

/** Whether a provider key is actually configured. */
export function hasProviderKey(env: Env, provider: "gemini" | "groq"): boolean {
  return provider === "gemini" ? env.GEMINI_API_KEY.length > 0 : env.GROQ_API_KEY.length > 0;
}
