import type { Logger } from "@owlnighter/shared";
import { sendPush, type PushDeps } from "./push.js";

/**
 * Job handler registry. The queue worker looks a job up by name and runs its
 * handler with the decoded payload. Concrete side-effect wiring (DB, storage,
 * FCM) is passed in via `ctx` so handlers stay unit-testable.
 */
export interface JobContext {
  logger?: Logger;
  /** FCM delivery config. When present, `push.send` actually delivers; when
   * absent (or unconfigured) it degrades to a log line. */
  push?: PushDeps;
}

/** Payload shape for a `push.send` job. */
interface PushSendPayload {
  token?: string;
  notification?: { title: string; body: string };
  data?: Record<string, string>;
}

export type JobHandler = (payload: unknown, ctx: JobContext) => Promise<void>;

export interface JobHandlerRegistry {
  [jobName: string]: JobHandler;
}

/**
 * Default handlers. These are intentionally thin stubs — the real send/persist
 * work is owned by the API layer's wiring; jobs here just define the contract
 * of what each named job does.
 */
export const jobHandlers: JobHandlerRegistry = {
  // Push delivery via FCM. When ctx.push is wired and the payload carries a
  // token + notification, deliver for real; otherwise degrade to a log line so
  // the queue still drains cleanly in dev/tests.
  "push.send": async (payload, ctx) => {
    const p = (payload ?? {}) as PushSendPayload;
    if (ctx.push && p.token && p.notification) {
      const result = await sendPush(ctx.push, {
        token: p.token,
        notification: p.notification,
        ...(p.data ? { data: p.data } : {}),
      });
      ctx.logger?.info({ status: result.status }, "job.push.send");
      return;
    }
    ctx.logger?.info({ payload }, "job.push.send");
  },
  // TTS pre-generation: call ensureTtsAsset with the job's text + voice params.
  "tts.pregenerate": async (payload, ctx) => {
    ctx.logger?.info({ payload }, "job.tts.pregenerate");
  },
  // Nightly fan-out: enumerate due users and enqueue push.send jobs.
  "reminders.nightly": async (payload, ctx) => {
    ctx.logger?.info({ payload }, "job.reminders.nightly");
  },
};

/** Look up + run a handler, throwing a clear error for unknown job names. */
export async function runJob(
  registry: JobHandlerRegistry,
  name: string,
  payload: unknown,
  ctx: JobContext = {},
): Promise<void> {
  const handler = registry[name];
  if (!handler) throw new Error(`No handler registered for job "${name}".`);
  await handler(payload, ctx);
}
