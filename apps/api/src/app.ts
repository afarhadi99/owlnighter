import Fastify, { type FastifyBaseLogger, type FastifyInstance } from "fastify";
import cors from "@fastify/cors";
import sensible from "@fastify/sensible";
import { buildOpenApiDocument } from "@owlnighter/contracts";
import { newRequestId } from "@owlnighter/shared";
import { buildDeps, type Deps } from "./deps.js";
import { registerRequestId } from "./plugins/request-id.js";
import { registerErrorHandler } from "./plugins/errors.js";
import { registerBookRoutes } from "./routes/books.js";
import { registerLibraryRoutes } from "./routes/library.js";
import { registerPlanRoutes } from "./routes/plans.js";
import { registerStepRoutes } from "./routes/steps.js";
import { registerQuizRoutes } from "./routes/quiz.js";
import { registerPushRoutes } from "./routes/push.js";
import { registerTtsRoutes } from "./routes/tts.js";
import { registerAdminRoutes } from "./routes/admin.js";
import { registerStatsRoutes } from "./routes/stats.js";
import "./types.js";

/**
 * Build a fully wired Fastify instance. Kept separate from server.ts so tests
 * can build the app without binding a port.
 */
export async function buildApp(deps: Deps = buildDeps()): Promise<FastifyInstance> {
  const app = Fastify({
    // Fastify v5 takes a pre-built pino instance via `loggerInstance` (the
    // `logger` option only accepts a boolean or a config object). Cast to the
    // base logger type so Fastify keeps its default generic — otherwise the
    // instance type specializes and the plugin/route helpers stop accepting it.
    loggerInstance: deps.config.logger as unknown as FastifyBaseLogger,
    // Use our request-id generator for Fastify's own req.id so log lines and the
    // x-request-id header agree. The request-id plugin still honours inbound ids.
    genReqId: () => newRequestId(),
    ajv: { customOptions: { removeAdditional: false } },
  });

  app.decorate("deps", deps);

  await app.register(cors, { origin: true });
  await app.register(sensible);

  registerRequestId(app);
  registerErrorHandler(app);

  // Liveness probe — no auth, no dependencies touched.
  app.get("/healthz", async () => ({ status: "ok", env: deps.config.env.NODE_ENV }));

  // Serve the generated OpenAPI document straight from the contracts package so
  // the spec can never drift from the running server.
  app.get("/openapi.json", async () => buildOpenApiDocument());

  // Contract-driven route registration (path/method/auth come from ENDPOINTS).
  registerBookRoutes(app, deps);
  registerLibraryRoutes(app, deps);
  registerPlanRoutes(app, deps);
  registerStepRoutes(app, deps);
  registerQuizRoutes(app, deps);
  registerPushRoutes(app, deps);
  registerTtsRoutes(app, deps);
  registerAdminRoutes(app, deps);
  registerStatsRoutes(app, deps);

  return app;
}
