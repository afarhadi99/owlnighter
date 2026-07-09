import { test } from "node:test";
import assert from "node:assert/strict";
import type { Deps } from "../deps.js";
import { reviewBucketFor } from "./grounding.js";

/** reviewBucketFor only reads the two threshold env values off deps. */
function fakeDeps(autoAccept = 0.85, reviewFloor = 0.6): Deps {
  return {
    config: { env: { GROUNDING_AUTO_ACCEPT: autoAccept, GROUNDING_REVIEW_FLOOR: reviewFloor } },
  } as unknown as Deps;
}

test("reviewBucketFor: >= auto-accept threshold → auto_accepted", () => {
  const deps = fakeDeps();
  assert.equal(reviewBucketFor(deps, 0.85), "auto_accepted");
  assert.equal(reviewBucketFor(deps, 0.99), "auto_accepted");
});

test("reviewBucketFor: between floor and auto-accept → needs_review", () => {
  const deps = fakeDeps();
  assert.equal(reviewBucketFor(deps, 0.6), "needs_review");
  assert.equal(reviewBucketFor(deps, 0.84), "needs_review");
});

test("reviewBucketFor: below review floor → limited", () => {
  const deps = fakeDeps();
  assert.equal(reviewBucketFor(deps, 0.59), "limited");
  assert.equal(reviewBucketFor(deps, 0), "limited");
});

test("reviewBucketFor: honours custom thresholds", () => {
  const deps = fakeDeps(0.9, 0.5);
  assert.equal(reviewBucketFor(deps, 0.85), "needs_review");
  assert.equal(reviewBucketFor(deps, 0.49), "limited");
  assert.equal(reviewBucketFor(deps, 0.95), "auto_accepted");
});
