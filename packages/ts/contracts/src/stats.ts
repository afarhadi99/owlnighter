import { z } from "zod";
import { IsoDate } from "./common.js";

// ---- GET /v1/me/stats ----
/** One day in the trailing 7-day window (oldest first, ending today). */
export const StatsDay = z.object({
  date: IsoDate,
  read: z.boolean(),
  xp: z.number().int().nonnegative(),
});
export type StatsDay = z.infer<typeof StatsDay>;

export const MyStatsResponse = z.object({
  currentStreak: z.number().int().nonnegative(),
  longestStreak: z.number().int().nonnegative(),
  totalXp: z.number().int().nonnegative(),
  xpToday: z.number().int().nonnegative(),
  week: z.array(StatsDay).length(7),
});
export type MyStatsResponse = z.infer<typeof MyStatsResponse>;
