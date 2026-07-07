import type { Env } from "@owlnighter/shared";
import type {
  Citation,
  GenerateObjectOptions,
  GenerateTextOptions,
  ProviderAdapter,
  AiTextResult,
} from "./types.js";

const ENDPOINT = "https://api.groq.com/openai/v1/chat/completions";

/**
 * GroqAdapter — OpenAI-compatible chat completions.
 *
 * IMPORTANT: uses JSON *object* mode (`response_format: { type: "json_object" }`),
 * NOT strict Structured Outputs. Qwen 3.6 on Groq does not support strict
 * schema-constrained outputs, so the router MUST validate + retry app-side.
 * Groq has no native grounding, so it never returns citations here.
 */
export class GroqAdapter implements ProviderAdapter {
  readonly name = "groq" as const;

  constructor(private readonly env: Env) {}

  private modelFor(override?: string): string {
    return override ?? this.env.GROQ_MODEL;
  }

  private headers(): Record<string, string> {
    return {
      "content-type": "application/json",
      authorization: `Bearer ${this.env.GROQ_API_KEY}`,
    };
  }

  async generateObjectRaw(opts: GenerateObjectOptions<unknown>): Promise<{
    raw: unknown;
    citations: Citation[];
    model: string;
  }> {
    const model = this.modelFor(opts.model);
    // The word "JSON" must appear in the prompt for json_object mode; make it explicit.
    const system = `${opts.system}\n\nRespond with a single valid JSON object only. No prose, no markdown fences.`;

    const res = await fetch(ENDPOINT, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify({
        model,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: system },
          { role: "user", content: opts.user },
        ],
      }),
    });
    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      throw new Error(`Groq generateObject failed (${res.status}): ${detail.slice(0, 500)}`);
    }
    const json = (await res.json()) as GroqResponse;
    const content = json.choices?.[0]?.message?.content ?? "";
    if (!content.trim()) throw new Error("Groq returned an empty message.");
    return { raw: JSON.parse(content), citations: [], model };
  }

  async generateText(opts: GenerateTextOptions): Promise<AiTextResult> {
    const model = this.modelFor(opts.model);
    const res = await fetch(ENDPOINT, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: opts.system },
          { role: "user", content: opts.user },
        ],
      }),
    });
    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      throw new Error(`Groq generateText failed (${res.status}): ${detail.slice(0, 500)}`);
    }
    const json = (await res.json()) as GroqResponse;
    const text = json.choices?.[0]?.message?.content ?? "";
    return { text, provider: "groq", model };
  }
}

interface GroqResponse {
  choices?: Array<{ message?: { content?: string } }>;
}
