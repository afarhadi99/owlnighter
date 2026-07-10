import { test } from "node:test";
import assert from "node:assert/strict";
import {
  nightlyReminderTemplate,
  pushTemplateFor,
  sendPush,
  type PushType,
} from "@owlnighter/jobs";

const ALL_TYPES: PushType[] = [
  "nightly_reminder",
  "streak_warning",
  "completion_celebration",
  "re_engagement",
];

test("nightly reminder template interpolates pages + book and tags its type", () => {
  const t = nightlyReminderTemplate({ pagesRemaining: 12, bookTitle: "Dune" });
  assert.equal(t.data["type"], "nightly_reminder");
  assert.match(t.body, /12 pages/);
  assert.match(t.body, /Dune/);
});

test("pushTemplateFor covers all 4 types with string-only data values", () => {
  for (const type of ALL_TYPES) {
    const t = pushTemplateFor(type, { streakDays: 5, pagesRemaining: 8, xpEarned: 30, daysAway: 4 });
    assert.equal(t.data["type"], type);
    assert.ok(t.title.length > 0, `${type} has a title`);
    assert.ok(t.body.length > 0, `${type} has a body`);
    for (const v of Object.values(t.data)) assert.equal(typeof v, "string");
  }
});

test("sendPush returns not_configured (and never throws) when FCM env is empty", async () => {
  const res = await sendPush(
    { projectId: "", serviceAccountJson: "" },
    { token: "device-abc", notification: { title: "t", body: "b" } },
  );
  assert.equal(res.status, "not_configured");
});
