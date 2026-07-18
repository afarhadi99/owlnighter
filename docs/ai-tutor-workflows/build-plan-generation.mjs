// Regenerates plan-generation-workflow.json — the AI Tutor API workflow for the
// `plan_generation` task. Run this — never hand-edit the output — whenever
// apps/api/src/services/plans.ts's `GroundedBookPlan` schema (or the `PlanStep`
// and `BookIdentity` contracts it embeds, packages/ts/contracts/src/plan.ts and
// book.ts) changes:
//
//   node docs/ai-tutor-workflows/build-plan-generation.mjs
//
// Like book-grounding (and unlike quiz), this is a GENERIC
// {{system}}\n\n{{user}} PASSTHROUGH workflow, not a discrete-named-variable
// template. plans.ts calls deps.ai.generateObject with composed `system`/`user`
// strings and does NOT emit a named-variable map, so owlnighter's
// AiTutorApiAdapter (packages/ts/ai/src/aiTutorApi.ts) posts the generic
// `{ system, user }` fallback body — the template just concatenates them. The
// framing (the SYSTEM_PROMPT in plans.ts) arrives at runtime as the `system`
// value; it is NOT baked into the template, so there is nothing to single-source
// into an app-side constant here.
//
// What IS single-sourced from this script is `modelSettings.structuredOutputSchema`
// — the JSON Schema mirroring plans.ts's `GroundedBookPlan` Zod shape, so the
// baked schema can never drift via a hand-typed nested-JSON-string transcription.
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));

// The generic passthrough template. `system` and `user` are supplied verbatim by
// plans.ts at runtime via the adapter's `{ system, user }` fallback body.
const template = "{{system}}\n\n{{user}}";

const inputs = [
  { name: "system", label: "System", type: "textarea" },
  { name: "user", label: "User", type: "textarea" },
];

// ── BookIdentity JSON Schema (mirrors packages/ts/contracts/src/book.ts) ──────
// Identical to the book-grounding generator's copy; kept inline so each generator
// is self-contained and independently runnable, matching build.mjs's style.
const bookIdentitySchema = {
  type: "object",
  properties: {
    canonicalTitle: { type: "string", minLength: 1 },
    authors: { type: "array", minItems: 1, items: { type: "string" } },
    editionLabel: { type: "string" },
    isbn13: { type: "string", pattern: "^\\d{13}$" },
    googleBooksId: { type: "string" },
    openLibraryKey: { type: "string" },
    pageCount: { type: "integer", minimum: 1, maximum: 100000 },
    languageCode: { type: "string", minLength: 2, maxLength: 2 },
    publishedYear: { type: "integer", minimum: -3000, maximum: 2100 },
    coverUrl: { type: "string", format: "uri" },
    confidence: { type: "number", minimum: 0, maximum: 1 },
  },
  required: ["canonicalTitle", "authors", "confidence"],
  additionalProperties: false,
};

// ── PlanStep JSON Schema (mirrors plan.ts's PlanStep Zod shape) ───────────────
const planStepSchema = {
  type: "object",
  properties: {
    stepIndex: { type: "integer", minimum: 0, maximum: 10000 },
    title: { type: "string" },
    pageStart: { type: "integer", minimum: 0, maximum: 100000 },
    pageEnd: { type: "integer", minimum: 0, maximum: 100000 },
    chapterHint: { type: "string" },
    quizMode: { type: "string", enum: ["grounded", "preview", "user_text", "fallback"] },
    prompt: { type: "string" },
    confidence: { type: "number", minimum: 0, maximum: 1 },
  },
  required: ["stepIndex", "title", "quizMode", "prompt", "confidence"],
  additionalProperties: false,
};

// ── GroundedBookPlan JSON Schema (mirrors plans.ts's Zod schema exactly) ──────
const structuredOutputSchema = {
  type: "object",
  properties: {
    book: bookIdentitySchema,
    pacingMode: { type: "string", enum: ["gentle", "standard", "intensive"] },
    nightlyGoalPages: { type: "integer", minimum: 3, maximum: 50 },
    rationale: { type: "string" },
    steps: { type: "array", minItems: 1, items: planStepSchema },
    citations: {
      type: "array",
      items: {
        type: "object",
        properties: {
          title: { type: "string" },
          url: { type: "string", format: "uri" },
          reason: { type: "string" },
        },
        required: ["title", "url", "reason"],
        additionalProperties: false,
      },
    },
  },
  required: ["book", "pacingMode", "nightlyGoalPages", "rationale", "steps"],
  additionalProperties: false,
};

// Keys confirmed against manage-prompt's own ModelSettings TS type
// (components/console/workflow/workflow-model-settings.tsx). enableWebSearch is
// FALSE: plans.ts calls generateObject with requireGrounding: false — grounding
// already happened at book-ground time and its facts are baked into the prompt,
// so the plan pass deliberately does not need live search grounding.
const modelSettings = {
  temperature: 0.4,
  maxTokens: 16000,
  enableWebSearch: false,
  reasoningEffort: "none",
  structuredOutputSchema: JSON.stringify(structuredOutputSchema),
};

const workflow = {
  name: "owlnighter Plan Generation",
  model: "gemini-3.5-flash",
  template,
  instruction: "",
  modelSettings: JSON.stringify(modelSettings),
  cacheControlTtl: 0,
  inputs,
};

writeFileSync(join(here, "plan-generation-workflow.json"), JSON.stringify(workflow, null, 2) + "\n");
console.log("Wrote plan-generation-workflow.json");
