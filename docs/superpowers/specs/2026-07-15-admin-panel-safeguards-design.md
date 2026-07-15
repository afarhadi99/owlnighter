# Admin panel safeguards, settings, and AI provider management — design

**Date:** 2026-07-15
**Status:** Approved for implementation

## Overview

This adds four related subsystems to owlnighter, all scoped to the **admin panel and backend** (no mobile-app changes):

1. Real authentication + `@mytsi.org`-only, admin-approved sign-up for the admin panel itself (today it has none).
2. A DB-backed, admin-editable settings system (book limits, feature flags, non-secret config, write-only API keys) replacing scattered env-var-only config.
3. AI provider management — Groq, OpenRouter, and a new "AI Tutor API" provider, each admin-configurable, with live model catalogs for Groq/OpenRouter and per-task system-prompt editing for Groq/OpenRouter.
4. An AI Tutor API provider adapter, plus one importable workflow-definition JSON that lets AI Tutor API genuinely stand in for Groq on real quiz generation.

Everything here follows the existing contract-driven pattern (`packages/ts/contracts` → Zod → `apps/api` routes → typed `apps/admin` client) and the existing two-step migration pattern (a new numbered file in `infra/sql/`, mirrored in `packages/ts/db/src/schema.ts`).

### Explicit non-goals (out of scope for this round)

- Mobile end-user sign-up/auth — untouched, stays exactly as-is (dev bypass + unimplemented Supabase sign-in).
- The children's-story workflow JSON from the original ask — that was an illustrative example of the AI Tutor API platform's format, not a real deliverable; dropped per user confirmation.
- Per-user override of `max_books_per_user` — only a single global default is built now; per-user override is a natural, obvious extension if ever needed, not built speculatively.
- Wiring against a real, hosted Supabase Auth project — this dev environment has no real Supabase project configured (empty service-role/anon keys, local-only URL), so admin auth is self-contained (see §1) rather than layered on infrastructure that doesn't exist here.
- Actually calling AI Tutor API's `PUT /api/workflows/import` against the user's live account — that creates a real, possibly billable resource using their real Bearer key. The JSON file is delivered; importing it happens with explicit confirmation at build time, not silently.

---

## 1. Admin panel authentication + approval

Self-contained email/password auth for admin-panel operators, decoupled from `profiles` (which models reading-app end-users, not ops accounts — mixing the two would blur a boundary that should stay clean) and decoupled from Supabase Auth (not actually running in this environment).

### Schema (`infra/sql/0004_admin_accounts.sql`, mirrored in `packages/ts/db/src/schema.ts`)

```sql
create table admin_accounts (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  password_hash text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  is_admin boolean not null default false,
  approved_by uuid references admin_accounts(id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table admin_sessions (
  id uuid primary key default gen_random_uuid(),
  admin_account_id uuid not null references admin_accounts(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

alter table admin_accounts enable row level security;
alter table admin_sessions enable row level security;
-- No policies: these tables are only ever touched via the service-role-backed
-- Fastify API, never a client-side Supabase session. Default-deny is
-- defense-in-depth, matching the existing pattern in 0002_rls.sql.
```

Email comparison is case-insensitive (`lower(email)` unique index). Sessions are opaque random tokens; only a SHA-256 hash is stored (same reasoning as never storing plaintext passwords) — the raw token lives only in an httpOnly, secure, `SameSite=Lax` cookie.

### Backend (`apps/api/src/routes/admin-auth.ts`, new contracts in `packages/ts/contracts`)

- `POST /v1/admin/auth/signup` `{email, password}` — rejects any email not ending in `@mytsi.org` (case-insensitive) with a 400 before touching the DB. Validates password length (min 8). Hashes with bcrypt, inserts `status='pending'`. Returns 201 with a "pending approval" message; **no session is issued** for pending accounts.
- `POST /v1/admin/auth/login` `{email, password}` — verifies the bcrypt hash; if `status !== 'approved'` or `!is_admin`, returns 403 with a status-specific message ("pending approval" / "rejected"). On success, creates an `admin_sessions` row (30-day expiry) and sets the cookie.
- `POST /v1/admin/auth/logout` — deletes the session row, clears the cookie.
- `GET /v1/admin/auth/me` — resolves the current admin account from the cookie; 401 if missing/expired/invalid.
- `GET /v1/admin/accounts/pending` — list pending accounts (approved-admin only).
- `POST /v1/admin/accounts/:id/approve` / `/reject` — approved-admin only; approve sets `is_admin=true, status='approved', approved_by, approved_at`.

A new `requireApprovedAdmin` Fastify preHandler (reads the cookie, joins `admin_sessions` → `admin_accounts`) replaces the current stub `x-admin: 1` header check on **every** existing `/v1/admin/*` route. This is a behavior change to existing admin routes, but the current behavior is already non-functional in practice (the admin console sends a placeholder header; the API's real `adminGuard` expects a Supabase JWT that never arrives) — this makes admin auth actually work rather than removing a working protection.

### Seed script (`packages/ts/db/scripts/seed-admin-accounts.mjs`)

Idempotent upsert-by-email, bcrypt-hashes the three given passwords, inserts as `status='approved', is_admin=true`:

| email | password |
| --- | --- |
| rcohen@mytsi.org | REDACTED_PASSWORD |
| nkukaj@mytsi.org | REDACTED_PASSWORD |
| afarhadi@mytsi.org | REDACTED_PASSWORD |

Run via a new `pnpm --filter @owlnighter/db seed:admin` script, matching the existing `migrate`/dev-seed conventions.

### Admin panel UI

- `/login` — email + password.
- `/signup` — email + password; on success shows a "request submitted, waiting on admin approval" state (not a redirect to a logged-in view).
- `/accounts` — pending-accounts list with Approve/Reject buttons; only reachable when logged in.
- A root-layout auth check (server-side, calls `GET /v1/admin/auth/me` via the forwarded cookie) redirects to `/login` for every other route.

---

## 2. Admin-editable settings

### Schema (`infra/sql/0005_app_settings.sql`)

```sql
create table app_settings (
  key text primary key,
  value jsonb not null,
  is_secret boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid references admin_accounts(id)
);
```

Seeded (in the same migration) with default rows for every known setting, so the table is never "empty" for a key the app expects:

| key | default value | is_secret | notes |
| --- | --- | --- | --- |
| `max_books_per_user` | `3` | no | enforced on add-book |
| `flag.groq_quiz_generation` | `true` | no | was `FLAG_GROQ_QUIZ` |
| `flag.tts_pregeneration` | `true` | no | was `FLAG_TTS_PREGEN` |
| `flag.grounding_review_queue` | `true` | no | was `FLAG_GROUNDING_REVIEW` |
| `grounding.auto_accept` | `0.85` | no | was `GROUNDING_AUTO_ACCEPT` |
| `grounding.review_floor` | `0.60` | no | was `GROUNDING_REVIEW_FLOOR` |
| `catalog.open_library_base_url` | `"https://openlibrary.org"` | no | |
| `catalog.google_books_api_key` | `null` | **yes** | write-only |
| `ai.gemini.model` | `"gemini-3.5-flash"` | no | |
| `ai.groq.model` | `"qwen-3.6-32b"` | no | reconciles the `.env.example` vs `env.ts` drift the research found |
| `ai.deepgram.tts_model` | `"aura-2-thalia-en"` | no | |
| *(AI provider keys/prompts — see §3)* | | | |

`DATABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are **never** represented here — hard exclusion, no admin path can ever set or read them.

### Backend

- `GET /v1/admin/settings` — returns all rows; `is_secret` rows return `{configured: bool, hint: "…last4"}` instead of the real value.
- `PUT /v1/admin/settings/:key` — validated against a per-key Zod schema registry (so `max_books_per_user` must be a positive int, thresholds must be 0–1, etc.); records `updated_by` from the requesting admin session.
- A small `getSetting(key)` helper (in `packages/ts/shared` or a new `packages/ts/db` accessor) with a short in-process cache (~30s TTL) so hot-path reads (e.g. the add-book check) don't hit the DB every request. Env vars become the seed defaults only; the DB row is the runtime source of truth once the migration has run.
- The add-book endpoint (`apps/api`, library service) reads `max_books_per_user` and rejects a new addition once the user's `user_books` count meets it, with a clear error message the mobile UI can surface.

### Admin panel UI

New `/settings` page, grouped into cards: Limits, Feature Flags, Catalog, AI Models (non-provider-specific defaults). Secret fields render as password-style inputs showing only the masked hint, with a "replace" affordance rather than an editable pre-filled value.

---

## 3. AI provider management

### Schema changes

`infra/sql/0006_provider_enum_relax.sql` — relaxes the two existing CHECK constraints (`reading_plans.provider`, `quiz_instances.provider`) to allow `'openrouter'` and `'ai_tutor_api'` alongside the existing `'gemini'`/`'groq'`.

`packages/ts/ai/src/types.ts` — `ProviderName` becomes `"gemini" | "groq" | "openrouter" | "ai_tutor_api"`.

### Per-provider settings (added to `app_settings`, all keys prefixed and secrets flagged)

- `ai_provider.groq.api_key` (secret), `.model`, `.system_prompt.plan_generation`, `.system_prompt.quiz_generation` — unset system-prompt keys fall back to today's hardcoded constants in `plans.ts`/`quiz.ts`.
- `ai_provider.openrouter.api_key` (secret), `.model`, `.system_prompt.plan_generation`, `.system_prompt.quiz_generation`.
- `ai_provider.ai_tutor_api.api_key` (secret), `.workflow_id.book_grounding`, `.workflow_id.plan_generation`, `.workflow_id.quiz_generation` — **no system-prompt field**: AI Tutor API's prompt template lives on a pre-created workflow on their platform, not something owlnighter sends per-request (confirmed by reading their `/api/v1/run/[workflowId]` route — it substitutes named input variables into a stored `template`, it doesn't accept an arbitrary prompt).
- `ai_provider.default` = `"ai_tutor_api"` — this sets which provider is **pre-selected in the admin UI** when configuring a task's provider. It does not forcibly override Gemini's existing contract-critical role for book-grounding/plan-generation (those stay Gemini-first per the existing router logic, `requireGrounding`/`requireStrictSchema`) unless an admin explicitly reassigns that task to a different provider in the settings — flagging this interpretation explicitly since "make it the default" could otherwise be read as "force every task onto it," which would break the grounding-accuracy guarantees the rest of the app depends on.

### New adapters (`packages/ts/ai/src`)

- `openrouter.ts` — OpenRouter exposes an OpenAI-compatible `/api/v1/chat/completions` endpoint; structured output via their JSON-schema response-format support. Implementation will confirm exact request/response shape against OpenRouter's real docs during the build (not guessed here).
- `aiTutorApi.ts` — `POST https://aitutor-api.vercel.app/api/v1/run/{workflow_id}` with `Authorization: Bearer <key>` and a JSON body of the task's template variables; the response is `{success, result: "<json-string>", citations?}` — `result` is `JSON.parse`'d and validated against the caller's Zod schema through the **same** `safeParse` safety net the router already applies to Gemini/Groq, so a malformed AI-Tutor-API response degrades the same way a malformed Gemini/Groq response does today (retry/fallback), never silently accepted.

### Live model catalogs

`GET /v1/admin/ai/models?provider=groq|openrouter` — server-side call (keeping any required key off the client): Groq's model-list endpoint needs the configured Groq key; OpenRouter's is publicly readable. Returns a normalized `{id, name, contextLength, pricing, modality}[]`. The admin UI renders this as a sortable, filterable table (click column headers to sort; a modality filter defaulting to text/LLM models, since OpenRouter's catalog spans multiple modalities and the ask specifically called out wanting the LLM ones surfaced clearly).

### Admin panel UI

New `/ai-providers` page: one card per provider. Groq/OpenRouter cards get a "Fetch models" button opening the sortable table plus per-task system-prompt textareas. The AI Tutor API card gets the Bearer-key field and three workflow-ID fields (one per task), with inline help text explaining they come from importing the JSON in §4 into the AI Tutor API console.

---

## 4. AI Tutor API workflow deliverable

One file, `docs/ai-tutor-workflows/quiz-generation-workflow.json`, matching the exact import contract read from `manage-prompt`'s own `WorkflowSchema`/`/api/workflows/import` route:

- `template` — owlnighter's existing quiz-generation system prompt (from `apps/api/src/services/quiz.ts`) rewritten with `{{...}}` placeholders for the per-request dynamic parts (book title/author, grounded step content, quiz mode, question count).
- `modelSettings` (JSON-encoded string) — `enableWebSearch: true` (quiz accuracy genuinely benefits from grounding, unlike a children's story) and `structuredOutputSchema` set to owlnighter's real quiz-instance Zod schema converted to raw JSON Schema — using a model from their catalog confirmed to support both `structuredOutput` and `webSearch` (the exact valid model-id string will be confirmed against their live catalog code during implementation rather than guessed here).
- A short `docs/ai-tutor-workflows/README.md` explaining: drag-and-drop this file into the AI Tutor API console (or `PUT /api/workflows/import`) to get a real `workflow_id`, then paste it into owlnighter's `/ai-providers` settings under AI Tutor API → quiz-generation workflow ID.

---

## Verification plan

- **Backend unit tests:** admin-auth (domain rejection, signup→pending→approve→login happy path, rejected-account login blocked, session expiry), settings CRUD + secret masking + validation rejection, provider-enum relax, new adapters (mocked HTTP).
- **Admin panel, driven live:** `pnpm dev:api` + `pnpm dev:admin` — walk through signup rejection for a non-`@mytsi.org` email, login as a seeded admin, approve a freshly-submitted pending signup, edit a setting and confirm it persists across reload, open `/ai-providers` and fetch live Groq/OpenRouter model lists if keys are available in this environment (flagging now: this dev `.env` currently has empty Groq/OpenRouter keys, so live catalog fetching may only be verifiable structurally — request goes out, correct error surfaces — rather than end-to-end with real data, unless real keys are supplied).
- **Android emulator:** confirm the existing reading loop is unaffected (no mobile code changes in this round), and specifically exercise the one behavior change that does reach mobile — adding a 4th book is rejected with a clear message once `max_books_per_user=3` is enforced.

## File/migration plan

- `infra/sql/0004_admin_accounts.sql`, `0005_app_settings.sql`, `0006_provider_enum_relax.sql` (+ mirrored Drizzle tables in `packages/ts/db/src/schema.ts`).
- `packages/ts/db/scripts/seed-admin-accounts.mjs`.
- `packages/ts/contracts` — new schemas/endpoints for admin-auth, settings, AI provider config, model catalogs.
- `apps/api/src/routes/admin-auth.ts`, `apps/api/src/routes/settings.ts` (or extend `admin.ts`), `apps/api/src/plugins/admin-session.ts`.
- `packages/ts/ai/src/openrouter.ts`, `aiTutorApi.ts`, router changes.
- `apps/admin/app/login`, `/signup`, `/accounts`, `/settings`, `/ai-providers` (+ shared auth-check + API client updates for cookie-based requests).
- `docs/ai-tutor-workflows/quiz-generation-workflow.json` + `README.md`.
