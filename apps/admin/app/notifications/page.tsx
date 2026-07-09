import { PageHeader, TodoBanner } from "@/components/PageHeader";
import { StatTile } from "@/components/StatTile";
import { DataTable } from "@/components/DataTable";
import { Badge } from "@/components/Badge";

// Mock FCM message templates + delivery health. Push send rights are backend/
// admin only (blueprint §security posture) — this surface is read + template mgmt.
type MockTemplate = Record<string, unknown> & {
  key: string;
  title: string;
  sent: number;
  delivered: number;
  opened: number;
};

const templates: MockTemplate[] = [
  { key: "nightly_reminder", title: "Your reading unlocks tonight 🦉", sent: 4210, delivered: 4139, opened: 1802 },
  { key: "streak_risk", title: "Keep your {{streak}}-day streak alive", sent: 980, delivered: 961, opened: 611 },
  { key: "plan_complete", title: "You finished {{book}}!", sent: 142, delivered: 140, opened: 96 },
];

export default function NotificationsPage() {
  return (
    <div>
      <PageHeader
        title="Notifications"
        subtitle="Message templates, delivery success, and push token health. Send rights live backend-only."
      />
      <TodoBanner>
        still mock: POST /v1/push/register handles token registration, but no
        admin template + delivery-metrics endpoints exist yet (unlike Overview/
        TTS/Quiz QA, which now read live admin endpoints).
      </TodoBanner>

      <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <StatTile label="Delivery success" value="98.3%" tone="good" sub="24h" />
        <StatTile label="Open-through" value="42.1%" tone="warn" sub="24h" />
        <StatTile label="Stale tokens" value="87" tone="bad" sub="pending prune" />
      </div>

      <DataTable<MockTemplate>
        rowKey={(r) => r.key}
        rows={templates}
        columns={[
          { key: "key", header: "Template key" },
          { key: "title", header: "Copy" },
          { key: "sent", header: "Sent" },
          {
            key: "delivered",
            header: "Delivered",
            render: (r) => (
              <span>
                {r.delivered}{" "}
                <span className="text-muted">
                  ({((r.delivered / r.sent) * 100).toFixed(0)}%)
                </span>
              </span>
            ),
          },
          {
            key: "opened",
            header: "Opened",
            render: (r) => (
              <Badge tone="info">
                {((r.opened / r.delivered) * 100).toFixed(0)}%
              </Badge>
            ),
          },
        ]}
      />
    </div>
  );
}
