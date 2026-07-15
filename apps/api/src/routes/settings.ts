import type { FastifyInstance } from "fastify";
import type {
  AdminAiModelsResponse,
  AdminSettingsResponse,
  AdminUpdateSettingRequest,
  AdminUpdateSettingResponse,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { requireAdminAccount } from "../plugins/admin-session.js";
import { badRequest } from "../plugins/errors.js";
import { getAiModels } from "../services/ai-models.js";
import { getAllSettings, updateSetting } from "../services/settings.js";
import { register } from "./helpers.js";

export function registerSettingsRoutes(app: FastifyInstance, deps: Deps): void {
  register<never, AdminSettingsResponse>(app, deps, "adminGetSettings", async () => {
    return getAllSettings(deps);
  });

  register<AdminUpdateSettingRequest, AdminUpdateSettingResponse>(
    app,
    deps,
    "adminPutSetting",
    async ({ req, body, params }) => {
      const admin = requireAdminAccount(req);
      const key = params["key"];
      if (!key) throw badRequest("Missing setting key.");
      return updateSetting(deps, admin.id, key, body.value);
    },
  );

  register<never, AdminAiModelsResponse>(app, deps, "adminGetAiModels", async ({ req }) => {
    requireAdminAccount(req);
    const provider = (req.query as Record<string, string> | undefined)?.["provider"];
    return getAiModels(deps, provider);
  });
}
