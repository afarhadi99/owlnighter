import { createSign } from "node:crypto";
import type { Logger } from "@owlnighter/shared";

/**
 * FCM push pipeline.
 *
 * Two concerns live here, both dependency-free (node:crypto + global fetch):
 *  1. Pure message TEMPLATES for the four notification kinds. They take a small
 *     context and return { title, body, data } — trivially unit-testable.
 *  2. Delivery via FCM HTTP v1. We mint an OAuth access token by signing a
 *     service-account JWT (RS256) with node:crypto and exchanging it at Google's
 *     token endpoint — no firebase-admin dependency. When FCM is not configured
 *     we return { status: 'not_configured' } and never throw, so callers can
 *     degrade honestly instead of faking delivery.
 */

// ---- Templates ----

export type PushType =
  | "nightly_reminder"
  | "streak_warning"
  | "completion_celebration"
  | "re_engagement";

/** Optional copy inputs. Every field has a sensible default so a template can
 * render for a test push with no real context. */
export interface PushTemplateContext {
  bookTitle?: string;
  pagesRemaining?: number;
  streakDays?: number;
  xpEarned?: number;
  daysAway?: number;
}

/** FCM data values MUST be strings, so `data` is Record<string, string>. */
export interface PushTemplate {
  title: string;
  body: string;
  data: Record<string, string>;
}

export function nightlyReminderTemplate(ctx: PushTemplateContext = {}): PushTemplate {
  const pages = Math.max(ctx.pagesRemaining ?? 10, 1);
  const book = ctx.bookTitle ? ` of ${ctx.bookTitle}` : "";
  return {
    title: "Tonight's reading is ready",
    body: `Your next ${pages} pages${book} are waiting. A quick quiz unlocks once you finish.`,
    data: { type: "nightly_reminder", pagesRemaining: String(pages) },
  };
}

export function streakWarningTemplate(ctx: PushTemplateContext = {}): PushTemplate {
  const streak = Math.max(ctx.streakDays ?? 1, 1);
  const pages = Math.max(ctx.pagesRemaining ?? 10, 1);
  return {
    title: "Keep your streak alive",
    body: `Read ${pages} pages tonight to protect your ${streak}-day streak.`,
    data: { type: "streak_warning", streakDays: String(streak), pagesRemaining: String(pages) },
  };
}

export function completionCelebrationTemplate(ctx: PushTemplateContext = {}): PushTemplate {
  const streak = Math.max(ctx.streakDays ?? 1, 1);
  const xp = Math.max(ctx.xpEarned ?? 20, 0);
  return {
    title: "Nice work tonight!",
    body: `You finished tonight's reading and earned ${xp} XP. Streak: ${streak} day${streak === 1 ? "" : "s"}.`,
    data: { type: "completion_celebration", streakDays: String(streak), xpEarned: String(xp) },
  };
}

export function reEngagementTemplate(ctx: PushTemplateContext = {}): PushTemplate {
  const days = Math.max(ctx.daysAway ?? 3, 1);
  const book = ctx.bookTitle ? ` ${ctx.bookTitle}` : " your book";
  return {
    title: "Your book misses you",
    body: `It's been ${days} days. Pick up${book} tonight — even a few pages keeps the habit going.`,
    data: { type: "re_engagement", daysAway: String(days) },
  };
}

const TEMPLATES: Record<PushType, (ctx?: PushTemplateContext) => PushTemplate> = {
  nightly_reminder: nightlyReminderTemplate,
  streak_warning: streakWarningTemplate,
  completion_celebration: completionCelebrationTemplate,
  re_engagement: reEngagementTemplate,
};

/** Dispatch to the template for `type`, throwing for an unknown kind. */
export function pushTemplateFor(type: PushType, ctx: PushTemplateContext = {}): PushTemplate {
  const fn = TEMPLATES[type];
  if (!fn) throw new Error(`Unknown push type: ${type}`);
  return fn(ctx);
}

// ---- Delivery (FCM HTTP v1) ----

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const GOOGLE_TOKEN_URI = "https://oauth2.googleapis.com/token";
const FCM_SEND_BASE = "https://fcm.googleapis.com/v1/projects";

export interface PushDeps {
  projectId: string;
  serviceAccountJson: string;
  logger?: Logger;
  /** Injectable for tests; defaults to global fetch. */
  fetchImpl?: typeof fetch;
  /** Injectable clock (seconds since epoch) for deterministic JWT claims. */
  nowSeconds?: () => number;
}

export interface SendPushInput {
  token: string;
  notification: { title: string; body: string };
  data?: Record<string, string>;
  /** Pre-minted OAuth token to skip re-minting when sending to many tokens. */
  accessToken?: string;
}

export type SendPushResult =
  | { status: "sent"; messageName: string }
  | { status: "not_configured"; reason: string }
  | { status: "error"; reason: string };

interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri?: string;
}

function base64url(input: Buffer | string): string {
  return Buffer.from(input).toString("base64url");
}

function parseServiceAccount(json: string): ServiceAccount | undefined {
  try {
    const sa = JSON.parse(json) as Partial<ServiceAccount>;
    if (!sa.client_email || !sa.private_key) return undefined;
    return {
      client_email: sa.client_email,
      private_key: sa.private_key,
      ...(sa.token_uri ? { token_uri: sa.token_uri } : {}),
    };
  } catch {
    return undefined;
  }
}

/**
 * Mint a short-lived FCM OAuth access token from the service-account JSON by
 * signing a JWT (RS256) and exchanging it via the JWT-bearer grant. Returns
 * null when FCM is unconfigured or the exchange fails (logged, never throws).
 */
export async function mintFcmAccessToken(deps: PushDeps): Promise<string | null> {
  if (!deps.projectId || !deps.serviceAccountJson) return null;
  const sa = parseServiceAccount(deps.serviceAccountJson);
  if (!sa) {
    deps.logger?.warn("FCM_SERVICE_ACCOUNT_JSON is not valid JSON with client_email/private_key.");
    return null;
  }

  const fetchImpl = deps.fetchImpl ?? fetch;
  const now = deps.nowSeconds ? deps.nowSeconds() : Math.floor(Date.now() / 1000);
  const tokenUri = sa.token_uri ?? GOOGLE_TOKEN_URI;

  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(
    JSON.stringify({ iss: sa.client_email, scope: FCM_SCOPE, aud: tokenUri, iat: now, exp: now + 3600 }),
  );
  const signingInput = `${header}.${claims}`;
  const signer = createSign("RSA-SHA256");
  signer.update(signingInput);
  signer.end();
  const signature = signer.sign(sa.private_key).toString("base64url");
  const jwt = `${signingInput}.${signature}`;

  const res = await fetchImpl(tokenUri, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }).toString(),
  });
  if (!res.ok) {
    const detail = await res.text().catch(() => "");
    deps.logger?.error({ status: res.status, detail: detail.slice(0, 300) }, "FCM token exchange failed");
    return null;
  }
  const json = (await res.json()) as { access_token?: string };
  return json.access_token ?? null;
}

/**
 * Send one message via FCM HTTP v1. Returns a structured result rather than
 * throwing so a batch caller (e.g. the admin push-test endpoint) can build a
 * per-token summary. `not_configured` is returned verbatim when FCM env is empty.
 */
export async function sendPush(deps: PushDeps, input: SendPushInput): Promise<SendPushResult> {
  if (!deps.projectId || !deps.serviceAccountJson) {
    return { status: "not_configured", reason: "FCM_PROJECT_ID / FCM_SERVICE_ACCOUNT_JSON are not set." };
  }

  const accessToken = input.accessToken ?? (await mintFcmAccessToken(deps)) ?? undefined;
  if (!accessToken) {
    return { status: "error", reason: "Could not mint an FCM OAuth access token (check service account JSON)." };
  }

  const fetchImpl = deps.fetchImpl ?? fetch;
  const message: Record<string, unknown> = {
    token: input.token,
    notification: { title: input.notification.title, body: input.notification.body },
  };
  if (input.data && Object.keys(input.data).length > 0) message["data"] = input.data;

  const res = await fetchImpl(`${FCM_SEND_BASE}/${deps.projectId}/messages`, {
    method: "POST",
    headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json" },
    body: JSON.stringify({ message }),
  });
  if (!res.ok) {
    const detail = await res.text().catch(() => "");
    deps.logger?.warn({ status: res.status, detail: detail.slice(0, 300) }, "FCM send failed");
    return { status: "error", reason: `FCM send failed (${res.status}): ${detail.slice(0, 200)}` };
  }
  const json = (await res.json()) as { name?: string };
  return { status: "sent", messageName: json.name ?? "" };
}
