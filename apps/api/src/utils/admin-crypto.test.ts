import { test } from "node:test";
import assert from "node:assert/strict";
import { generateSessionToken, hashToken } from "./admin-crypto.js";

test("generateSessionToken produces long, URL-safe, non-colliding tokens", () => {
  const seen = new Set<string>();
  for (let i = 0; i < 10_000; i++) {
    const t = generateSessionToken();
    assert.ok(t.length >= 32, "token should be reasonably long");
    assert.match(t, /^[A-Za-z0-9_-]+$/, "token should be URL-safe");
    assert.ok(!seen.has(t), "tokens should not collide");
    seen.add(t);
  }
});

test("hashToken is deterministic and one-way", () => {
  const token = "abc123";
  const h1 = hashToken(token);
  const h2 = hashToken(token);
  assert.equal(h1, h2);
  assert.notEqual(h1, token);
  assert.match(h1, /^[a-f0-9]{64}$/, "sha256 hex digest is 64 chars");
});

test("hashToken differs for different tokens", () => {
  assert.notEqual(hashToken("a"), hashToken("b"));
});
