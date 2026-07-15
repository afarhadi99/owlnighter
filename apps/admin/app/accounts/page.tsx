import { api, ApiRequestError } from "@/lib/api";
import type { AdminPendingAccount } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { DataTable } from "@/components/DataTable";
import { Badge } from "@/components/Badge";
import { approveAccountAction, rejectAccountAction } from "./actions";

export default async function AccountsPage() {
  let accounts: AdminPendingAccount[] = [];
  let error: string | null = null;
  try {
    const res = await api.adminListPendingAccounts();
    accounts = res.accounts;
  } catch (err) {
    error =
      err instanceof ApiRequestError
        ? `${err.status}: ${err.body?.error.message ?? err.message}`
        : (err as Error).message;
  }

  return (
    <div>
      <PageHeader title="Admin Accounts" subtitle="Pending @mytsi.org signup requests awaiting approval." />
      {error ? (
        <div className="mb-4 rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">{error}</div>
      ) : null}
      <DataTable<AdminPendingAccount>
        rowKey={(r) => r.id}
        rows={accounts}
        empty="No pending requests."
        columns={[
          { key: "email", header: "Email" },
          { key: "status", header: "Status", render: (r) => <Badge tone="warn">{r.status}</Badge> },
          { key: "createdAt", header: "Requested" },
          {
            key: "actions",
            header: "Actions",
            render: (r) => (
              <div className="flex gap-2">
                <form action={approveAccountAction.bind(null, r.id)}>
                  <button
                    type="submit"
                    className="rounded border border-good/40 bg-good/10 px-2 py-1 text-xs text-good"
                  >
                    Approve
                  </button>
                </form>
                <form action={rejectAccountAction.bind(null, r.id)}>
                  <button type="submit" className="rounded border border-bad/40 bg-bad/10 px-2 py-1 text-xs text-bad">
                    Reject
                  </button>
                </form>
              </div>
            ),
          },
        ]}
      />
    </div>
  );
}
