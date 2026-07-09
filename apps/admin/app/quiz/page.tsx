"use client";

import { useState } from "react";
import { PageHeader, TodoBanner } from "@/components/PageHeader";
import { DataTable } from "@/components/DataTable";
import { Badge, quizModeTone } from "@/components/Badge";
import { api, ApiRequestError } from "@/lib/api";

// Mock quiz instances + failure rates. Answer keys stay server-side; admin sees
// only aggregate correctness. There is still no admin quiz-list endpoint, so
// the rows below stay static — only the invalidate action is wired.
type MockQuiz = Record<string, unknown> & {
  quizId: string;
  quizMode: string;
  questions: number;
  provider: string;
  attempts: number;
  failureRate: number;
  invalidated: boolean;
};

const initialQuizzes: MockQuiz[] = [
  { quizId: "qz_8f31…", quizMode: "grounded", questions: 4, provider: "gemini", attempts: 214, failureRate: 0.12, invalidated: false },
  { quizId: "qz_a029…", quizMode: "preview", questions: 4, provider: "groq", attempts: 88, failureRate: 0.31, invalidated: false },
  { quizId: "qz_c7d4…", quizMode: "fallback", questions: 3, provider: "groq", attempts: 40, failureRate: 0.62, invalidated: true },
];

export default function QuizPage() {
  const [quizzes, setQuizzes] = useState(initialQuizzes);
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function onInvalidate(quizId: string) {
    const reason = window.prompt(`Reason for invalidating ${quizId}?`);
    if (!reason) return;

    setPendingId(quizId);
    setError(null);
    try {
      const res = await api.invalidateQuiz(quizId, { reason });
      setQuizzes((prev) =>
        prev.map((q) =>
          q.quizId === res.quizId ? { ...q, invalidated: res.invalidated } : q,
        ),
      );
    } catch (err) {
      setError(
        err instanceof ApiRequestError
          ? `${err.status}: ${err.body?.error.message ?? err.message}`
          : (err as Error).message,
      );
    } finally {
      setPendingId(null);
    }
  }

  return (
    <div>
      <PageHeader
        title="Quiz QA"
        subtitle="Quiz instances, provenance mode, failure rates, and invalidation controls."
      />
      <TodoBanner>
        no admin quiz-list endpoint yet, so rows below are still fixtures;
        the invalidate action is wired to POST /v1/admin/quiz/:id/invalidate.
      </TodoBanner>

      {error ? (
        <div className="mb-4 rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">
          Invalidate failed — {error}
        </div>
      ) : null}

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
                  disabled={pendingId === r.quizId}
                  onClick={() => onInvalidate(r.quizId)}
                  className="rounded border border-line px-2 py-0.5 text-xs text-warn hover:bg-ink-700 disabled:opacity-50"
                >
                  {pendingId === r.quizId ? "invalidating…" : "invalidate"}
                </button>
              ),
          },
        ]}
      />
    </div>
  );
}
