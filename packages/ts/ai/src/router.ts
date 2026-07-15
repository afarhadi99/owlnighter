import type { Env } from "@owlnighter/shared";
import { GeminiAdapter } from "./gemini.js";
import { GroqAdapter } from "./groq.js";
import { OpenRouterAdapter } from "./openrouter.js";
import { AiTutorApiAdapter } from "./aiTutorApi.js";
import type {
  AiObjectResult,
  AiRouter,
  AiTask,
  AiTextResult,
  GenerateObjectOptions,
  GenerateTextOptions,
  ProviderAdapter,
  ProviderName,
  SettingsReader,
} from "./types.js";

/** Only these two tasks may be reassigned via ai_provider.task_override.* —
 * book_grounding/plan_generation keep their hardcoded Gemini-first routing
 * (native Search Grounding and schema-strictness are Gemini-only capabilities
 * today; reassigning those tasks would silently break the honesty guarantees
 * the rest of the app depends on). */
const TASK_OVERRIDABLE: ReadonlySet<AiTask> = new Set(["quiz_generation", "rewrite"]);

/** Exported (but not re-exported from index.ts, so it stays out of the
 * package's public API) purely so router.test.ts can unit-test the
 * override-eligibility guard directly, independent of the requireGrounding
 * short-circuit above it and of generateObject's own upstream filtering. */
export function preferredProvider(
  opts: { task: AiTask; requireGrounding?: boolean; requireStrictSchema?: boolean },
  taskOverride: ProviderName | undefined,
): ProviderName {
  if (opts.requireGrounding || opts.requireStrictSchema) return "gemini";
  if (taskOverride && TASK_OVERRIDABLE.has(opts.task)) return taskOverride;
  switch (opts.task) {
    case "book_grounding":
    case "plan_generation":
      return "gemini";
    case "rewrite":
    case "quiz_generation":
      return "groq";
    default:
      return "gemini";
  }
}

export function createAiRouter(env: Env, settings: SettingsReader): AiRouter {
  const gemini = new GeminiAdapter(env);

  async function adapterFor(name: ProviderName): Promise<{ adapter: ProviderAdapter; configured: boolean }> {
    switch (name) {
      case "gemini":
        return { adapter: gemini, configured: env.GEMINI_API_KEY.length > 0 };
      case "groq": {
        const snap = await settings.snapshot();
        const apiKey = snap.groq.apiKey || env.GROQ_API_KEY;
        const model = snap.groq.model || env.GROQ_MODEL;
        return { adapter: new GroqAdapter({ apiKey, model }), configured: apiKey.length > 0 };
      }
      case "openrouter": {
        const snap = await settings.snapshot();
        return {
          adapter: new OpenRouterAdapter({ apiKey: snap.openrouter.apiKey, model: snap.openrouter.model }),
          configured: snap.openrouter.apiKey.length > 0 && snap.openrouter.model.length > 0,
        };
      }
      case "ai_tutor_api": {
        const snap = await settings.snapshot();
        return {
          adapter: new AiTutorApiAdapter({ apiKey: snap.aiTutorApi.apiKey, workflowIds: snap.aiTutorApi.workflowIds }),
          configured: snap.aiTutorApi.apiKey.length > 0,
        };
      }
      default: {
        const _exhaustive: never = name;
        throw new Error(`Unknown provider: ${_exhaustive}`);
      }
    }
  }

  /** Whatever the preferred provider is, fall back to Gemini once if it isn't
   * itself Gemini. Generalizes the original 2-provider behavior (a Groq-first
   * call falls back to Gemini; a Gemini-first call never falls back) to 4
   * providers without changing that semantic. */
  function order(pref: ProviderName): ProviderName[] {
    return pref === "gemini" ? ["gemini"] : [pref, "gemini"];
  }

  return {
    async generateObject<T>(opts: GenerateObjectOptions<T>): Promise<AiObjectResult<T>> {
      const snap = await settings.snapshot();
      const override = TASK_OVERRIDABLE.has(opts.task) ? snap.taskOverrides[opts.task] : undefined;
      const pref = preferredProvider(opts, override);

      let attempts = 0;
      let lastError: unknown;
      let triedAny = false;

      for (const providerName of order(pref)) {
        const { adapter, configured } = await adapterFor(providerName);
        if (!configured) continue;
        triedAny = true;
        const maxTriesHere = providerName === pref ? 2 : 1;
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

      if (!triedAny) {
        throw new Error(
          "No AI provider is configured for this task. Configure a provider's API key in the admin panel's AI Providers page or the environment.",
        );
      }
      throw new Error(
        `generateObject exhausted providers for "${opts.schemaName}". Last error: ` +
          (lastError instanceof Error ? lastError.message : String(lastError)),
      );
    },

    async generateText(opts: GenerateTextOptions): Promise<AiTextResult> {
      const snap = await settings.snapshot();
      const override = TASK_OVERRIDABLE.has(opts.task) ? snap.taskOverrides[opts.task] : undefined;
      const pref = preferredProvider({ task: opts.task }, override);
      for (const name of order(pref)) {
        const { adapter, configured } = await adapterFor(name);
        if (configured) return adapter.generateText(opts);
      }
      throw new Error(
        "No AI provider key configured. Set GEMINI_API_KEY and/or GROQ_API_KEY, or configure a provider in the admin panel.",
      );
    },
  };
}
