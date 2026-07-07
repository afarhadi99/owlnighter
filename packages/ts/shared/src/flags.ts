/**
 * Feature flags. Deliberately dumb (env-driven booleans) until there's a real
 * need for a flag service — no speculative flag framework.
 */
export interface FeatureFlags {
  /** Allow Groq for quiz generation (falls back to Gemini on invalid output). */
  groqQuizGeneration: boolean;
  /** Enable Deepgram TTS pre-generation jobs. */
  ttsPregeneration: boolean;
  /** Enable the admin grounding review queue. */
  groundingReviewQueue: boolean;
}

export function resolveFlags(env: NodeJS.ProcessEnv = process.env): FeatureFlags {
  const on = (k: string, def: boolean) => {
    const v = env[k];
    return v === undefined ? def : v === "true" || v === "1";
  };
  return {
    groqQuizGeneration: on("FLAG_GROQ_QUIZ", true),
    ttsPregeneration: on("FLAG_TTS_PREGEN", true),
    groundingReviewQueue: on("FLAG_GROUNDING_REVIEW", true),
  };
}
