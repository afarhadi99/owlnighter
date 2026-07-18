// Regenerates BOTH single-sourced quiz-generation artifacts. Run this — never
// hand-edit the outputs — whenever the quiz framing text, the named-variable
// spec, or apps/api/src/services/quiz.ts's GeneratedQuiz schema changes:
//
//   1. quiz-generation-workflow.json — the AI Tutor API workflow. Its
//      `template` bakes in the framing and interpolates the named variables,
//      and its `structuredOutputSchema` mirrors the GeneratedQuiz Zod shape (so
//      it can never drift via a hand-typed nested-JSON-string transcription
//      error).
//   2. apps/api/src/services/quiz-prompt.generated.ts — exports
//      QUIZ_SYSTEM_FRAMING, the exact same framing string, for the app's
//      Gemini/Groq/OpenRouter path. Emitting both from here is what guarantees
//      the app framing and the workflow framing cannot silently drift.
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));

// ── Single source of truth: framing text ────────────────────────────────────
// The static system/framing instructions. Baked into the workflow `template`
// (the confirmed-working interpolation path) AND exported to the app as
// QUIZ_SYSTEM_FRAMING. Change quiz behavior here, in one place.
const framingLines = [
  "You write short comprehension quizzes for a nightly reading app.",
  "Each question needs a single unambiguous correctAnswer.",
  "For multiple_choice, include 3-4 options and set correctAnswer to the exact option text.",
  "For true_false, correctAnswer is 'true' or 'false'.",
  "Do NOT invent page-specific facts unless the provided context supports them.",
  "Output valid JSON only.",
];

// A worked example of the exact output shape, appended after the prose rules.
// Keep this in sync with GeneratedQuiz (apps/api/src/services/quiz.ts) — it
// covers the two kinds with explicit formatting rules above (multiple_choice,
// true_false); short_answer isn't shown since no rule governs its shape yet.
// The subject matter and question count are placeholders on purpose — the
// model must write its own questions from the real step content and the
// actual requested count, not copy this example's.
const exampleOutput = {
  questions: [
    {
      kind: "multiple_choice",
      prompt: "What does the protagonist decide at the end of this chapter?",
      options: ["To stay home", "To join the quest", "To return the ring", "To warn the village"],
      correctAnswer: "To join the quest",
      explanation: "The chapter ends with the protagonist agreeing to accompany the group.",
      sourceCitationIndex: 0,
    },
    {
      kind: "true_false",
      prompt: "The chapter takes place entirely at night.",
      correctAnswer: "false",
      explanation: "Most of the chapter's events happen during the day.",
    },
  ],
};
const QUIZ_SYSTEM_FRAMING =
  framingLines.join(" ") +
  "\n\nExample output shape (illustrative only — write your own questions from the actual " +
  "step content and the requested question count; do not reuse this example's subject " +
  "matter or count):\n" +
  JSON.stringify(exampleOutput, null, 2);

// ── Single source of truth: the ordered named-variable spec ──────────────────
// `name` must match BOTH the {{placeholder}} in the template AND the key
// apps/api/src/services/quiz.ts's quizVariables() emits. `promptLabel` is the
// inline label in the template's layout block (null = rendered as its own
// standalone block with no inline label). `label` is the human label shown for
// the workflow input in the AI Tutor API console.
const variables = [
  { name: "stepTitle", label: "Step title", promptLabel: "Step" },
  { name: "chapterHint", label: "Chapter hint", promptLabel: "Chapter" },
  { name: "pageRange", label: "Page range", promptLabel: "Pages" },
  { name: "quizMode", label: "Quiz mode", promptLabel: "Quiz mode" },
  { name: "questionCount", label: "Question count", promptLabel: "Question count" },
  { name: "readerContext", label: "Reader context", promptLabel: null },
];

// Framing, a blank line, the labeled layout of the inline variables, a blank
// line, then the standalone reader-context block.
const labeledLayout = variables
  .filter((v) => v.promptLabel != null)
  .map((v) => `${v.promptLabel}: {{${v.name}}}`)
  .join("\n");
const template = `${QUIZ_SYSTEM_FRAMING}\n\n${labeledLayout}\n\n{{readerContext}}`;

const inputs = variables.map((v) => ({ name: v.name, label: v.label, type: "textarea" }));

// ── GeneratedQuiz JSON Schema (mirrors quiz.ts's Zod schema exactly) ──────────
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
          sourceCitationIndex: { type: "integer", minimum: 0, maximum: 1000 },
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
  maxTokens: 16000,
  enableWebSearch: true,
  reasoningEffort: "none",
  structuredOutputSchema: JSON.stringify(structuredOutputSchema),
};

// Top-level shape confirmed against manage-prompt's WorkflowSchema
// (lib/utils/workflow.ts) and its export routes' exportData shape.
const workflow = {
  name: "owlnighter Quiz Generation",
  model: "gemini-3.5-flash",
  template,
  instruction: "",
  modelSettings: JSON.stringify(modelSettings),
  cacheControlTtl: 0,
  inputs,
};

writeFileSync(join(here, "quiz-generation-workflow.json"), JSON.stringify(workflow, null, 2) + "\n");
console.log("Wrote quiz-generation-workflow.json");

// Emit the app-side framing module. Path is relative to this script so the
// generator stays runnable from any cwd.
const generatedTs =
  "// GENERATED by docs/ai-tutor-workflows/build.mjs — do not edit by hand; run `node docs/ai-tutor-workflows/build.mjs` to regenerate.\n" +
  `export const QUIZ_SYSTEM_FRAMING = ${JSON.stringify(QUIZ_SYSTEM_FRAMING)};\n`;
const generatedTsPath = join(here, "..", "..", "apps", "api", "src", "services", "quiz-prompt.generated.ts");
writeFileSync(generatedTsPath, generatedTs);
console.log("Wrote apps/api/src/services/quiz-prompt.generated.ts");
