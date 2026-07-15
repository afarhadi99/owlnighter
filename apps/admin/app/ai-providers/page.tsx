import { api, ApiRequestError } from "@/lib/api";
import type { AdminSettingRow } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { ProviderCard } from "./ProviderCard";
import { ModelCatalogTable } from "./ModelCatalogTable";
import { DefaultProviderCard } from "./DefaultProviderCard";

export default async function AiProvidersPage() {
  let rows: AdminSettingRow[] = [];
  let error: string | null = null;
  try {
    const res = await api.adminGetSettings();
    rows = res.settings;
  } catch (err) {
    error =
      err instanceof ApiRequestError
        ? `${err.status}: ${err.body?.error.message ?? err.message}`
        : (err as Error).message;
  }
  const byKey = new Map(rows.map((r) => [r.key, r]));
  const str = (key: string) => (typeof byKey.get(key)?.value === "string" ? (byKey.get(key)!.value as string) : "");
  const configured = (key: string) => byKey.get(key)?.configured ?? false;

  return (
    <div>
      <PageHeader
        title="AI Providers"
        subtitle="Admin-managed keys, models, and per-task system prompts for Groq, OpenRouter, and AI Tutor API."
      />
      {error ? (
        <div className="mb-4 rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">{error}</div>
      ) : null}

      <DefaultProviderCard
        defaultProvider={str("ai_provider.default") || "ai_tutor_api"}
        quizOverride={str("ai_provider.task_override.quiz_generation")}
        rewriteOverride={str("ai_provider.task_override.rewrite")}
      />

      <ProviderCard
        title="Groq"
        fields={[
          {
            key: "ai_provider.groq.api_key",
            label: "API key",
            type: "password",
            placeholder: configured("ai_provider.groq.api_key") ? "•••• configured" : "not set",
          },
          { key: "ai_provider.groq.model", label: "Model", type: "text", defaultValue: str("ai_provider.groq.model") },
          {
            key: "ai_provider.groq.system_prompt.plan_generation",
            label: "System prompt — plan generation (blank = built-in default)",
            type: "textarea",
            defaultValue: str("ai_provider.groq.system_prompt.plan_generation"),
          },
          {
            key: "ai_provider.groq.system_prompt.quiz_generation",
            label: "System prompt — quiz generation (blank = built-in default)",
            type: "textarea",
            defaultValue: str("ai_provider.groq.system_prompt.quiz_generation"),
          },
        ]}
      >
        <ModelCatalogTable provider="groq" />
      </ProviderCard>

      <ProviderCard
        title="OpenRouter"
        fields={[
          {
            key: "ai_provider.openrouter.api_key",
            label: "API key",
            type: "password",
            placeholder: configured("ai_provider.openrouter.api_key") ? "•••• configured" : "not set",
          },
          {
            key: "ai_provider.openrouter.model",
            label: "Model",
            type: "text",
            defaultValue: str("ai_provider.openrouter.model"),
            placeholder: "e.g. anthropic/claude-3.5-haiku",
          },
          {
            key: "ai_provider.openrouter.system_prompt.plan_generation",
            label: "System prompt — plan generation (blank = built-in default)",
            type: "textarea",
            defaultValue: str("ai_provider.openrouter.system_prompt.plan_generation"),
          },
          {
            key: "ai_provider.openrouter.system_prompt.quiz_generation",
            label: "System prompt — quiz generation (blank = built-in default)",
            type: "textarea",
            defaultValue: str("ai_provider.openrouter.system_prompt.quiz_generation"),
          },
        ]}
      >
        <ModelCatalogTable provider="openrouter" />
      </ProviderCard>

      <ProviderCard
        title="AI Tutor API"
        fields={[
          {
            key: "ai_provider.ai_tutor_api.api_key",
            label: "API key",
            type: "password",
            placeholder: configured("ai_provider.ai_tutor_api.api_key") ? "•••• configured" : "not set",
          },
          {
            key: "ai_provider.ai_tutor_api.workflow_id.book_grounding",
            label: "Workflow ID — book grounding",
            type: "text",
            defaultValue: str("ai_provider.ai_tutor_api.workflow_id.book_grounding"),
          },
          {
            key: "ai_provider.ai_tutor_api.workflow_id.plan_generation",
            label: "Workflow ID — plan generation",
            type: "text",
            defaultValue: str("ai_provider.ai_tutor_api.workflow_id.plan_generation"),
          },
          {
            key: "ai_provider.ai_tutor_api.workflow_id.quiz_generation",
            label: "Workflow ID — quiz generation",
            type: "text",
            defaultValue: str("ai_provider.ai_tutor_api.workflow_id.quiz_generation"),
          },
        ]}
      >
        <p className="mt-2 text-xs text-muted">
          Workflow IDs come from importing{" "}
          <code>docs/ai-tutor-workflows/quiz-generation-workflow.json</code> into your AI Tutor API console (see
          that folder&apos;s README).
        </p>
      </ProviderCard>
    </div>
  );
}
