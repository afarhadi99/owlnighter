import { pino, type Logger } from "pino";

export type { Logger };

/** Structured JSON logger. Every AI/TTS/push call should log with a requestId. */
export function createLogger(level = "info"): Logger {
  return pino({
    level,
    base: { app: "owlnighter" },
    timestamp: pino.stdTimeFunctions.isoTime,
  });
}

export const logger = createLogger(process.env["LOG_LEVEL"] ?? "info");
