import type {
  AiTextResult,
  AiTutorRuntimeConfig,
  Citation,
  GenerateObjectOptions,
  GenerateTextOptions,
  ProviderAdapter,
} from "./types.js";

/**
 * AiTutorApiAdapter — INTERIM STUB. A follow-up task replaces this with the
 * real implementation that calls https://aitutor-api.vercel.app/api/v1/run/{workflowId}.
 * This stub exists only so router.ts (which references this class) compiles;
 * it always throws if actually invoked, since it's never "configured" unless
 * an admin sets an AI Tutor API key (and even then, a real call would need
 * the real implementation, not this stub).
 */
export class AiTutorApiAdapter implements ProviderAdapter {
  readonly name = "ai_tutor_api" as const;

  constructor(private readonly config: AiTutorRuntimeConfig) {}

  async generateObjectRaw(_opts: GenerateObjectOptions<unknown>): Promise<{
    raw: unknown;
    citations: Citation[];
    model: string;
  }> {
    throw new Error(
      `AiTutorApiAdapter is not yet implemented (stub). workflowIds=${JSON.stringify(this.config.workflowIds)}`,
    );
  }

  async generateText(_opts: GenerateTextOptions): Promise<AiTextResult> {
    throw new Error(
      `AiTutorApiAdapter is not yet implemented (stub). workflowIds=${JSON.stringify(this.config.workflowIds)}`,
    );
  }
}
