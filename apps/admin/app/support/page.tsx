import { PageHeader, TodoBanner } from "@/components/PageHeader";
import { Badge } from "@/components/Badge";

// User support: library state, streak repair, plan reset, notification status.
// All mock; real ops need admin user-lookup + mutation endpoints.
const mockUser = {
  id: "usr_4f21…",
  email: "reader@example.com",
  status: "active",
  currentStreak: 12,
  longestStreak: 21,
  activeBooks: 2,
  pushToken: "healthy",
};

const supportActions = [
  { label: "Repair streak", hint: "recompute from completion log", tone: "warn" as const },
  { label: "Reset plan", hint: "regenerate path from current page", tone: "warn" as const },
  { label: "Reissue push token", hint: "force client re-register", tone: "neutral" as const },
  { label: "Archive library book", hint: "soft-remove without data loss", tone: "neutral" as const },
];

export default function SupportPage() {
  return (
    <div>
      <PageHeader
        title="User Support"
        subtitle="Inspect a user's library state, streak, and notification status; run repair actions."
      />
      <TodoBanner>
        add admin user-lookup + mutation endpoints (streak repair, plan reset).
        RLS keeps user data server-side; admin uses service-role access.
      </TodoBanner>

      <div className="mb-6 rounded-md border border-line bg-ink-800 p-4">
        <div className="grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
          <Field label="User" value={mockUser.id} mono />
          <Field label="Email" value={mockUser.email} />
          <Field label="Status" value={<Badge tone="good">{mockUser.status}</Badge>} />
          <Field label="Push" value={<Badge tone="good">{mockUser.pushToken}</Badge>} />
          <Field label="Current streak" value={`${mockUser.currentStreak}d`} mono />
          <Field label="Longest streak" value={`${mockUser.longestStreak}d`} mono />
          <Field label="Active books" value={String(mockUser.activeBooks)} mono />
        </div>
      </div>

      <h2 className="mb-2 font-mono text-sm font-semibold text-slate-200">
        Repair actions
      </h2>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        {supportActions.map((a) => (
          <div
            key={a.label}
            className="flex items-center justify-between rounded-md border border-line bg-ink-800 px-4 py-3"
          >
            <div>
              <div className="text-sm text-slate-100">{a.label}</div>
              <div className="text-xs text-muted">{a.hint}</div>
            </div>
            <button
              type="button"
              className={`rounded border border-line px-3 py-1 text-xs hover:bg-ink-700 ${a.tone === "warn" ? "text-warn" : "text-slate-300"}`}
            >
              run
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

function Field({
  label,
  value,
  mono,
}: {
  label: string;
  value: React.ReactNode;
  mono?: boolean;
}) {
  return (
    <div>
      <div className="text-[11px] uppercase tracking-widest text-muted">
        {label}
      </div>
      <div className={`mt-0.5 ${mono ? "font-mono" : ""} text-slate-100`}>
        {value}
      </div>
    </div>
  );
}
