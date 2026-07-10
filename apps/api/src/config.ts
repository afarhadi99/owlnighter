import { loadEnv, createLogger, resolveFlags, type Env, type FeatureFlags, type Logger } from "@owlnighter/shared";

/**
 * Process-wide configuration, resolved once at boot. Everything downstream
 * (plugins, services, routes) reads from this single object so there is exactly
 * one place env is parsed and one logger instance.
 */
export interface AppConfig {
  env: Env;
  flags: FeatureFlags;
  logger: Logger;
}

let cached: AppConfig | undefined;

export function getConfig(): AppConfig {
  if (cached) return cached;
  const env = loadEnv();
  cached = {
    env,
    flags: resolveFlags(),
    logger: createLogger(env.LOG_LEVEL),
  };
  return cached;
}

/** Fixed dev user id used when a DEV bearer token is presented in development. */
export const DEV_USER_ID = "00000000-0000-4000-8000-0000000000de";
