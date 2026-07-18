import type { ProviderName, SettingsReader, SettingsSnapshot } from "@owlnighter/ai";
import type { SettingsCache } from "@owlnighter/db";

/** Adapts the API's DB-backed SettingsCache into the shape packages/ts/ai
 * depends on, so the ai package never gains a dependency on packages/ts/db. */
export function createAiSettingsReader(settings: SettingsCache): SettingsReader {
  return {
    async snapshot(): Promise<SettingsSnapshot> {
      const [
        groqApiKey,
        groqModel,
        openrouterApiKey,
        openrouterModel,
        aiTutorApiKey,
        workflowBookGrounding,
        workflowPlanGeneration,
        workflowQuizGeneration,
        workflowRewrite,
        defaultProvider,
        groundingOverride,
        planOverride,
        quizOverride,
        rewriteOverride,
      ] = await Promise.all([
        settings.get("ai_provider.groq.api_key", ""),
        settings.get("ai_provider.groq.model", ""),
        settings.get("ai_provider.openrouter.api_key", ""),
        settings.get("ai_provider.openrouter.model", ""),
        settings.get("ai_provider.ai_tutor_api.api_key", ""),
        settings.get("ai_provider.ai_tutor_api.workflow_id.book_grounding", ""),
        settings.get("ai_provider.ai_tutor_api.workflow_id.plan_generation", ""),
        settings.get("ai_provider.ai_tutor_api.workflow_id.quiz_generation", ""),
        settings.get("ai_provider.ai_tutor_api.workflow_id.rewrite", ""),
        // The global default provider for any task without an explicit override.
        settings.get<ProviderName | null>("ai_provider.default", null),
        // Per-task overrides. Every task is overridable now that the router no
        // longer hardcodes grounding/plan to Gemini; grounding/plan override
        // keys are read defensively (they may not exist as settings yet — a
        // missing key just yields null and falls through to the default).
        settings.get<ProviderName | null>("ai_provider.task_override.book_grounding", null),
        settings.get<ProviderName | null>("ai_provider.task_override.plan_generation", null),
        settings.get<ProviderName | null>("ai_provider.task_override.quiz_generation", null),
        settings.get<ProviderName | null>("ai_provider.task_override.rewrite", null),
      ]);
      return {
        groq: { apiKey: groqApiKey, model: groqModel },
        openrouter: { apiKey: openrouterApiKey, model: openrouterModel },
        aiTutorApi: {
          apiKey: aiTutorApiKey,
          workflowIds: {
            book_grounding: workflowBookGrounding || undefined,
            plan_generation: workflowPlanGeneration || undefined,
            quiz_generation: workflowQuizGeneration || undefined,
            rewrite: workflowRewrite || undefined,
          },
        },
        ...(defaultProvider ? { default: defaultProvider } : {}),
        taskOverrides: {
          ...(groundingOverride ? { book_grounding: groundingOverride } : {}),
          ...(planOverride ? { plan_generation: planOverride } : {}),
          ...(quizOverride ? { quiz_generation: quizOverride } : {}),
          ...(rewriteOverride ? { rewrite: rewriteOverride } : {}),
        },
      };
    },
  };
}
