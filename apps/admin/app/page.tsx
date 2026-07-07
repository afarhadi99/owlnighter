import { PageHeader, TodoBanner } from "@/components/PageHeader";
import { StatTile } from "@/components/StatTile";
import { Badge } from "@/components/Badge";

// Mock observability signals from the blueprint §"Observability recommendations":
// grounding confidence histogram, quiz invalidation rate, TTS cache hit rate,
// push send success. Replace each with a real metrics endpoint.
const groundingBuckets = [
  { label: "auto ≥0.85", count: 412, tone: "good" as const },
  { label: "review 0.60–0.84", count: 118, tone: "warn" as const },
  { label: "limited <0.60", count: 37, tone: "bad" as const },
];

export default function OverviewPage() {
  const total = groundingBuckets.reduce((n, b) => n + b.count, 0);

  return (
    <div>
      <PageHeader
        title="Overview"
        subtitle="Operational health at a glance. Every number here is mock data until wired to the metrics API."
      />

      <TodoBanner>
        no metrics endpoint exists in the contract yet; these tiles read static
        fixtures.
      </TodoBanner>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatTile
          label="Grounding confidence"
          value={`${Math.round((groundingBuckets[0]!.count / total) * 100)}%`}
          sub="share auto-accepted"
          tone="good"
        >
          <div className="space-y-1">
            {groundingBuckets.map((b) => (
              <div
                key={b.label}
                className="flex items-center justify-between text-xs"
              >
                <span className="text-muted">{b.label}</span>
                <Badge tone={b.tone}>{b.count}</Badge>
              </div>
            ))}
          </div>
        </StatTile>

        <StatTile
          label="Quiz invalidation rate"
          value="4.2%"
          sub="quizzes voided / regenerated (7d)"
          tone="warn"
        />

        <StatTile
          label="TTS cache hit rate"
          value="91.7%"
          sub="hash-deduped Deepgram assets"
          tone="good"
        />

        <StatTile
          label="Push send success"
          value="98.3%"
          sub="FCM delivered / attempted (24h)"
          tone="good"
        />
      </div>

      <div className="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-2">
        <StatTile
          label="Median step latency"
          value="1.9s"
          sub="plan → quiz generation p50"
        />
        <StatTile
          label="Offline sync backlog"
          value="126"
          sub="queued client mutations across users"
          tone="warn"
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
