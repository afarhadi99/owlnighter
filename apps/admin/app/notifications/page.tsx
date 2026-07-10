"use client";

import { useState } from "react";
import { PageHeader } from "@/components/PageHeader";
import { Badge } from "@/components/Badge";
import { api, ApiRequestError } from "@/lib/api";
import type { AdminPushTestResponse, PushType } from "@/lib/api";

// The four notification kinds the push pipeline can render (mirrors the
// ReminderKind / PushType union in @owlnighter/jobs).
const PUSH_TYPES: { value: PushType; label: string }[] = [
  { value: "nightly_reminder", label: "Nightly reminder" },
  { value: "streak_warning", label: "Streak warning" },
  { value: "completion_celebration", label: "Completion celebration" },
  { value: "re_engagement", label: "Re-engagement" },
];

export default function NotificationsPage() {
  const [userId, setUserId] = useState("00000000-0000-4000-8000-0000000000de");
  const [type, setType] = useState<PushType>("nightly_reminder");
  const [submitting, setSubmitting] = useState(false);
  const [result, setResult] = useState<AdminPushTestResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    setResult(null);
    try {
      const res = await api.sendTestPush(userId, type);
      setResult(res);
    } catch (err) {
      setError(
        err instanceof ApiRequestError
          ? `${err.status}: ${err.body?.error.message ?? err.message}`
          : (err as Error).message,
      );
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div>
      <PageHeader
        title="Notifications"
        subtitle="Send a test push of any of the four templates to a user's registered device tokens, via POST /v1/admin/push/test."
      />

      <form
        onSubmit={onSubmit}
        className="mb-6 flex flex-wrap items-end gap-3 rounded-md border border-line bg-ink-800 p-4"
      >
        <label className="flex flex-col gap-1">
          <span className="text-[11px] uppercase tracking-widest text-muted">
            User ID
          </span>
          <input
            value={userId}
            onChange={(e) => setUserId(e.target.value)}
            required
            spellCheck={false}
            className="h-9 w-80 rounded border border-line bg-ink-900 px-2 font-mono text-xs text-slate-100 outline-none focus:border-accent"
          />
        </label>

        <label className="flex flex-col gap-1">
          <span className="text-[11px] uppercase tracking-widest text-muted">
            Template
          </span>
          <select
            value={type}
            onChange={(e) => setType(e.target.value as PushType)}
            className="h-9 rounded border border-line bg-ink-900 px-2 text-sm text-slate-100 outline-none focus:border-accent"
          >
            {PUSH_TYPES.map((t) => (
              <option key={t.value} value={t.value}>
                {t.label}
              </option>
            ))}
          </select>
        </label>

        <button
          type="submit"
          disabled={submitting || !userId.trim()}
          className="h-9 rounded bg-accent px-4 text-sm font-medium text-ink-900 disabled:opacity-40"
        >
          {submitting ? "Sending…" : "Send test push"}
        </button>
      </form>

      {error ? (
        <div className="mb-4 rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">
          POST /v1/admin/push/test failed — {error}
        </div>
      ) : null}

      {result ? (
        <div className="space-y-3">
          <div
            className={`rounded-md border px-3 py-2 text-sm ${
              result.configured
                ? "border-good/40 bg-good/10 text-good"
                : "border-warn/40 bg-warn/10 text-warn"
            }`}
          >
            {result.configured
              ? "FCM is configured — attempted delivery to each registered token."
              : "FCM is not configured (FCM_PROJECT_ID / FCM_SERVICE_ACCOUNT_JSON unset on the API) — no push was actually sent; results below reflect that."}
          </div>

          <div className="rounded-md border border-line bg-ink-800 p-4">
            <div className="text-[11px] uppercase tracking-widest text-muted">
              Rendered notification
            </div>
            <div className="mt-1 text-sm font-medium text-slate-100">
              {result.notification.title}
            </div>
            <div className="text-sm text-muted">{result.notification.body}</div>
          </div>

          <div>
            <h2 className="mb-2 font-mono text-sm font-semibold text-slate-200">
              Per-token results
            </h2>
            {result.results.length === 0 ? (
              <div className="rounded-md border border-line bg-ink-800 px-3 py-2 text-sm text-muted">
                No registered device tokens for this user.
              </div>
            ) : (
              <div className="space-y-2">
                {result.results.map((r, i) => (
                  <div
                    key={`${r.token}-${i}`}
                    className="flex items-center justify-between rounded-md border border-line bg-ink-800 px-4 py-2"
                  >
                    <div className="flex items-center gap-3">
                      <span className="font-mono text-xs text-slate-300">
                        {r.token}
                      </span>
                      <Badge tone="neutral">{r.platform}</Badge>
                    </div>
                    <div className="flex items-center gap-2">
                      {r.detail ? (
                        <span className="text-xs text-muted">{r.detail}</span>
                      ) : null}
                      <Badge
                        tone={
                          r.status === "sent"
                            ? "good"
                            : r.status === "not_configured"
                              ? "warn"
                              : "bad"
                        }
                      >
                        {r.status}
                      </Badge>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      ) : null}
    </div>
  );
}
