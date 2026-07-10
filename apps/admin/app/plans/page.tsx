import { api, ApiRequestError, API_BASE } from "@/lib/api";
import type { AdminPlanListItem } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { DataTable } from "@/components/DataTable";
import { Badge } from "@/components/Badge";

const pacingTone = {
  gentle: "info",
  standard: "neutral",
  intensive: "warn",
} as const;

export default async function PlansPage() {
  let plans: AdminPlanListItem[] = [];
  let error: string | null = null;
  try {
    const data = await api.getPlans();
    plans = data.plans;
  } catch (err) {
    error =
      err instanceof ApiRequestError
        ? `${err.status}: ${err.body?.error.message ?? err.message}`
        : (err as Error).message;
  }

  return (
    <div>
      <PageHeader
        title="Plan QA"
        subtitle="Generated nightly reading plans, read live from GET /v1/admin/plans."
      />

      {error ? (
        <div className="mb-4 rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">
          GET /v1/admin/plans failed — {error}
          <div className="mt-1 text-xs text-muted">
            Confirm the API is running at {API_BASE}.
          </div>
        </div>
      ) : null}

      <DataTable<AdminPlanListItem>
        rowKey={(r) => r.planId}
        rows={plans}
        columns={[
          { key: "planId", header: "Plan" },
          { key: "bookId", header: "Book" },
          {
            key: "planVersion",
            header: "Version",
            render: (r) => `v${r.planVersion}`,
          },
          {
            key: "provider",
            header: "Provider/model",
            render: (r) => (
              <span className="font-mono text-xs text-muted">
                {r.provider}/{r.providerModel}
              </span>
            ),
          },
          {
            key: "pacingMode",
            header: "Pacing",
            render: (r) => (
              <Badge tone={pacingTone[r.pacingMode]}>{r.pacingMode}</Badge>
            ),
          },
          {
            key: "nightlyGoalPages",
            header: "Nightly goal",
            render: (r) => `${r.nightlyGoalPages} pp`,
          },
          { key: "stepCount", header: "Steps" },
          {
            key: "startsOn",
            header: "Starts",
            render: (r) => new Date(r.startsOn).toLocaleDateString(),
          },
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
