import { test } from "node:test";
import assert from "node:assert/strict";
import { isTaskConfigured } from "./ai-availability.js";
import { fakeDeps, fakeSettings } from "../test/helpers.js";

test("isTaskConfigured is true when GEMINI_API_KEY is set, regardless of task", async () => {
  const deps = fakeDeps({ env: { GEMINI_API_KEY: "test-key" } });
  assert.equal(await isTaskConfigured(deps, "book_grounding"), true);
  assert.equal(await isTaskConfigured(deps, "plan_generation"), true);
});

test("isTaskConfigured is false when nothing is configured", async () => {
  const deps = fakeDeps({ env: { GEMINI_API_KEY: "", GROQ_API_KEY: "" } });
  assert.equal(await isTaskConfigured(deps, "plan_generation"), false);
});

test("isTaskConfigured is true when AI Tutor API has a key AND a workflow id for the task", async () => {
  const deps = fakeDeps({
    env: { GEMINI_API_KEY: "", GROQ_API_KEY: "" },
    settings: fakeSettings({
      rows: [
        { key: "ai_provider.ai_tutor_api.api_key", value: "sk_test" },
        { key: "ai_provider.ai_tutor_api.workflow_id.plan_generation", value: "wf_123" },
      ],
    }),
  });
  assert.equal(await isTaskConfigured(deps, "plan_generation"), true);
  // A different task with no workflow id configured for it is still unconfigured.
  assert.equal(await isTaskConfigured(deps, "book_grounding"), false);
});

test("isTaskConfigured is false when AI Tutor API has a key but no workflow id for the task", async () => {
  const deps = fakeDeps({
    env: { GEMINI_API_KEY: "", GROQ_API_KEY: "" },
    settings: fakeSettings({ rows: [{ key: "ai_provider.ai_tutor_api.api_key", value: "sk_test" }] }),
  });
  assert.equal(await isTaskConfigured(deps, "plan_generation"), false);
});
