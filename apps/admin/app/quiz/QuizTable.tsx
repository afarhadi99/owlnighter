"use client";

import { useState } from "react";
import { DataTable } from "@/components/DataTable";
import { Badge, quizModeTone, confidenceTone } from "@/components/Badge";
import { api, ApiRequestError } from "@/lib/api";
import type { AdminQuizListItem } from "@/lib/api";
import { Spinner } from "@/components/Spinner";
import { chime, error as errorChime } from "@/lib/sfx";

export function QuizTable({ initialQuizzes }: { initialQuizzes: AdminQuizListItem[] }) {
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
          q.quizId === res.quizId
            ? { ...q, invalidatedAt: res.invalidated ? new Date().toISOString() : null }
            : q,
        ),
      );
      chime();
    } catch (err) {
      setError(
        err instanceof ApiRequestError
          ? `${err.status}: ${err.body?.error.message ?? err.message}`
          : (err as Error).message,
      );
      errorChime();
    } finally {
      setPendingId(null);
    }
  }

  return (
    <div>
      {error ? (
        <div className="mb-4 rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">
          Invalidate failed — {error}
        </div>
      ) : null}

      <DataTable<AdminQuizListItem>
        rowKey={(r) => r.quizId}
        rows={quizzes}
        columns={[
          { key: "quizId", header: "Quiz" },
          { key: "stepId", header: "Step" },
          {
            key: "quizMode",
            header: "Mode",
            render: (r) => (
              <Badge tone={quizModeTone(r.quizMode)}>{r.quizMode}</Badge>
            ),
          },
          { key: "questionCount", header: "Qs" },
          {
            key: "provider",
            header: "Provider",
            render: (r) => (
              <span className="font-mono text-xs text-muted">
                {r.provider}/{r.providerModel}
              </span>
            ),
          },
          {
            key: "confidence",
            header: "Confidence",
            render: (r) => (
              <Badge tone={confidenceTone(r.confidence)}>
                {r.confidence.toFixed(2)}
              </Badge>
            ),
          },
          {
            key: "createdAt",
            header: "Created",
            render: (r) => new Date(r.createdAt).toLocaleString(),
          },
          {
            key: "actions",
            header: "",
            render: (r) =>
              r.invalidatedAt ? (
                <Badge tone="bad">invalidated</Badge>
              ) : (
                <button
                  type="button"
                  disabled={pendingId === r.quizId}
                  onClick={() => onInvalidate(r.quizId)}
                  className="rounded border border-line px-2 py-0.5 text-xs text-warn hover:bg-ink-700 disabled:opacity-50"
                >
                  {pendingId === r.quizId ? (
                    <span className="inline-flex items-center gap-1">
                      <Spinner size={11} /> invalidating…
                    </span>
                  ) : (
                    "invalidate"
                  )}
                </button>
              ),
          },
        ]}
      />
    </div>
  );
}
