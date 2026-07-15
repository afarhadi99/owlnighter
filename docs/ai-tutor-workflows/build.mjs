// Regenerates quiz-generation-workflow.json. Run this — never hand-edit the
// JSON — whenever apps/api/src/services/quiz.ts's GeneratedQuiz schema
// changes, so structuredOutputSchema can never drift from the real contract
// via a hand-typed nested-JSON-string transcription error.
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));

// Mirrors apps/api/src/services/quiz.ts's GeneratedQuiz Zod schema exactly.
const structuredOutputSchema = {
  type: "object",
  properties: {
    questions: {
      type: "array",
      minItems: 1,
      items: {
        type: "object",
        properties: {
          kind: { type: "string", enum: ["multiple_choice", "true_false", "short_answer"] },
          prompt: { type: "string" },
          options: { type: "array", items: { type: "string" } },
          correctAnswer: { type: "string" },
          explanation: { type: "string" },
          sourceCitationIndex: { type: "integer" },
        },
        required: ["kind", "prompt", "correctAnswer"],
        additionalProperties: false,
      },
    },
  },
  required: ["questions"],
  additionalProperties: false,
};

// Keys confirmed against manage-prompt's own ModelSettings TS type
// (components/console/workflow/workflow-model-settings.tsx).
const modelSettings = {
  temperature: 0.4,
  maxTokens: 2048,
  enableWebSearch: true,
  reasoningEffort: "none",
  structuredOutputSchema: JSON.stringify(structuredOutputSchema),
};

// Top-level shape confirmed against manage-prompt's WorkflowSchema
// (lib/utils/workflow.ts) and its export routes' exportData shape.
const workflow = {
  name: "owlnighter Quiz Generation",
  model: "gemini-3.5-flash",
  template: "{{system}}\n\n{{user}}",
  instruction: "",
  modelSettings: JSON.stringify(modelSettings),
  cacheControlTtl: 0,
  inputs: [
    { name: "system", label: "System instructions", type: "textarea" },
    { name: "user", label: "User prompt", type: "textarea" },
  ],
};

writeFileSync(join(here, "quiz-generation-workflow.json"), JSON.stringify(workflow, null, 2) + "\n");
console.log("Wrote quiz-generation-workflow.json");
