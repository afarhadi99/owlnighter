import { contentHash, type Logger } from "@owlnighter/shared";

/**
 * TTS pre-generation + caching.
 *
 * Policy (from the blueprint): generate on the backend only, key by a content
 * hash of every parameter that changes the audio, store once in Supabase
 * Storage, and reuse forever. Long text is chunked at sentence boundaries so
 * playback can start sooner. Never call Deepgram from the client.
 */

const DEEPGRAM_TTS_URL = "https://api.deepgram.com/v1/speak";
const TTS_PROVIDER = "deepgram";

export interface TtsAssetRow {
  id: string;
  assetKey: string;
  provider: string;
  voiceModel: string;
  locale: string;
  storagePath: string;
  durationMs: number | null;
}

export interface EnsureTtsInput {
  text: string;
  voiceModel: string; // e.g. "aura-2-thalia-en"
  speakingRate?: number;
  locale: string;
}

/** Storage seam — Supabase Storage upload. Kept abstract so jobs stay testable. */
export interface TtsStorage {
  /** Upload audio bytes, return the storage path (bucket-relative). */
  upload(path: string, bytes: Uint8Array, contentType: string): Promise<string>;
}

/** DB seam — only the two operations this job needs on tts_assets. */
export interface TtsRepo {
  findByKey(assetKey: string): Promise<TtsAssetRow | undefined>;
  insert(row: Omit<TtsAssetRow, "id">): Promise<TtsAssetRow>;
}

export interface TtsDeps {
  deepgramApiKey: string;
  storage: TtsStorage;
  repo: TtsRepo;
  logger?: Logger;
  /** Injectable for tests; defaults to global fetch. */
  fetchImpl?: typeof fetch;
}

export type EnsureTtsResult =
  | { status: "cached"; asset: TtsAssetRow }
  | { status: "generated"; asset: TtsAssetRow }
  | { status: "not_configured"; reason: string };

/** Stable cache key: any change to these inputs yields a new asset. */
export function ttsAssetKey(input: EnsureTtsInput): string {
  return contentHash([
    TTS_PROVIDER,
    input.voiceModel,
    input.speakingRate ?? 1,
    input.text,
    input.locale,
  ]);
}

/**
 * Split text into chunks no longer than `maxChars`, breaking at sentence
 * boundaries where possible. A single over-long sentence is emitted whole
 * rather than cut mid-word — Deepgram handles it, we just lose the latency win.
 */
export function chunkTextBySentence(text: string, maxChars = 1800): string[] {
  const sentences = text.match(/[^.!?]+[.!?]+(\s|$)|[^.!?]+$/g) ?? [text];
  const chunks: string[] = [];
  let current = "";
  for (const raw of sentences) {
    const s = raw.trim();
    if (!s) continue;
    if (current && current.length + 1 + s.length > maxChars) {
      chunks.push(current);
      current = s;
    } else {
      current = current ? `${current} ${s}` : s;
    }
  }
  if (current) chunks.push(current);
  return chunks;
}

/**
 * Cache-first TTS. Returns the existing row if present; otherwise synthesizes
 * via Deepgram REST, uploads, and inserts a row. Guarded when the key is empty.
 */
export async function ensureTtsAsset(
  deps: TtsDeps,
  input: EnsureTtsInput,
): Promise<EnsureTtsResult> {
  const assetKey = ttsAssetKey(input);

  const existing = await deps.repo.findByKey(assetKey);
  if (existing) return { status: "cached", asset: existing };

  if (!deps.deepgramApiKey) {
    return {
      status: "not_configured",
      reason: "DEEPGRAM_API_KEY is empty; TTS generation is disabled.",
    };
  }

  const fetchImpl = deps.fetchImpl ?? fetch;
  const chunks = chunkTextBySentence(input.text);

  // Synthesize each chunk and concatenate the raw audio bytes. mp3 frames are
  // independently decodable, so byte concatenation yields a playable file.
  const audioParts: Uint8Array[] = [];
  for (const chunk of chunks) {
    const url = new URL(DEEPGRAM_TTS_URL);
    url.searchParams.set("model", input.voiceModel);
    if (input.speakingRate != null) url.searchParams.set("speed", String(input.speakingRate));
    const res = await fetchImpl(url, {
      method: "POST",
      headers: {
        authorization: `Token ${deps.deepgramApiKey}`,
        "content-type": "application/json",
        accept: "audio/mpeg",
      },
      body: JSON.stringify({ text: chunk }),
    });
    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      throw new Error(`Deepgram TTS failed (${res.status}): ${detail.slice(0, 300)}`);
    }
    audioParts.push(new Uint8Array(await res.arrayBuffer()));
  }

  const bytes = concatBytes(audioParts);
  const storagePath = `tts/${assetKey}.mp3`;
  const uploadedPath = await deps.storage.upload(storagePath, bytes, "audio/mpeg");

  const asset = await deps.repo.insert({
    assetKey,
    provider: TTS_PROVIDER,
    voiceModel: input.voiceModel,
    locale: input.locale,
    storagePath: uploadedPath,
    durationMs: null, // duration probing is out of scope here; admin QA can backfill
  });

  deps.logger?.info({ assetKey, chunks: chunks.length, bytes: bytes.length }, "tts.generated");
  return { status: "generated", asset };
}

function concatBytes(parts: Uint8Array[]): Uint8Array {
  const total = parts.reduce((n, p) => n + p.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const p of parts) {
    out.set(p, offset);
    offset += p.length;
  }
  return out;
}
