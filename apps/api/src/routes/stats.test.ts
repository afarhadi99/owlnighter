import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../app.js";
import { DEV_BEARER, DEV_USER_ID, fakeDeps, tableRows } from "../test/helpers.js";

test("GET /v1/me/stats derives streaks, xp, and the trailing 7-day week", async () => {
  const { schema } = await import("@owlnighter/db");
  const today = new Date();
  const iso = (daysAgo: number) => new Date(today.getTime() - daysAgo * 86_400_000).toISOString().slice(0, 10);
  const byTable = tableRows(
    [schema.profiles, []],
    [
      schema.streakDays,
      [
        { userId: DEV_USER_ID, day: iso(0), xp: 20 },
        { userId: DEV_USER_ID, day: iso(1), xp: 20 },
        { userId: DEV_USER_ID, day: iso(2), xp: 10 },
        // gap at day 3 — breaks the streak further back
        { userId: DEV_USER_ID, day: iso(5), xp: 20 },
      ],
    ],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "GET", url: "/v1/me/stats", headers: DEV_BEARER });
    assert.equal(res.statusCode, 200);
    const body = res.json() as {
      currentStreak: number;
      longestStreak: number;
      totalXp: number;
      xpToday: number;
      week: Array<{ date: string; read: boolean; xp: number }>;
    };
    assert.equal(body.currentStreak, 3); // today, yesterday, day-before are consecutive
    assert.equal(body.longestStreak, 3);
    assert.equal(body.totalXp, 70);
    assert.equal(body.xpToday, 20);
    assert.equal(body.week.length, 7);
    assert.equal(body.week[6]!.date, iso(0)); // last entry is today
    assert.equal(body.week[6]!.read, true);
    assert.equal(body.week[6]!.xp, 20);
    assert.equal(body.week[0]!.date, iso(6)); // first entry is 6 days ago
    assert.equal(body.week[0]!.read, false);
  } finally {
    await app.close();
  }
});

test("GET /v1/me/stats requires auth (401)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "GET", url: "/v1/me/stats" });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});
