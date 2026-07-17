import type { ZodType } from "zod";

/** The four generation tasks the product runs. Routing keys off these. */
export type AiTask = "book_grounding" | "plan_generation" | "quiz_generation" | "rewrite";

/** All AI providers the product can route to. */
export type ProviderName = "gemini" | "groq" | "openrouter" | "ai_tutor_api";

/** Runtime credentials + model handed to an adapter at construction time. */
export interface ProviderRuntimeConfig {
  apiKey: string;
  model: string;
}

export interface GenerateObjectOptions<T> {
  task: AiTask;
  /** Stable name for the schema — used for logging and Gemini responseSchema title. */
  schemaName: string;
  /** Zod schema. Output is validated against this before it is ever returned. */
  schema: ZodType<T>;
  system: string;
  user: string;
  /**
   * Task-specific named template variables for providers whose prompt template
   * lives platform-side (AI Tutor API). Providers that compose prompts from
   * system/user (Gemini/Groq/OpenRouter) ignore it.
   */
  variables?: Record<string, string>;
  /** Override the env default model. */
  model?: string;
  /** Hint the router to prefer the low-latency provider (Groq) when task allows. */
  preferLatency?: boolean;
  /** Force Google Search Grounding — implies Gemini. */
  requireGrounding?: boolean;
  /** Force schema-constrained output — implies Gemini (Groq Qwen has JSON mode only). */
  requireStrictSchema?: boolean;
}

/** A grounded source. Mirrors the citations shape used in the Zod contracts. */
export interface Citation {
  title: string;
  url: string;
  reason: string;
}

export interface AiObjectResult<T> {
  data: T;
  provider: ProviderName;
  model: string;
  citations: Citation[];
  /** How many provider calls it took to produce valid output (1 = first try). */
  attempts: number;
}

export interface AiTextResult {
  text: string;
  provider: ProviderName;
  model: string;
}

export interface GenerateTextOptions {
  task: AiTask;
  system: string;
  user: string;
  /**
   * Task-specific named template variables for providers whose prompt template
   * lives platform-side (AI Tutor API). Providers that compose prompts from
   * system/user (Gemini/Groq/OpenRouter) ignore it.
   */
  variables?: Record<string, string>;
  model?: string;
  preferLatency?: boolean;
}

export interface AiRouter {
  generateObject<T>(opts: GenerateObjectOptions<T>): Promise<AiObjectResult<T>>;
  generateText(opts: GenerateTextOptions): Promise<AiTextResult>;
}

/**
 * Low-level provider adapter. Adapters do the transport + parse to a raw JS
 * value + extract citations; the router owns routing and Zod validation.
 */
export interface ProviderAdapter {
  readonly name: ProviderName;
  /** Call the model, parse its JSON body, return the raw value + citations + model id. */
  generateObjectRaw(opts: GenerateObjectOptions<unknown>): Promise<{
    raw: unknown;
    citations: Citation[];
    model: string;
  }>;
  generateText(opts: GenerateTextOptions): Promise<AiTextResult>;
}

export interface AiTutorRuntimeConfig {
  apiKey: string;
  workflowIds: Partial<Record<AiTask, string>>;
}

/** What the router asks for on every call — always fresh (the settings-cache
 * layer underneath owns the ~30s TTL), so admin edits apply without a restart. */
export interface SettingsSnapshot {
  groq: ProviderRuntimeConfig;
  openrouter: ProviderRuntimeConfig;
  aiTutorApi: AiTutorRuntimeConfig;
  taskOverrides: Partial<Record<AiTask, ProviderName>>;
}

export interface SettingsReader {
  snapshot(): Promise<SettingsSnapshot>;
}
