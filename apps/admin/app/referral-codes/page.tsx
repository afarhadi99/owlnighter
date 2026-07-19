import { api, ApiRequestError } from "@/lib/api";
import type { AdminReferralCode } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { DataTable } from "@/components/DataTable";
import { Badge } from "@/components/Badge";
import { CreateCodeForm } from "./CreateCodeForm";
import { ToggleActiveButton } from "./ToggleActiveButton";

function usageLabel(row: AdminReferralCode): string {
  return row.maxUses === null ? `${row.useCount} / unlimited` : `${row.useCount} / ${row.maxUses}`;
}

function statusBadge(row: AdminReferralCode) {
  if (!row.isActive) return <Badge tone="neutral">deactivated</Badge>;
  if (row.expiresAt && new Date(row.expiresAt).getTime() <= Date.now()) return <Badge tone="bad">expired</Badge>;
  if (row.maxUses !== null && row.useCount >= row.maxUses) return <Badge tone="bad">exhausted</Badge>;
  return <Badge tone="good">active</Badge>;
}

export default async function ReferralCodesPage() {
  let codes: AdminReferralCode[] = [];
  let error: string | null = null;
  try {
    const res = await api.adminListReferralCodes();
    codes = res.codes;
  } catch (err) {
    error =
      err instanceof ApiRequestError
        ? `${err.status}: ${err.body?.error.message ?? err.message}`
        : (err as Error).message;
  }

  return (
    <div>
      <PageHeader
        title="Referral Codes"
        subtitle="Invite-code gate for new accounts — both email/password signup and Google sign-in require one to activate."
      />
      {error ? (
        <div className="mb-4 rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">{error}</div>
      ) : null}

      <CreateCodeForm />

      <DataTable<AdminReferralCode>
        rowKey={(r) => r.id}
        rows={codes}
        empty="No referral codes yet — mint one above."
        columns={[
          { key: "code", header: "Code", render: (r) => <span className="font-mono">{r.code}</span> },
          { key: "label", header: "Label", render: (r) => r.label ?? <span className="text-muted">—</span> },
          { key: "usage", header: "Usage", render: (r) => usageLabel(r) },
          {
            key: "expiresAt",
            header: "Expires",
            render: (r) => (r.expiresAt ? new Date(r.expiresAt).toLocaleDateString() : "never"),
          },
          { key: "status", header: "Status", render: (r) => statusBadge(r) },
          {
            key: "actions",
            header: "Actions",
            render: (r) => <ToggleActiveButton id={r.id} isActive={r.isActive} />,
          },
        ]}
      />
    </div>
  );
}
