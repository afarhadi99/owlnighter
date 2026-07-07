import { buildApp } from "./app.js";
import { getConfig } from "./config.js";

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
