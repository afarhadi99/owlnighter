import { api, ApiRequestError, API_BASE } from "@/lib/api";
import type { AdminTtsAsset } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { StatTile } from "@/components/StatTile";
import { DataTable } from "@/components/DataTable";

export default async function TtsPage() {
  let assets: AdminTtsAsset[] = [];
  let error: string | null = null;
  try {
    const data = await api.getTtsAssets();
    assets = data.assets;
  } catch (err) {
    error =
      err instanceof ApiRequestError
        ? `${err.status}: ${err.body?.error.message ?? err.message}`
        : (err as Error).message;
  }

  const voices = new Set(assets.map((a) => a.voiceModel)).size;

  return (
    <div>
      <PageHeader
        title="TTS QA"
        subtitle="Cache inspector for generated audio, read live from GET /v1/admin/tts."
      />

      {error ? (
        <div className="mb-4 rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">
          GET /v1/admin/tts failed — {error}
          <div className="mt-1 text-xs text-muted">
            Confirm the API is running at {API_BASE}.
          </div>
        </div>
      ) : null}

      <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <StatTile label="Assets" value={assets.length} sub="in cache" />
        <StatTile label="Voices in use" value={voices} sub="distinct voice models" />
        <StatTile
          label="Locales"
          value={new Set(assets.map((a) => a.locale)).size}
          sub="distinct locales"
        />
      </div>

      <DataTable<AdminTtsAsset>
        rowKey={(r) => r.assetId}
        rows={assets}
        columns={[
          { key: "assetKey", header: "Asset key (content hash)" },
          { key: "voiceModel", header: "Voice" },
          { key: "locale", header: "Locale" },
          {
            key: "durationMs",
            header: "Duration",
            render: (r) => `${(r.durationMs / 1000).toFixed(1)}s`,
          },
          { key: "storagePath", header: "Storage path" },
          {
            key: "createdAt",
            header: "Created",
            render: (r) => new Date(r.createdAt).toLocaleString(),
          },
        ]}
      />
    </div>
  );
}
