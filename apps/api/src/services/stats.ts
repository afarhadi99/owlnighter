import { eq } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import { type MyStatsResponse, type StatsDay } from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import type { AuthUser } from "../types.js";
import { computeStreaks } from "./quiz.js";

/**
 * Streaks, total/today XP, and the trailing 7-day window (oldest first, ending
 * today) — all derived from the `streak_days` ledger. Reuses `computeStreaks`
 * (the same pure streak math `submitQuiz` uses) so the two never drift.
 */
export async function getMyStats(deps: Deps, user: AuthUser): Promise<MyStatsResponse> {
  const today = new Date().toISOString().slice(0, 10);

  const rows = await deps.db.select().from(schema.streakDays).where(eq(schema.streakDays.userId, user.id));

  const xpByDay = new Map<string, number>();
  for (const r of rows) {
    xpByDay.set(r.day, (xpByDay.get(r.day) ?? 0) + r.xp);
  }
  const sortedDays = [...xpByDay.keys()].sort();

  const { current, longest } = computeStreaks(sortedDays, today);
  const totalXp = sortedDays.reduce((sum, d) => sum + xpByDay.get(d)!, 0);
  const xpToday = xpByDay.get(today) ?? 0;

  const todayMs = Date.parse(`${today}T00:00:00Z`);
  const week: StatsDay[] = [];
  for (let i = 6; i >= 0; i--) {
    const date = new Date(todayMs - i * 86_400_000).toISOString().slice(0, 10);
    const xp = xpByDay.get(date) ?? 0;
    week.push({ date, read: xp > 0, xp });
  }

  return { currentStreak: current, longestStreak: longest, totalXp, xpToday, week };
}
