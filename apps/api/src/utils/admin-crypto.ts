import { randomBytes, createHash } from "node:crypto";

/** 256 bits of randomness, base64url-encoded (URL/cookie/header safe). */
export function generateSessionToken(): string {
  return randomBytes(32).toString("base64url");
}

/** One-way SHA-256 hex digest. Only the hash is ever persisted — never the raw token. */
export function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}
