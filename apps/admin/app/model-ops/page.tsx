import { PageHeader, TodoBanner } from "@/components/PageHeader";
import { DataTable } from "@/components/DataTable";
import { Badge } from "@/components/Badge";

// Model operations: active provider/model, routing rules, retry/fallback logs.
// Providers per .env.example: Gemini (grounding-heavy) + Groq Qwen (fast JSON).
const routing = [
  { flow: "book grounding", primary: "gemini/gemini-3.5-flash", fallback: "—", reason: "grounding + citations required" },
  { flow: "plan generation", primary: "gemini/gemini-3.5-flash", fallback: "groq/qwen-3.6-32b", reason: "schema-constrained; groq validated fallback" },
  { flow: "quiz generation", primary: "groq/qwen-3.6-32b", fallback: "gemini/gemini-3.5-flash", reason: "latency-sensitive JSON object mode" },
];

type MockLog = Record<string, unknown> & {
  ts: string;
  flow: string;
  provider: string;
  outcome: string;
  attempts: number;
};

const fallbackLog: MockLog[] = [
  { ts: "2026-07-07T02:14:03Z", flow: "quiz", provider: "groq → gemini", outcome: "fallback ok", attempts: 2 },
  { ts: "2026-07-07T01:58:41Z", flow: "plan", provider: "gemini", outcome: "ok", attempts: 1 },
  { ts: "2026-07-07T01:41:12Z", flow: "quiz", provider: "groq", outcome: "schema retry", attempts: 3 },
];

export default function ModelOpsPage() {
  return (
    <div>
      <PageHeader
        title="Model Operations"
        subtitle="Active provider/model per flow, routing rules, and retry/fallback logs. Keys stay backend-only."
      />
      <TodoBanner>
        still mock: add admin routing-config + AI-call-log endpoints; every AI
        call should carry a provider/model label and request ID (blueprint
        §observability). Overview/TTS/Quiz QA now read live admin endpoints —
        this page still doesn&apos;t have one to call.
      </TodoBanner>

      <h2 className="mb-2 font-mono text-sm font-semibold text-slate-200">
        Routing rules
      </h2>
      <div className="mb-6">
        <DataTable<Record<string, unknown> & (typeof routing)[number]>
          rowKey={(r) => r.flow}
          rows={routing as (Record<string, unknown> & (typeof routing)[number])[]}
          columns={[
            { key: "flow", header: "Flow" },
            {
              key: "primary",
              header: "Primary",
              render: (r) => <Badge tone="info">{r.primary}</Badge>,
            },
            {
              key: "fallback",
              header: "Fallback",
              render: (r) =>
                r.fallback === "—" ? (
                  <span className="text-muted">—</span>
                ) : (
                  <Badge tone="neutral">{r.fallback}</Badge>
                ),
            },
            { key: "reason", header: "Why" },
          ]}
        />
      </div>

      <h2 className="mb-2 font-mono text-sm font-semibold text-slate-200">
        Retry / fallback log
      </h2>
      <DataTable<MockLog>
        rowKey={(r, i) => `${r.ts}-${i}`}
        rows={fallbackLog}
        columns={[
          { key: "ts", header: "Timestamp" },
          { key: "flow", header: "Flow" },
          { key: "provider", header: "Provider path" },
          {
            key: "outcome",
            header: "Outcome",
            render: (r) => (
              <Badge tone={r.outcome === "ok" ? "good" : "warn"}>
                {r.outcome}
              </Badge>
            ),
          },
          { key: "attempts", header: "Attempts" },
        ]}
      />
    </div>
  );
}
