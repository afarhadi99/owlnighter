import { api, ApiRequestError, API_BASE } from "@/lib/api";
import type { AdminMetricsResponse } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { StatTile } from "@/components/StatTile";
import { Badge } from "@/components/Badge";

export default async function OverviewPage() {
  let metrics: AdminMetricsResponse | null = null;
  let error: string | null = null;
  try {
    metrics = await api.getMetrics();
  } catch (err) {
    error =
      err instanceof ApiRequestError
        ? `${err.status}: ${err.body?.error.message ?? err.message}`
        : (err as Error).message;
  }

  const groundingTotal = metrics
    ? metrics.grounding.autoAccepted +
      metrics.grounding.needsReview +
      metrics.grounding.limited
    : 0;
  const autoAcceptedPct =
    metrics && groundingTotal > 0
      ? Math.round((metrics.grounding.autoAccepted / groundingTotal) * 100)
      : null;

  return (
    <div>
      <PageHeader
        title="Overview"
        subtitle="Operational health at a glance, read live from GET /v1/admin/metrics."
      />

      {error ? (
        <div className="mb-4 rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">
          GET /v1/admin/metrics failed — {error}
          <div className="mt-1 text-xs text-muted">
            Confirm the API is running at {API_BASE}.
          </div>
        </div>
      ) : null}

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatTile
          label="Grounding confidence"
          value={autoAcceptedPct !== null ? `${autoAcceptedPct}%` : "—"}
          sub="share auto-accepted"
          tone="good"
        >
          {metrics ? (
            <div className="space-y-1">
              <Row label="auto-accepted" count={metrics.grounding.autoAccepted} tone="good" />
              <Row label="needs review" count={metrics.grounding.needsReview} tone="warn" />
              <Row label="limited" count={metrics.grounding.limited} tone="bad" />
            </div>
          ) : null}
        </StatTile>

        <StatTile
          label="Quiz pass rate"
          value={metrics ? `${(metrics.quiz.passRate * 100).toFixed(1)}%` : "—"}
          sub={metrics ? `${metrics.quiz.attempts} attempts` : "attempts"}
          tone="warn"
        />

        <StatTile
          label="TTS assets"
          value={metrics ? metrics.tts.assets.toLocaleString() : "—"}
          sub="hash-deduped Deepgram assets"
          tone="good"
        />

        <StatTile
          label="Books"
          value={metrics ? metrics.books.total.toLocaleString() : "—"}
          sub="in catalog"
        />
      </div>

      <div className="mt-6 rounded-md border border-line bg-ink-800 p-4 text-sm text-muted">
        <div className="mb-1 font-mono text-slate-200">Where to look next</div>
        Start with <span className="text-accent">Grounding Review</span> for
        low-confidence titles, then <span className="text-accent">Quiz QA</span>{" "}
        for invalidation spikes. Provenance for every fact lives under a book&apos;s
        grounding detail page.
      </div>
    </div>
  );
}

function Row({
  label,
  count,
  tone,
}: {
  label: string;
  count: number;
  tone: "good" | "warn" | "bad";
}) {
  return (
    <div className="flex items-center justify-between text-xs">
      <span className="text-muted">{label}</span>
      <Badge tone={tone}>{count}</Badge>
    </div>
  );
}
