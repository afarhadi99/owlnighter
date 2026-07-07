import { PageHeader, TodoBanner } from "@/components/PageHeader";
import { StatTile } from "@/components/StatTile";
import { DataTable } from "@/components/DataTable";
import { Badge } from "@/components/Badge";

// Mock Deepgram TTS assets (hash-deduped + cached per TtsGenerateResponse).
type MockAsset = Record<string, unknown> & {
  assetKey: string;
  voiceModel: string;
  durationMs: number;
  cached: boolean;
  hits: number;
};

const assets: MockAsset[] = [
  { assetKey: "sha256:9ab3…", voiceModel: "aura-2-thalia-en", durationMs: 42000, cached: true, hits: 312 },
  { assetKey: "sha256:1f0c…", voiceModel: "aura-2-thalia-en", durationMs: 38500, cached: true, hits: 118 },
  { assetKey: "sha256:77de…", voiceModel: "aura-2-orion-en", durationMs: 51200, cached: false, hits: 1 },
];

export default function TtsPage() {
  return (
    <div>
      <PageHeader
        title="TTS QA"
        subtitle="Preview generated audio, cache hit rate, and voice usage. Assets are hash-deduped so identical text reuses one file."
      />
      <TodoBanner>
        POST /v1/tts/generate exists for creation; add an admin asset-list +
        signed-URL preview endpoint for playback here.
      </TodoBanner>

      <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <StatTile label="Cache hit rate" value="91.7%" tone="good" sub="24h" />
        <StatTile label="Assets generated" value="1,204" sub="lifetime" />
        <StatTile label="Voices in use" value="2" sub="aura-2 family" />
      </div>

      <DataTable<MockAsset>
        rowKey={(r) => r.assetKey}
        rows={assets}
        columns={[
          { key: "assetKey", header: "Asset key (content hash)" },
          { key: "voiceModel", header: "Voice" },
          {
            key: "durationMs",
            header: "Duration",
            render: (r) => `${(r.durationMs / 1000).toFixed(1)}s`,
          },
          {
            key: "cached",
            header: "Cache",
            render: (r) => (
              <Badge tone={r.cached ? "good" : "neutral"}>
                {r.cached ? "hit" : "miss"}
              </Badge>
            ),
          },
          { key: "hits", header: "Reuse count" },
          {
            key: "actions",
            header: "",
            render: () => (
              <button
                type="button"
                className="rounded border border-line px-2 py-0.5 text-xs text-accent hover:bg-ink-700"
              >
                ▶ preview
              </button>
            ),
          },
        ]}
      />
    </div>
  );
}
