import type {
  AiTextResult,
  Citation,
  GenerateObjectOptions,
  GenerateTextOptions,
  ProviderAdapter,
  ProviderRuntimeConfig,
} from "./types.js";
import { postChatCompletion } from "./openaiCompatible.js";

const ENDPOINT = "https://openrouter.ai/api/v1/chat/completions";

/**
 * OpenRouterAdapter — OpenAI-compatible chat completions. Uses the same
 * `json_object` response-format mode as GroqAdapter rather than OpenRouter's
 * model-dependent strict `json_schema` mode (not every routed model supports
 * it); the router's Zod safeParse + retry/fallback validates output exactly
 * like it does for Groq/Qwen today.
 */
export class OpenRouterAdapter implements ProviderAdapter {
  readonly name = "openrouter" as const;

  constructor(private readonly config: ProviderRuntimeConfig) {}

  async generateObjectRaw(opts: GenerateObjectOptions<unknown>): Promise<{
    raw: unknown;
    citations: Citation[];
    model: string;
  }> {
    const model = opts.model ?? this.config.model;
    const system = `${opts.system}\n\nRespond with a single valid JSON object only. No prose, no markdown fences.`;

    const json = await postChatCompletion(
      ENDPOINT,
      this.config.apiKey,
      {
        model,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: system },
          { role: "user", content: opts.user },
        ],
      },
      "OpenRouter generateObject",
    );
    const content = json.choices?.[0]?.message?.content ?? "";
    if (!content.trim()) throw new Error("OpenRouter returned an empty message.");
    return { raw: JSON.parse(content), citations: [], model };
  }

  async generateText(opts: GenerateTextOptions): Promise<AiTextResult> {
    const model = opts.model ?? this.config.model;
    const json = await postChatCompletion(
      ENDPOINT,
      this.config.apiKey,
      {
        model,
        messages: [
          { role: "system", content: opts.system },
          { role: "user", content: opts.user },
        ],
      },
      "OpenRouter generateText",
    );
    const text = json.choices?.[0]?.message?.content ?? "";
    return { text, provider: "openrouter", model };
  }
}
