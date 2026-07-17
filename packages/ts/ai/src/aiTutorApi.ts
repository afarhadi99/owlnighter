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
 * workflow_id (ai_provider.ai_tutor_api.workflow_id.* settings).
 *
 * The adapter is task-agnostic about the request body: it sends `opts.variables`
 * (a flat named-variable map) verbatim when a task supplies one — its dedicated
 * templated workflow interpolates those {{names}} platform-side — and otherwise
 * falls back to the generic `{ system, user }` body that the generic
 * `{{system}}\n\n{{user}}` passthrough workflow expects. Quiz generation uses the
 * variable-map path; tasks not yet migrated to a templated workflow (e.g. rewrite)
 * keep working via the fallback.
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
    body: Record<string, string>,
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
      // manage-prompt run route source (`inputValues: body`). `body` is either
      // a task's named-variable map or the generic { system, user } fallback
      // (see requestBody); the endpoint treats both the same way.
      body: JSON.stringify(body),
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
    const { result, citations } = await this.run(workflowId, requestBody(opts));
    if (typeof result !== "string") throw new Error("AI Tutor API result was not a JSON string.");
    return { raw: JSON.parse(result), citations, model: `ai_tutor_api:${workflowId}` };
  }

  async generateText(opts: GenerateTextOptions): Promise<AiTextResult> {
    const workflowId = this.workflowIdFor(opts.task);
    const { result } = await this.run(workflowId, requestBody(opts));
    const text = decodeTextResult(result);
    return { text, provider: "ai_tutor_api", model: `ai_tutor_api:${workflowId}` };
  }
}

/**
 * The flat request body the run endpoint interpolates into the workflow
 * template. Prefer a task's named-variable map (used by templated workflows
 * such as quiz generation); fall back to the generic { system, user } body for
 * tasks whose workflow is still the `{{system}}\n\n{{user}}` passthrough.
 */
function requestBody(opts: { variables?: Record<string, string>; system: string; user: string }): Record<string, string> {
  if (opts.variables && Object.keys(opts.variables).length > 0) return opts.variables;
  return { system: opts.system, user: opts.user };
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
