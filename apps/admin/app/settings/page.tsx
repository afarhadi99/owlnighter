import { api, ApiRequestError } from "@/lib/api";
import type { AdminSettingRow } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { SettingField } from "./SettingField";

const GROUPS: Array<{
  title: string;
  fields: Array<{ key: string; label: string; type: "string" | "number" | "boolean" | "secret" }>;
}> = [
  { title: "Limits", fields: [{ key: "max_books_per_user", label: "Max books per user", type: "number" }] },
  {
    title: "Feature Flags",
    fields: [
      { key: "flag.groq_quiz_generation", label: "Groq quiz generation", type: "boolean" },
      { key: "flag.tts_pregeneration", label: "TTS pre-generation", type: "boolean" },
      { key: "flag.grounding_review_queue", label: "Grounding review queue", type: "boolean" },
    ],
  },
  {
    title: "Grounding thresholds",
    fields: [
      { key: "grounding.auto_accept", label: "Auto-accept confidence", type: "number" },
      { key: "grounding.review_floor", label: "Review floor confidence", type: "number" },
    ],
  },
  {
    title: "Catalog",
    fields: [
      { key: "catalog.open_library_base_url", label: "Open Library base URL", type: "string" },
      { key: "catalog.google_books_api_key", label: "Google Books API key", type: "secret" },
    ],
  },
  {
    title: "AI Models (non-provider defaults)",
    fields: [
      { key: "ai.gemini.model", label: "Gemini model", type: "string" },
      { key: "ai.deepgram.tts_model", label: "Deepgram TTS model", type: "string" },
    ],
  },
];

export default async function SettingsPage() {
  let rows: AdminSettingRow[] = [];
  let error: string | null = null;
  try {
    const res = await api.adminGetSettings();
    rows = res.settings;
  } catch (err) {
    error =
      err instanceof ApiRequestError
        ? `${err.status}: ${err.body?.error.message ?? err.message}`
        : (err as Error).message;
  }
  const byKey = new Map(rows.map((r) => [r.key, r]));

  return (
    <div>
      <PageHeader
        title="Settings"
        subtitle="Admin-editable config, backed by app_settings. Env vars are only the seed defaults now."
      />
      {error ? (
        <div className="mb-4 rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">{error}</div>
      ) : null}
      {GROUPS.map((group) => (
        <div key={group.title} className="mb-6 rounded-md border border-line bg-ink-800 p-4">
          <h2 className="mb-2 font-mono text-sm font-semibold text-slate-200">{group.title}</h2>
          {group.fields.map((f) => {
            const row = byKey.get(f.key);
            return (
              <SettingField
                key={f.key}
                settingKey={f.key}
                label={f.label}
                type={f.type}
                initialValue={row?.value}
                configured={row?.configured}
              />
            );
          })}
        </div>
      ))}
    </div>
  );
}
