# AI Tutor API workflows

owlnighter can route individual AI tasks to a pre-created **workflow** on an AI
Tutor API account (the `ai_tutor_api` provider). Each task maps to its own
admin-configured workflow id (`ai_provider.ai_tutor_api.workflow_id.*`). This
folder holds the workflow definitions — one generated `*.json` per task, plus
the generator that emits it.

**Every `*-workflow.json` here is generated. Never hand-edit the JSON** — run the
matching generator instead (see each workflow below). The generators are the
single source of truth so a workflow's baked `structuredOutputSchema` can never
drift from the app's real Zod schema via a hand-typed nested-JSON transcription.

| Task              | JSON                              | Generator                       | Template style        | Web search |
| ----------------- | --------------------------------- | ------------------------------- | --------------------- | ---------- |
| `quiz_generation` | `quiz-generation-workflow.json`   | `build.mjs`                     | named-variable        | on         |
| `book_grounding`  | `book-grounding-workflow.json`    | `build-book-grounding.mjs`      | `{{system}}\n\n{{user}}` passthrough | on |
| `plan_generation` | `plan-generation-workflow.json`   | `build-plan-generation.mjs`     | `{{system}}\n\n{{user}}` passthrough | off |

Regenerate all three:

```
node docs/ai-tutor-workflows/build.mjs
node docs/ai-tutor-workflows/build-book-grounding.mjs
node docs/ai-tutor-workflows/build-plan-generation.mjs
```

## Two template styles, and why

owlnighter's `AiTutorApiAdapter` (`packages/ts/ai/src/aiTutorApi.ts`) sends a
flat request body to `POST /api/v1/run/{workflowId}`. It picks the body per task:

- **Named-variable map** — when the app supplies `opts.variables` (a flat
  `{name: value}` map). The workflow's `template` interpolates those discrete
  `{{names}}` platform-side, and `inputs` declares exactly those names.
- **Generic `{ system, user }` fallback** — when the app supplies no variable
  map. The workflow's `template` is the passthrough `{{system}}\n\n{{user}}`,
  with two `inputs` (`system`, `user`).

Which style a workflow uses is dictated by what its app-side caller emits:

- **quiz_generation** — `quiz.ts`'s `quizVariables()` emits a six-key variable
  map, so its workflow is the **named-variable** style (framing baked into the
  template, six discrete inputs). See below.
- **book_grounding** — `grounding.ts` calls `deps.ai.generateObject` with
  composed `system`/`user` strings and **no** variable map, so its workflow is
  the **passthrough** style. The framing (`grounding.ts`'s `SYSTEM_PROMPT`)
  arrives at runtime as the `system` value; it is not baked into the template,
  so there is nothing to single-source into an app-side constant (contrast the
  quiz workflow).
- **plan_generation** — `plans.ts` likewise passes composed `system`/`user`
  strings and no variable map, so its workflow is the **passthrough** style too.

For the two passthrough workflows the only thing the generator single-sources is
`modelSettings.structuredOutputSchema` — the JSON Schema mirroring the task's Zod
output shape:

- `book-grounding-workflow.json` mirrors `grounding.ts`'s `GroundedIdentity`
  (which embeds `BookIdentity` from `packages/ts/contracts/src/book.ts`, plus
  `sources` and `facts` arrays). `enableWebSearch: true` — `grounding.ts` calls
  `generateObject` with `requireGrounding: true`; resolving edition identity from
  live sources needs search grounding.
- `plan-generation-workflow.json` mirrors `plans.ts`'s `GroundedBookPlan`
  (which embeds `BookIdentity` and an array of `PlanStep` from
  `packages/ts/contracts/src/plan.ts`). `enableWebSearch: false` — `plans.ts`
  calls `generateObject` with `requireGrounding: false`; grounding already
  happened at book-ground time and its facts are baked into the prompt, so the
  plan pass deliberately does not need live search.

`model: "gemini-3.5-flash"` on all three is *this platform's own* model-catalog
entry (confirmed to support both `webSearch` and `structuredOutput`) — unrelated
to owlnighter's own `GEMINI_MODEL` env var / Gemini adapter; don't confuse the
two even though the name looks similar.

### Important: routing caveat for book_grounding / plan_generation

As of today these two workflows **cannot actually be exercised** by the running
app even after you import them and set their ids. `packages/ts/ai/src/router.ts`
hardcodes `book_grounding` and `plan_generation` to Gemini
(`preferredProvider` returns `"gemini"` for both; `book_grounding` additionally
forces Gemini via `requireGrounding: true`), and neither task is in
`TASK_OVERRIDABLE`, so no admin override or provider default can reroute them to
`ai_tutor_api`. `packages/ts/contracts/src/settings.ts` documents the same thing
and the admin UI hides both fields. These workflow definitions + ids are prepared
for **forward compatibility**: if that hardcoded-Gemini routing is ever relaxed,
the workflows, schema, and settings keys are already in place. (Enabling the
routing itself is a `packages/` change, out of scope for this folder.)

## The quiz workflow (named-variable style)

`quiz-generation-workflow.json` bakes the quiz framing into `template`, followed
by a labeled layout interpolating six discrete inputs — `stepTitle`,
`chapterHint`, `pageRange`, `quizMode`, `questionCount`, `readerContext` — whose
keys match `quiz.ts`'s `quizVariables()`. Because the framing is baked into the
template, `build.mjs` also emits `apps/api/src/services/quiz-prompt.generated.ts`
(exporting `QUIZ_SYSTEM_FRAMING`), which `quiz.ts` imports for its
Gemini/Groq/OpenRouter path — so the baked template framing and the app-side
constant come from one generator and cannot silently drift.
`modelSettings.structuredOutputSchema` mirrors `quiz.ts`'s `GeneratedQuiz` shape,
and `enableWebSearch: true`.

## How to import a workflow and wire it up

Importing is a **manual, browser step** — it is not doable with the run API key.
The `PUT https://aitutor-api.vercel.app/api/workflows/import` endpoint is
authenticated by the console's **browser session** (a Bearer `sk_...` key on that
request 307-redirects to `/sign-in`); the `sk_...` key only authorizes the run
endpoint (`POST /api/v1/run/{workflowId}`). owlnighter therefore never imports
workflows on anyone's behalf — the Bearer key belongs to a real, possibly-billable
account.

1. Sign in to your AI Tutor API console in a browser.
2. Import the workflow's `.json` (drag-and-drop, or the console's import action,
   which is what calls `PUT /api/workflows/import` with your session cookie).
3. Note the `shortId` (`wf_...`) the platform assigns on import. The file's own
   `name` field is overwritten by the import route, so don't expect the JSON's
   name to survive.
4. In owlnighter's admin panel, go to **AI Providers → AI Tutor API** and paste
   that id into the matching **Workflow ID** field. (For `book_grounding` /
   `plan_generation`, whose fields the admin UI currently hides, set the value
   directly in `app_settings`, e.g.
   `ai_provider.ai_tutor_api.workflow_id.book_grounding`.)
5. Set an AI Tutor API key in the same card.

`quiz_generation` is already imported on the connected account
(`ai_provider.ai_tutor_api.workflow_id.quiz_generation`). The `book_grounding`
and `plan_generation` ids are currently empty and must be imported and pasted the
same way.
