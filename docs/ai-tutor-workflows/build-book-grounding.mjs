// Regenerates book-grounding-workflow.json — the AI Tutor API workflow for the
// `book_grounding` task. Run this — never hand-edit the output — whenever
// apps/api/src/services/grounding.ts's `GroundedIdentity` schema (or the
// `BookIdentity` contract it embeds, packages/ts/contracts/src/book.ts) changes:
//
//   node docs/ai-tutor-workflows/build-book-grounding.mjs
//
// Unlike the quiz workflow, this is a GENERIC {{system}}\n\n{{user}} PASSTHROUGH
// workflow, not a discrete-named-variable template. grounding.ts calls
// deps.ai.generateObject with composed `system`/`user` strings and does NOT emit
// a named-variable map, so owlnighter's AiTutorApiAdapter
// (packages/ts/ai/src/aiTutorApi.ts) posts the generic `{ system, user }`
// fallback body — the template just concatenates them. The framing (the
// SYSTEM_PROMPT in grounding.ts) therefore arrives at runtime as the `system`
// value; it is NOT baked into the template, so there is nothing to single-source
// into an app-side constant here (contrast build.mjs, whose quiz framing IS baked
// into the template and so is co-emitted as QUIZ_SYSTEM_FRAMING).
//
// What IS single-sourced from this script is `modelSettings.structuredOutputSchema`
// — the JSON Schema mirroring grounding.ts's `GroundedIdentity` Zod shape, so the
// baked schema can never drift via a hand-typed nested-JSON-string transcription.
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));

// The generic passthrough template. `system` and `user` are supplied verbatim by
// grounding.ts at runtime via the adapter's `{ system, user }` fallback body.
const template = "{{system}}\n\n{{user}}";

const inputs = [
  { name: "system", label: "System", type: "textarea" },
  { name: "user", label: "User", type: "textarea" },
];

// ── BookIdentity JSON Schema (mirrors packages/ts/contracts/src/book.ts) ──────
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

// ── GroundedIdentity JSON Schema (mirrors grounding.ts's Zod schema exactly) ──
const structuredOutputSchema = {
  type: "object",
  properties: {
    identity: bookIdentitySchema,
    pageLevelUnsafe: { type: "boolean" },
    sources: {
      type: "array",
      items: {
        type: "object",
        properties: {
          sourceType: { type: "string", enum: ["google_books", "open_library", "web"] },
          url: { type: "string", format: "uri" },
          title: { type: "string" },
          snippet: { type: "string" },
          trustScore: { type: "number", minimum: 0, maximum: 1 },
        },
        required: ["sourceType", "trustScore"],
        additionalProperties: false,
      },
    },
    facts: {
      type: "array",
      items: {
        type: "object",
        properties: {
          factType: {
            type: "string",
            enum: ["page_count", "chapter_map", "character", "theme", "preview_segment"],
          },
          key: { type: "string" },
          // z.unknown() — any JSON value; intentionally unconstrained.
          value: {},
          confidence: { type: "number", minimum: 0, maximum: 1 },
          sourceIndices: { type: "array", items: { type: "integer" } },
        },
        required: ["factType", "key", "value", "confidence"],
        additionalProperties: false,
      },
    },
  },
  required: ["identity", "pageLevelUnsafe"],
  additionalProperties: false,
};

// Keys confirmed against manage-prompt's own ModelSettings TS type
// (components/console/workflow/workflow-model-settings.tsx). enableWebSearch is
// true: grounding.ts calls generateObject with requireGrounding: true — the task
// resolves book identity from live web sources, so search grounding is required.
const modelSettings = {
  temperature: 0.2,
  maxTokens: 16000,
  enableWebSearch: true,
  reasoningEffort: "none",
  structuredOutputSchema: JSON.stringify(structuredOutputSchema),
};

const workflow = {
  name: "owlnighter Book Grounding",
  model: "gemini-3.5-flash",
  template,
  instruction: "",
  modelSettings: JSON.stringify(modelSettings),
  cacheControlTtl: 0,
  inputs,
};

writeFileSync(join(here, "book-grounding-workflow.json"), JSON.stringify(workflow, null, 2) + "\n");
console.log("Wrote book-grounding-workflow.json");
