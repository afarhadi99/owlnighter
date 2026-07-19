import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { buildApp } from "./app.js";
import { getConfig } from "./config.js";

// loadEnv() (called by getConfig() below) only reads process.env — it does not
// read .env itself. `pnpm dev`/`tsx watch` invoke this file directly with no
// --env-file flag, so without this, every var silently falls back to its
// Zod default (e.g. DATABASE_URL defaults to 127.0.0.1:54322 — a different,
// unrelated project's Postgres container — instead of failing loudly).
// process.loadEnvFile is a no-op-safe try/catch: production has no .env file
// and gets its config from the real environment instead.
try {
  process.loadEnvFile(resolve(dirname(fileURLToPath(import.meta.url)), "../../../.env"));
} catch {
  // No .env file (production) — env vars come from the real environment.
}

/** Boot the HTTP server. Fails fast on env/config errors (loadEnv throws). */
async function main(): Promise<void> {
  const { env, logger } = getConfig();
  const app = await buildApp();

  try {
    await app.listen({ host: env.API_HOST, port: env.API_PORT });
    logger.info({ host: env.API_HOST, port: env.API_PORT }, "owlnighter API listening");
  } catch (err) {
    logger.error({ err }, "failed to start server");
    process.exit(1);
  }

  // Clean shutdown so the DB pool drains and in-flight requests finish.
  for (const signal of ["SIGINT", "SIGTERM"] as const) {
    process.on(signal, () => {
      logger.info({ signal }, "shutting down");
      void app.close().then(() => process.exit(0));
    });
  }
}

void main();
