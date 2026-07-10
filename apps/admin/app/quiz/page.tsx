import { api, ApiRequestError, API_BASE } from "@/lib/api";
import type { AdminQuizListItem } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { QuizTable } from "./QuizTable";

export default async function QuizPage() {
  let quizzes: AdminQuizListItem[] = [];
  let error: string | null = null;
  try {
    const data = await api.getQuizzes();
    quizzes = data.quizzes;
  } catch (err) {
    error =
      err instanceof ApiRequestError
        ? `${err.status}: ${err.body?.error.message ?? err.message}`
        : (err as Error).message;
  }

  return (
    <div>
      <PageHeader
        title="Quiz QA"
        subtitle="Quiz instances, provenance mode, and invalidation controls — read live from GET /v1/admin/quizzes."
      />

      {error ? (
        <div className="mb-4 rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">
          GET /v1/admin/quizzes failed — {error}
          <div className="mt-1 text-xs text-muted">
            Confirm the API is running at {API_BASE}.
          </div>
        </div>
      ) : null}

      <QuizTable initialQuizzes={quizzes} />
    </div>
  );
}
