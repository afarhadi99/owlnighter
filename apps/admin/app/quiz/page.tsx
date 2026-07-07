import { PageHeader, TodoBanner } from "@/components/PageHeader";
import { DataTable } from "@/components/DataTable";
import { Badge, quizModeTone } from "@/components/Badge";

// Mock quiz instances + failure rates. Answer keys stay server-side; admin sees
// only aggregate correctness and invalidation controls.
type MockQuiz = Record<string, unknown> & {
  quizId: string;
  quizMode: string;
  questions: number;
  provider: string;
  attempts: number;
  failureRate: number;
  invalidated: boolean;
};

const quizzes: MockQuiz[] = [
  { quizId: "qz_8f31…", quizMode: "grounded", questions: 4, provider: "gemini", attempts: 214, failureRate: 0.12, invalidated: false },
  { quizId: "qz_a029…", quizMode: "preview", questions: 4, provider: "groq", attempts: 88, failureRate: 0.31, invalidated: false },
  { quizId: "qz_c7d4…", quizMode: "fallback", questions: 3, provider: "groq", attempts: 40, failureRate: 0.62, invalidated: true },
];

export default function QuizPage() {
  return (
    <div>
      <PageHeader
        title="Quiz QA"
        subtitle="Quiz instances, provenance mode, failure rates, and invalidation controls."
      />
      <TodoBanner>
        no admin quiz-list endpoint yet; invalidation button should POST a
        (to-be-added) /v1/admin/quiz/:id/invalidate.
      </TodoBanner>

      <DataTable<MockQuiz>
        rowKey={(r) => r.quizId}
        rows={quizzes}
        columns={[
          { key: "quizId", header: "Quiz" },
          {
            key: "quizMode",
            header: "Mode",
            render: (r) => (
              <Badge tone={quizModeTone(r.quizMode)}>{r.quizMode}</Badge>
            ),
          },
          { key: "questions", header: "Qs" },
          {
            key: "provider",
            header: "Provider",
            render: (r) => (
              <Badge tone={r.provider === "gemini" ? "info" : "neutral"}>
                {r.provider}
              </Badge>
            ),
          },
          { key: "attempts", header: "Attempts" },
          {
            key: "failureRate",
            header: "Fail rate",
            render: (r) => (
              <span className={r.failureRate > 0.5 ? "text-bad" : r.failureRate > 0.3 ? "text-warn" : "text-good"}>
                {(r.failureRate * 100).toFixed(0)}%
              </span>
            ),
          },
          {
            key: "actions",
            header: "",
            render: (r) =>
              r.invalidated ? (
                <Badge tone="bad">invalidated</Badge>
              ) : (
                <button
                  type="button"
                  className="rounded border border-line px-2 py-0.5 text-xs text-warn hover:bg-ink-700"
                >
                  invalidate
                </button>
              ),
          },
        ]}
      />
    </div>
  );
}
