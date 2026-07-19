import { createAiSettingsReader } from "./ai-settings.js";
import type { Deps } from "../deps.js";

type AiTask = "book_grounding" | "plan_generation" | "quiz_generation" | "rewrite";

/**
 * Whether `task` can be served by at least one currently-configured provider,
 * mirroring the router's own per-provider "configured" check
 * (packages/ts/ai/src/router.ts's `adapterFor`) without duplicating the
 * router itself. Every task is provider-overridable — nothing is pinned to a
 * single provider — so callers use this for an early, specific 503 instead of
 * letting the router's generic "no provider configured" Error surface as a
 * bare 500.
 */
export async function isTaskConfigured(deps: Deps, task: AiTask): Promise<boolean> {
  if (deps.config.env.GEMINI_API_KEY.length > 0) return true;

  const snap = await createAiSettingsReader(deps.settings).snapshot();
  if ((snap.groq.apiKey || deps.config.env.GROQ_API_KEY).length > 0) return true;
  if (snap.openrouter.apiKey.length > 0 && snap.openrouter.model.length > 0) return true;
  if (snap.aiTutorApi.apiKey.length > 0 && Boolean(snap.aiTutorApi.workflowIds[task])) return true;

  return false;
}
