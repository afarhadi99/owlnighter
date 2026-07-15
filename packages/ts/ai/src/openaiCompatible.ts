export interface OpenAiCompatibleResponse {
  choices?: Array<{ message?: { content?: string } }>;
}

/** Shared POST + error-handling shape for OpenAI-compatible chat-completions
 * endpoints (Groq, OpenRouter). Redacts the caller's own API key out of any
 * upstream error body before it's ever thrown/logged/returned to a client. */
export async function postChatCompletion(
  endpoint: string,
  apiKey: string,
  body: Record<string, unknown>,
  providerLabel: string,
): Promise<OpenAiCompatibleResponse> {
  const res = await fetch(endpoint, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${apiKey}` },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const rawDetail = await res.text().catch(() => "");
    const detail = apiKey ? rawDetail.replaceAll(apiKey, "[redacted]") : rawDetail;
    throw new Error(`${providerLabel} request failed (${res.status}): ${detail.slice(0, 500)}`);
  }
  return (await res.json()) as OpenAiCompatibleResponse;
}
