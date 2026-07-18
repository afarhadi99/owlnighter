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
  SettingsSnapshot,
} from "./types.js";

/** Global fallback used only when ai_provider.default has not been configured
 * yet. Not a task-specific lock: every task resolves through this same default
 * unless an explicit per-task override reassigns it. */
const DEFAULT_PROVIDER: ProviderName = "ai_tutor_api";

/** Every provider, in the canonical order used to build a task's fallback
 * chain after the preferred provider and Gemini. */
const ALL_PROVIDERS: readonly ProviderName[] = ["gemini", "groq", "openrouter", "ai_tutor_api"];

/**
 * Resolve which provider a task routes to: an explicit per-task override
 * (ai_provider.task_override.<task>) wins; otherwise the global default
 * (ai_provider.default); otherwise the DEFAULT_PROVIDER constant. No task is
 * hardcoded to a provider, and grounding/strict-schema requirements no longer
 * force Gemini here — grounding runs on whichever provider serves the task
 * (both Gemini and the AI Tutor API workflow support web-search grounding).
 *
 * Exported (but not re-exported from index.ts, so it stays out of the package's
 * public API) purely so router.test.ts can unit-test resolution directly.
 */
export function preferredProvider(
  task: AiTask,
  snap: Pick<SettingsSnapshot, "taskOverrides" | "default">,
): ProviderName {
  return snap.taskOverrides[task] ?? snap.default ?? DEFAULT_PROVIDER;
}

export function createAiRouter(env: Env, settings: SettingsReader): AiRouter {
  const gemini = new GeminiAdapter(env);

  /** Build a provider's adapter and decide whether it can STRUCTURALLY serve
   * `task` right now. A provider with no API key can't; ai_tutor_api
   * additionally can't serve a task that has no workflow_id configured (its
   * adapter would only throw "no workflow_id configured"). Task-aware so the
   * router can skip a provider that would inevitably fail — this is what lets
   * grounding fall back gracefully to Gemini when the AI Tutor grounding
   * workflow hasn't been set up yet. */
  async function adapterFor(
    name: ProviderName,
    task: AiTask,
  ): Promise<{ adapter: ProviderAdapter; configured: boolean }> {
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
          configured: snap.aiTutorApi.apiKey.length > 0 && Boolean(snap.aiTutorApi.workflowIds[task]),
        };
      }
      default: {
        const _exhaustive: never = name;
        throw new Error(`Unknown provider: ${_exhaustive}`);
      }
    }
  }

  /** The ordered fallback chain for a task: the resolved preferred provider
   * first, then Gemini, then every remaining provider. De-duplicated,
   * order-preserving. Providers that can't structurally serve the task are
   * skipped by the caller (via adapterFor's `configured`), so a task whose
   * preferred provider is ai_tutor_api-without-a-workflow_id degrades to
   * Gemini (then any other configured provider) instead of hard-failing. */
  function order(pref: ProviderName): ProviderName[] {
    return [...new Set<ProviderName>([pref, "gemini", ...ALL_PROVIDERS])];
  }

  return {
    async generateObject<T>(opts: GenerateObjectOptions<T>): Promise<AiObjectResult<T>> {
      const snap = await settings.snapshot();
      const pref = preferredProvider(opts.task, snap);

      let attempts = 0;
      let lastError: unknown;
      let triedAny = false;

      for (const providerName of order(pref)) {
        const { adapter, configured } = await adapterFor(providerName, opts.task);
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
      const pref = preferredProvider(opts.task, snap);
      for (const name of order(pref)) {
        const { adapter, configured } = await adapterFor(name, opts.task);
        if (configured) return adapter.generateText(opts);
      }
      throw new Error(
        "No AI provider key configured. Set GEMINI_API_KEY and/or GROQ_API_KEY, or configure a provider in the admin panel.",
      );
    },
  };
}
