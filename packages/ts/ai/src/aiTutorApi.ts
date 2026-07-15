import type {
  AiTextResult,
  AiTutorRuntimeConfig,
  Citation,
  GenerateObjectOptions,
  GenerateTextOptions,
  ProviderAdapter,
} from "./types.js";

const BASE = "https://aitutor-api.vercel.app/api/v1/run";

/**
 * AiTutorApiAdapter — runs a pre-created "workflow" on the caller's AI Tutor
 * API account. Each owlnighter AiTask maps to its own admin-configured
 * workflow_id (ai_provider.ai_tutor_api.workflow_id.* settings). The
 * workflow's `template` is a deliberately generic `{{system}}\n\n{{user}}`
 * passthrough — this adapter only ever forwards the same system/user strings
 * every other provider receives, so no per-task variable mapping lives here.
 */
export class AiTutorApiAdapter implements ProviderAdapter {
  readonly name = "ai_tutor_api" as const;

  constructor(private readonly config: AiTutorRuntimeConfig) {}

  private workflowIdFor(task: GenerateObjectOptions<unknown>["task"]): string {
    const id = this.config.workflowIds[task];
    if (!id) {
      throw new Error(
        `AI Tutor API has no workflow_id configured for task "${task}". Set it in the admin panel's AI Providers page.`,
      );
    }
    return id;
  }

  private async run(
    workflowId: string,
    system: string,
    user: string,
  ): Promise<{ result: unknown; citations: Citation[] }> {
    const res = await fetch(`${BASE}/${workflowId}`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${this.config.apiKey}`,
      },
      // The run endpoint uses the request body directly as its template
      // input values (flat object keyed by each input's declared name) —
      // NOT wrapped in an "inputs" envelope. Confirmed against the actual
      // manage-prompt run route source (`inputValues: body`).
      body: JSON.stringify({ system, user }),
    });
    if (!res.ok) {
      const rawDetail = await res.text().catch(() => "");
      const apiKey = this.config.apiKey;
      const detail = apiKey ? rawDetail.replaceAll(apiKey, "[redacted]") : rawDetail;
      throw new Error(`AI Tutor API run failed (${res.status}): ${detail.slice(0, 500)}`);
    }
    const json = (await res.json()) as AiTutorApiResponse;
    if (!json.success) throw new Error("AI Tutor API returned success: false.");
    const citations: Citation[] = (json.citations ?? []).map((c) => ({
      title: c.title ?? c.url ?? "source",
      url: c.url ?? "",
      reason: "Cited by AI Tutor API web search.",
    }));
    return { result: json.result, citations };
  }

  async generateObjectRaw(opts: GenerateObjectOptions<unknown>): Promise<{
    raw: unknown;
    citations: Citation[];
    model: string;
  }> {
    const workflowId = this.workflowIdFor(opts.task);
    const { result, citations } = await this.run(workflowId, opts.system, opts.user);
    if (typeof result !== "string") throw new Error("AI Tutor API result was not a JSON string.");
    return { raw: JSON.parse(result), citations, model: `ai_tutor_api:${workflowId}` };
  }

  async generateText(opts: GenerateTextOptions): Promise<AiTextResult> {
    const workflowId = this.workflowIdFor(opts.task);
    const { result } = await this.run(workflowId, opts.system, opts.user);
    const text = decodeTextResult(result);
    return { text, provider: "ai_tutor_api", model: `ai_tutor_api:${workflowId}` };
  }
}

/** Unwraps a JSON-encoded string `result` (the documented contract — e.g. a
 * rewrite workflow's result is `JSON.stringify("plain text")`) down to the
 * plain text callers expect. Falls back to the raw string unchanged if it
 * isn't valid JSON at all, so a workflow that already returns plain text
 * still works correctly instead of crashing. */
function decodeTextResult(result: unknown): string {
  if (typeof result !== "string") return JSON.stringify(result);
  try {
    const parsed = JSON.parse(result);
    return typeof parsed === "string" ? parsed : result;
  } catch {
    return result; // not JSON-encoded — already plain text, use as-is
  }
}

interface AiTutorApiResponse {
  success: boolean;
  result: string;
  citations?: Array<{ title?: string; url?: string }>;
}
