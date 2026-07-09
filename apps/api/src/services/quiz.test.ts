import { test } from "node:test";
import assert from "node:assert/strict";
import { computeStreaks } from "./quiz.js";

test("computeStreaks: no days → zero", () => {
  assert.deepEqual(computeStreaks([], "2026-07-09"), { current: 0, longest: 0 });
});

test("computeStreaks: single day today → current 1", () => {
  assert.deepEqual(computeStreaks(["2026-07-09"], "2026-07-09"), { current: 1, longest: 1 });
});

test("computeStreaks: consecutive run ending today", () => {
  const days = ["2026-07-07", "2026-07-08", "2026-07-09"];
  assert.deepEqual(computeStreaks(days, "2026-07-09"), { current: 3, longest: 3 });
});

test("computeStreaks: gap breaks current but longest is remembered", () => {
  // A 3-day run, a gap, then a 2-day run ending today.
  const days = ["2026-07-01", "2026-07-02", "2026-07-03", "2026-07-08", "2026-07-09"];
  assert.deepEqual(computeStreaks(days, "2026-07-09"), { current: 2, longest: 3 });
});

test("computeStreaks: last day is yesterday → grace keeps current alive", () => {
  const days = ["2026-07-07", "2026-07-08"];
  assert.deepEqual(computeStreaks(days, "2026-07-09"), { current: 2, longest: 2 });
});

test("computeStreaks: last day older than yesterday → current resets to 0", () => {
  const days = ["2026-07-06", "2026-07-07"];
  assert.deepEqual(computeStreaks(days, "2026-07-09"), { current: 0, longest: 2 });
});
