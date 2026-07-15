import { hasProviderKey, type Env } from "@owlnighter/shared";
import { GeminiAdapter } from "./gemini.js";
import { GroqAdapter } from "./groq.js";
import type {
  AiObjectResult,
  AiRouter,
  AiTextResult,
  GenerateObjectOptions,
  GenerateTextOptions,
  ProviderAdapter,
} from "./types.js";

// Interim: only Gemini and Groq are actually wired up in this router (both the
// `adapters` map and `hasProviderKey` are 2-way). A later task rewrites this
// function body to be settings-driven across all 4 ProviderName values.
type ProviderName = "gemini" | "groq";

/**
 * Deterministic routing per the blueprint table:
 *  - grounding / strict schema / book identification / plan generation → Gemini
 *  - rewrite / quiz_generation (facts already exist) → Groq first (fast), fall back to Gemini
 */
function preferredProvider(opts: {
  task: GenerateObjectOptions<unknown>["task"];
  preferLatency?: boolean;
  requireGrounding?: boolean;
  requireStrictSchema?: boolean;
}): ProviderName {
  if (opts.requireGrounding || opts.requireStrictSchema) return "gemini";
  switch (opts.task) {
    case "book_grounding":
    case "plan_generation":
      // Contract-critical + citation-bearing → Gemini owns these.
      return "gemini";
    case "rewrite":
    case "quiz_generation":
      // Latency-sensitive, validated app-side → Groq first.
      return "groq";
    default:
      return "gemini";
  }
}

export function createAiRouter(env: Env): AiRouter {
  const adapters: Record<"gemini" | "groq", ProviderAdapter> = {
    gemini: new GeminiAdapter(env),
    groq: new GroqAdapter({ apiKey: env.GROQ_API_KEY, model: env.GROQ_MODEL }),
  };

  /** Pick a provider that actually has a key, honoring the routing preference. */
  function resolveProvider(pref: ProviderName): ProviderName {
    if (hasProviderKey(env, pref)) return pref;
    const other: ProviderName = pref === "gemini" ? "groq" : "gemini";
    if (hasProviderKey(env, other)) return other;
    throw new Error(
      "No AI provider key configured. Set GEMINI_API_KEY and/or GROQ_API_KEY.",
    );
  }

  return {
    async generateObject<T>(opts: GenerateObjectOptions<T>): Promise<AiObjectResult<T>> {
      const pref = preferredProvider(opts);
      const start = resolveProvider(pref);

      let attempts = 0;
      let lastError: unknown;

      // Attempt order: try the chosen provider (with one retry), then — if we
      // started on Groq — fall back to Gemini. Never return unvalidated data.
      const order: ProviderName[] = start === "groq" ? ["groq", "gemini"] : ["gemini"];

      for (const providerName of order) {
        if (!hasProviderKey(env, providerName)) continue;
        const adapter = adapters[providerName];
        const maxTriesHere = providerName === start ? 2 : 1; // retry once on the primary
        for (let i = 0; i < maxTriesHere; i++) {
          attempts++;
          try {
            const { raw, citations, model } = await adapter.generateObjectRaw(
              opts as GenerateObjectOptions<unknown>,
            );
            const parsed = opts.schema.safeParse(raw);
            if (parsed.success) {
              return { data: parsed.data, provider: providerName, model, citations, attempts };
            }
            lastError = new Error(
              `Schema validation failed for "${opts.schemaName}" on ${providerName}: ` +
                parsed.error.issues.map((x) => x.path.join(".") + " " + x.message).join("; "),
            );
          } catch (err) {
            lastError = err;
          }
        }
      }

      throw new Error(
        `generateObject exhausted providers for "${opts.schemaName}". Last error: ` +
          (lastError instanceof Error ? lastError.message : String(lastError)),
      );
    },

    async generateText(opts: GenerateTextOptions): Promise<AiTextResult> {
      const pref = preferredProvider({ task: opts.task, preferLatency: opts.preferLatency });
      const provider = resolveProvider(pref);
      return adapters[provider].generateText(opts);
    },
  };
}
