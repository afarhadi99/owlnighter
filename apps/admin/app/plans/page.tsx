import { PageHeader, TodoBanner } from "@/components/PageHeader";
import { DataTable } from "@/components/DataTable";
import { Badge, quizModeTone } from "@/components/Badge";

// Mock plan steps mirroring PlanStep from the contract. Real data: GET /v1/plans/:id.
// No admin list endpoint exists yet — see follow-ups.
type MockStep = Record<string, unknown> & {
  stepIndex: number;
  title: string;
  pageStart?: number;
  pageEnd?: number;
  quizMode: string;
  confidence: number;
};

const steps: MockStep[] = [
  { stepIndex: 0, title: "Ch. 1 — Down the Rabbit-Hole", pageStart: 1, pageEnd: 14, quizMode: "grounded", confidence: 0.92 },
  { stepIndex: 1, title: "Ch. 2 — The Pool of Tears", pageStart: 15, pageEnd: 28, quizMode: "preview", confidence: 0.71 },
  { stepIndex: 2, title: "Ch. 3 — A Caucus-Race", pageStart: 29, pageEnd: 40, quizMode: "fallback", confidence: 0.48 },
];

export default function PlansPage() {
  return (
    <div>
      <PageHeader
        title="Plan QA"
        subtitle="Inspect generated nightly path steps, pacing, and the quiz mode each step will use."
      />
      <TodoBanner>
        still mock: wire to GET /v1/plans/:id; add an admin plan-search
        endpoint to list plans. (Overview/TTS/Quiz QA now read live admin
        endpoints — this page still doesn&apos;t have one to call.)
      </TodoBanner>

      <div className="mb-4 flex gap-2 text-xs text-muted">
        <Badge tone="info">gemini/gemini-3.5-flash</Badge>
        <span>· pacing: standard · nightly goal: 12 pp · version 2</span>
      </div>

      <DataTable<MockStep>
        rowKey={(r) => String(r.stepIndex)}
        rows={steps}
        columns={[
          { key: "stepIndex", header: "#", render: (r) => `#${r.stepIndex}` },
          { key: "title", header: "Step" },
          {
            key: "pages",
            header: "Pages",
            render: (r) =>
              r.pageStart != null ? `${r.pageStart}–${r.pageEnd}` : "—",
          },
          {
            key: "quizMode",
            header: "Quiz mode",
            render: (r) => (
              <Badge tone={quizModeTone(r.quizMode)}>{r.quizMode}</Badge>
            ),
          },
          {
            key: "confidence",
            header: "Confidence",
            render: (r) => r.confidence.toFixed(2),
          },
        ]}
      />

      <p className="mt-4 text-xs text-muted">
        Steps in <span className="text-bad">fallback</span> mode cannot back
        page-specific questions — the plan honestly degrades rather than
        pretending precision (blueprint §copyright safeguards).
      </p>
    </div>
  );
}
