import type { JobQueue } from "./queue.js";

/**
 * Nightly reminder + streak-warning logic.
 *
 * The scheduling decisions are PURE functions (easy to test); the job handlers
 * are thin shells that push the resulting jobs onto the queue. Push delivery
 * itself (FCM/APNs) lives behind the queue's downstream worker, out of scope here.
 */

export type ReminderKind =
  | "nightly_reminder"
  | "streak_warning"
  | "completion_celebration"
  | "re_engagement";

export interface ReminderCandidate {
  userId: string;
  timezone: string;
  /** Local "HH:MM" the user wants their nightly nudge. */
  reminderTimeLocal: string;
  /** Whether the user has already completed tonight's step. */
  completedToday: boolean;
  /** Current streak length in days. */
  streakDays: number;
  /** Pages left in tonight's step (for message copy). */
  pagesRemaining: number;
}

export interface ReminderJob {
  kind: ReminderKind;
  userId: string;
  /** ISO instant the notification should fire. */
  sendAt: string;
  /** Ready-to-render copy for the push payload. */
  title: string;
  body: string;
}

/**
 * Convert a local "HH:MM" wall-clock time on a given date into a UTC ISO
 * instant for the candidate's timezone. Uses Intl to read the zone's offset —
 * no external tz library needed.
 */
export function localTimeToUtcIso(
  dateUtc: Date,
  timezone: string,
  hhmm: string,
): string {
  const [h, m] = hhmm.split(":").map((x) => Number(x));
  const hour = Number.isFinite(h) ? (h as number) : 20;
  const minute = Number.isFinite(m) ? (m as number) : 30;

  // Offset (minutes) between the target zone and UTC at this date.
  const offsetMinutes = zoneOffsetMinutes(dateUtc, timezone);
  // Wall-clock target, expressed as if UTC, then shifted back by the offset.
  const utcMillis = Date.UTC(
    dateUtc.getUTCFullYear(),
    dateUtc.getUTCMonth(),
    dateUtc.getUTCDate(),
    hour,
    minute,
    0,
  ) - offsetMinutes * 60_000;
  return new Date(utcMillis).toISOString();
}

/** Minutes east of UTC for `timezone` at `date` (e.g. -300 for US Eastern DST off). */
function zoneOffsetMinutes(date: Date, timezone: string): number {
  const dtf = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    hour12: false,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  const parts = dtf.formatToParts(date);
  const map: Record<string, number> = {};
  for (const p of parts) if (p.type !== "literal") map[p.type] = Number(p.value);
  const asUtc = Date.UTC(
    map["year"]!,
    map["month"]! - 1,
    map["day"]!,
    map["hour"]! === 24 ? 0 : map["hour"]!,
    map["minute"]!,
    map["second"]!,
  );
  return Math.round((asUtc - date.getTime()) / 60_000);
}

/** Decide whether a user should get a streak warning, and the copy for it. */
export function streakWarning(c: ReminderCandidate): { warn: boolean; body: string } {
  // Only warn if there's a streak worth protecting and they haven't read yet.
  if (c.completedToday || c.streakDays < 1) return { warn: false, body: "" };
  return {
    warn: true,
    body: `Read ${Math.max(c.pagesRemaining, 1)} pages tonight to protect your ${c.streakDays}-day streak.`,
  };
}

/**
 * Build the set of reminder jobs for a batch of candidates for a given night.
 * Pure — returns jobs; the handler enqueues them.
 */
export function buildNightlyReminderJobs(
  candidates: ReminderCandidate[],
  now: Date = new Date(),
): ReminderJob[] {
  const jobs: ReminderJob[] = [];
  for (const c of candidates) {
    if (c.completedToday) continue; // nothing to nudge

    const sendAt = localTimeToUtcIso(now, c.timezone, c.reminderTimeLocal);
    const warn = streakWarning(c);

    if (warn.warn) {
      jobs.push({
        kind: "streak_warning",
        userId: c.userId,
        sendAt,
        title: "Keep your streak alive",
        body: warn.body,
      });
    } else {
      jobs.push({
        kind: "nightly_reminder",
        userId: c.userId,
        sendAt,
        title: "Tonight's reading is ready",
        body: `Your next step is ${Math.max(c.pagesRemaining, 1)} pages. A quick quiz unlocks after you read.`,
      });
    }
  }
  return jobs;
}

/** Handler stub — computes jobs then enqueues them for the push worker. */
export async function handleNightlyReminders(
  queue: JobQueue,
  candidates: ReminderCandidate[],
  now: Date = new Date(),
): Promise<ReminderJob[]> {
  const jobs = buildNightlyReminderJobs(candidates, now);
  for (const job of jobs) await queue.enqueue("push.send", job);
  return jobs;
}
