"use server";
import { revalidatePath } from "next/cache";
import { api, ApiRequestError } from "@/lib/api";
import type { AiModelInfo } from "@/lib/api";

export async function fetchModelsAction(provider: "groq" | "openrouter"): Promise<AiModelInfo[]> {
  const res = await api.adminGetAiModels(provider);
  return res.models;
}

export interface SaveProviderState {
  error?: string;
  success?: boolean;
}

/** Saves every field in a provider card in one submit (several settings keys
 * at once). A blank `*.api_key` field is skipped — never overwrite a
 * configured secret with an accidental empty value. */
export async function saveProviderAction(
  keys: string[],
  _prevState: SaveProviderState,
  formData: FormData,
): Promise<SaveProviderState> {
  try {
    for (const key of keys) {
      const raw = formData.get(key);
      if (key.endsWith(".api_key") && (!raw || String(raw).length === 0)) continue;
      await api.adminPutSetting(key, String(raw ?? ""));
    }
  } catch (err) {
    if (err instanceof ApiRequestError) return { error: err.body?.error.message ?? "Save failed." };
    return { error: "Save failed." };
  }
  revalidatePath("/ai-providers");
  return { success: true };
}

export async function saveDefaultProviderAction(
  _prevState: SaveProviderState,
  formData: FormData,
): Promise<SaveProviderState> {
  try {
    await api.adminPutSetting(
      "ai_provider.default",
      String(formData.get("ai_provider.default") ?? "ai_tutor_api"),
    );
    const quiz = String(formData.get("ai_provider.task_override.quiz_generation") ?? "");
    const rewrite = String(formData.get("ai_provider.task_override.rewrite") ?? "");
    // The registry validates these two keys as `AiProviderName.nullable()` —
    // `null` clears the override back to built-in routing. An empty string
    // would fail that schema's enum check, so an empty select value must be
    // converted to `null` here rather than sent as-is.
    await api.adminPutSetting("ai_provider.task_override.quiz_generation", quiz || null);
    await api.adminPutSetting("ai_provider.task_override.rewrite", rewrite || null);
  } catch (err) {
    if (err instanceof ApiRequestError) return { error: err.body?.error.message ?? "Save failed." };
    return { error: "Save failed." };
  }
  revalidatePath("/ai-providers");
  return { success: true };
}
