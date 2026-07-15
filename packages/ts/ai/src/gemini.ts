import { z } from "zod";
import type { Env } from "@owlnighter/shared";
import type {
  Citation,
  GenerateObjectOptions,
  GenerateTextOptions,
  ProviderAdapter,
  AiTextResult,
} from "./types.js";

const BASE = "https://generativelanguage.googleapis.com/v1beta/models";

/**
 * GeminiAdapter — talks to the Google Generative Language REST API.
 * Owns the two Gemini-only capabilities:
 *  - schema-constrained JSON (responseMimeType + responseSchema via z.toJSONSchema)
 *  - Google Search Grounding (google_search tool + groundingMetadata citations)
 */
export class GeminiAdapter implements ProviderAdapter {
  readonly name = "gemini" as const;

  constructor(private readonly env: Env) {}

  private modelFor(override?: string): string {
    return override ?? this.env.GEMINI_MODEL;
  }

  private endpoint(model: string): string {
    // API key in the query string is the documented v1beta auth for this API.
    return `${BASE}/${model}:generateContent?key=${encodeURIComponent(this.env.GEMINI_API_KEY)}`;
  }

  async generateObjectRaw(opts: GenerateObjectOptions<unknown>): Promise<{
    raw: unknown;
    citations: Citation[];
    model: string;
  }> {
    const model = this.modelFor(opts.model);

    const generationConfig: Record<string, unknown> = {
      responseMimeType: "application/json",
    };
    // Grounding and responseSchema are mutually awkward on some model builds, so
    // only attach the JSON schema via responseSchema when grounding is NOT
    // requested. When grounding IS on we instead inline the JSON Schema into the
    // prompt (so the model knows the exact property names) and validate app-side.
    const tools: unknown[] = [];
    let userText = opts.user;
    if (opts.requireGrounding) {
      tools.push({ google_search: {} });
      const shape = JSON.stringify(toGeminiSchema(opts.schema));
      userText +=
        "\n\nRespond with ONLY a JSON object that exactly conforms to this JSON Schema" +
        " — use the same property names, include all required properties, add no extra" +
        ` keys, and emit no markdown fences or prose:\n${shape}`;
    } else {
      generationConfig["responseSchema"] = toGeminiSchema(opts.schema);
    }

    const body = {
      systemInstruction: { parts: [{ text: opts.system }] },
      contents: [{ role: "user", parts: [{ text: userText }] }],
      generationConfig,
      ...(tools.length ? { tools } : {}),
    };

    const res = await fetch(this.endpoint(model), {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      const rawDetail = await res.text().catch(() => "");
      const detail = this.env.GEMINI_API_KEY
        ? rawDetail.replaceAll(this.env.GEMINI_API_KEY, "[redacted]")
        : rawDetail;
      throw new Error(`Gemini generateObject failed (${res.status}): ${detail.slice(0, 500)}`);
    }
    const json = (await res.json()) as GeminiResponse;
    const candidate = json.candidates?.[0];
    const text = candidate?.content?.parts?.map((p) => p.text ?? "").join("") ?? "";
    if (!text.trim()) throw new Error("Gemini returned an empty candidate.");

    const raw = parseJson(text);
    const citations = extractCitations(candidate?.groundingMetadata);
    return { raw, citations, model };
  }

  async generateText(opts: GenerateTextOptions): Promise<AiTextResult> {
    const model = this.modelFor(opts.model);
    const body = {
      systemInstruction: { parts: [{ text: opts.system }] },
      contents: [{ role: "user", parts: [{ text: opts.user }] }],
    };
    const res = await fetch(this.endpoint(model), {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      const rawDetail = await res.text().catch(() => "");
      const detail = this.env.GEMINI_API_KEY
        ? rawDetail.replaceAll(this.env.GEMINI_API_KEY, "[redacted]")
        : rawDetail;
      throw new Error(`Gemini generateText failed (${res.status}): ${detail.slice(0, 500)}`);
    }
    const json = (await res.json()) as GeminiResponse;
    const text = json.candidates?.[0]?.content?.parts?.map((p) => p.text ?? "").join("") ?? "";
    return { text, provider: "gemini", model };
  }
}

/** Zod → JSON Schema, stripped to the subset Gemini's responseSchema accepts. */
function toGeminiSchema(schema: z.ZodType<unknown>): unknown {
  // Zod 4 native JSON Schema conversion. `io: "output"` keeps defaults/transform
  // shapes aligned with what we validate against on the way back.
  const js = z.toJSONSchema(schema, { io: "output", target: "draft-2020-12" });
  return stripUnsupported(js);
}

/**
 * Gemini's responseSchema rejects several JSON Schema keywords ($schema, additionalProperties,
 * const, format on some builds). Recursively drop them so the call doesn't 400.
 */
function stripUnsupported(node: unknown): unknown {
  if (Array.isArray(node)) return node.map(stripUnsupported);
  if (node && typeof node === "object") {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(node as Record<string, unknown>)) {
      if (k === "$schema" || k === "additionalProperties" || k === "$id" || k === "const") continue;
      out[k] = stripUnsupported(v);
    }
    return out;
  }
  return node;
}

function parseJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    // Grounded responses sometimes wrap JSON in prose or fences; salvage the object.
    const match = text.match(/\{[\s\S]*\}/);
    if (match) return JSON.parse(match[0]);
    throw new Error("Gemini response was not valid JSON.");
  }
}

/** Turn groundingMetadata web sources into our Citation shape. */
function extractCitations(meta: GroundingMetadata | undefined): Citation[] {
  const chunks = meta?.groundingChunks ?? [];
  const out: Citation[] = [];
  for (const c of chunks) {
    const web = c.web;
    if (!web?.uri) continue;
    out.push({
      title: web.title ?? web.uri,
      url: web.uri,
      reason: "Cited by Google Search Grounding.",
    });
  }
  return out;
}

// ---- Minimal response typings (only the fields we read) ----
interface GeminiResponse {
  candidates?: Array<{
    content?: { parts?: Array<{ text?: string }> };
    groundingMetadata?: GroundingMetadata;
  }>;
}
interface GroundingMetadata {
  groundingChunks?: Array<{ web?: { uri?: string; title?: string } }>;
}
