import type { AdminAiModelsResponse, AiModelInfo } from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { badRequest, unavailable } from "../plugins/errors.js";

interface GroqModelsResponse {
  data?: Array<{ id: string; context_window?: number }>;
}
interface OpenRouterModelsResponse {
  data?: Array<{
    id: string;
    name?: string;
    context_length?: number;
    pricing?: { prompt?: string; completion?: string };
    architecture?: { modality?: string };
  }>;
}

async function fetchGroqModels(apiKey: string): Promise<AiModelInfo[]> {
  if (!apiKey) throw unavailable("Groq model catalog unavailable: no Groq API key is configured.");
  const res = await fetch("https://api.groq.com/openai/v1/models", {
    headers: { authorization: `Bearer ${apiKey}` },
  });
  if (!res.ok) {
    const rawDetail = await res.text().catch(() => "");
    const detail = apiKey ? rawDetail.replaceAll(apiKey, "[redacted]") : rawDetail;
    throw unavailable(`Groq model catalog request failed (${res.status}): ${detail.slice(0, 500)}`);
  }
  const json = (await res.json()) as GroqModelsResponse;
  return (json.data ?? [])
    .map((m) => ({ id: m.id, name: m.id, contextLength: m.context_window }))
    .sort((a, b) => a.id.localeCompare(b.id));
}

async function fetchOpenRouterModels(): Promise<AiModelInfo[]> {
  const res = await fetch("https://openrouter.ai/api/v1/models");
  if (!res.ok) {
    const detail = await res.text().catch(() => "");
    throw unavailable(`OpenRouter model catalog request failed (${res.status}): ${detail.slice(0, 500)}`);
  }
  const json = (await res.json()) as OpenRouterModelsResponse;
  return (json.data ?? [])
    .map((m) => ({
      id: m.id,
      name: m.name ?? m.id,
      ...(m.context_length != null ? { contextLength: m.context_length } : {}),
      ...(m.pricing ? { pricing: { prompt: m.pricing.prompt, completion: m.pricing.completion } } : {}),
      ...(m.architecture?.modality ? { modality: m.architecture.modality } : {}),
    }))
    .sort((a, b) => a.id.localeCompare(b.id));
}

export async function getAiModels(deps: Deps, provider: string | undefined): Promise<AdminAiModelsResponse> {
  if (provider !== "groq" && provider !== "openrouter") {
    throw badRequest('Query param "provider" must be "groq" or "openrouter".');
  }
  if (provider === "groq") {
    const apiKey = (await deps.settings.get("ai_provider.groq.api_key", "")) || deps.config.env.GROQ_API_KEY;
    return { provider, models: await fetchGroqModels(apiKey) };
  }
  return { provider, models: await fetchOpenRouterModels() };
}
