# Admin Panel Safeguards, Settings, and AI Provider Management — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give owlnighter's admin panel real authentication with `@mytsi.org`-only, admin-approved signup; a DB-backed settings system replacing scattered env vars; admin-managed Groq/OpenRouter/AI-Tutor-API providers with live model catalogs and per-task system prompts; and an importable AI Tutor API workflow for quiz generation.

**Architecture:** Self-contained `admin_accounts`/`admin_sessions` tables (bcrypt-equivalent via Postgres `pgcrypto`, already enabled) power a brand-new `admin_panel` auth type parallel to the existing Supabase-based `user`/`admin` guards. A new `app_settings` table (admin-editable, ~30s-cached reads) replaces env-only config for limits/flags/thresholds/provider keys. `packages/ts/ai`'s router gains a `SettingsReader` seam so Groq/OpenRouter/AI-Tutor-API keys, models, and (for quiz/rewrite only) provider overrides are live-configurable without a redeploy, while Gemini's contract-critical grounding role stays hardcoded and protected.

**Tech Stack:** Fastify 5 + Zod 4 + Drizzle (existing), Postgres `pgcrypto` for password hashing (no new npm dependency), Node's built-in `crypto` for session tokens, Next.js 15 Server Actions for admin-panel cookie auth (no new npm dependency).

**User decisions (already made):**
- Admin-panel auth only — mobile end-user auth is untouched ("This is only for the admin panel, nothing to do with mobile").
- Real admin login now, self-contained (not real Supabase — this dev env has no live Supabase project).
- Drop the children's-story workflow JSON; ship only the quiz-generation workflow ("i dont need childrens stroy workflow, its just an example, ship the rest tho").
- One full design covering everything, built with parallel subagents ("fan out and implement").
- Seed accounts: `rcohen@mytsi.org`/`REDACTED_PASSWORD`, `nkukaj@mytsi.org`/`REDACTED_PASSWORD`, `afarhadi@mytsi.org`/`REDACTED_PASSWORD`, all pre-approved admins.

**Spec:** `docs/superpowers/specs/2026-07-15-admin-panel-safeguards-design.md` (approved). This plan corrects two internal spec inconsistencies found during research: (1) `admin_accounts.email` is made case-insensitive-unique via a `lower(email)` index rather than a plain `unique` column constraint, matching the spec's own prose; (2) the spec's `ai.groq.model` (§2) and `ai_provider.groq.model` (§3) are consolidated into the single `ai_provider.groq.model` setting to avoid two settings governing the same value.

---

## Task 1: DB schema — `admin_accounts` + `admin_sessions`

**Goal:** Self-contained admin-panel account/session tables exist in Postgres and are typed in Drizzle.

**Files:**
- Create: `infra/sql/0004_admin_accounts.sql`
- Modify: `packages/ts/db/src/schema.ts` (append `adminAccounts`, `adminSessions` tables)

**Acceptance Criteria:**
- [ ] `infra/sql/0004_admin_accounts.sql` creates `admin_accounts` and `admin_sessions` with RLS enabled and no policies (default-deny), matching the pattern in `infra/sql/0002_rls.sql`.
- [ ] Email uniqueness is case-insensitive (`lower(email)` unique index), not a plain column `unique`.
- [ ] `packages/ts/db/src/schema.ts` exports `adminAccounts` and `adminSessions` Drizzle tables whose column shapes match the SQL exactly.
- [ ] `pnpm --filter @owlnighter/db run typecheck` passes.

**Verify:** `DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:55432/postgres node packages/ts/db/scripts/apply-local.mjs` → prints `Applying infra/sql/0004_admin_accounts.sql ... ok` among the other files, ends with `✓ Local dev DB ready`.

**Steps:**

- [ ] **Step 1: Write the migration**

Create `infra/sql/0004_admin_accounts.sql`:

```sql
-- Admin-panel operator accounts. Decoupled from `profiles` (mobile end-users)
-- and from Supabase Auth (this dev environment has no live Supabase project).
create table public.admin_accounts (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  password_hash text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  is_admin boolean not null default false,
  approved_by uuid references public.admin_accounts(id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- Case-insensitive uniqueness: rcohen@mytsi.org and RCohen@mytsi.org are the same account.
create unique index admin_accounts_email_lower_idx on public.admin_accounts (lower(email));

create table public.admin_sessions (
  id uuid primary key default gen_random_uuid(),
  admin_account_id uuid not null references public.admin_accounts(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index admin_sessions_account_idx on public.admin_sessions (admin_account_id);
create index admin_sessions_expires_idx on public.admin_sessions (expires_at);

alter table public.admin_accounts enable row level security;
alter table public.admin_sessions enable row level security;
-- No policies: these tables are only ever touched via the service-role-backed
-- Fastify API, never a client-side Supabase session. Default-deny is
-- defense-in-depth, matching the existing pattern in 0002_rls.sql.
```

- [ ] **Step 2: Mirror in Drizzle**

In `packages/ts/db/src/schema.ts`, append after `quizGenerationRuns` (the last export):

```ts
export const adminAccounts = pgTable("admin_accounts", {
  id: uuid("id").primaryKey().defaultRandom(),
  email: text("email").notNull(),
  passwordHash: text("password_hash").notNull(),
  status: text("status").notNull().default("pending"),
  isAdmin: boolean("is_admin").notNull().default(false),
  approvedBy: uuid("approved_by"),
  approvedAt: timestamp("approved_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});

export const adminSessions = pgTable("admin_sessions", {
  id: uuid("id").primaryKey().defaultRandom(),
  adminAccountId: uuid("admin_account_id").notNull(),
  tokenHash: text("token_hash").notNull().unique(),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});
```

- [ ] **Step 3: Typecheck + apply locally**

Run: `pnpm --filter @owlnighter/db run typecheck` → no errors.
Run: `DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:55432/postgres node packages/ts/db/scripts/apply-local.mjs` → ends with `✓ Local dev DB ready (N files applied).`

- [ ] **Step 4: Commit**

```bash
git add infra/sql/0004_admin_accounts.sql packages/ts/db/src/schema.ts
git commit -m "feat(db): add admin_accounts and admin_sessions tables"
```

---

## Task 2: DB schema — `app_settings` + seeded defaults

**Goal:** A single `app_settings` table holds every admin-editable value (limits, flags, thresholds, catalog config, AI provider keys/models/prompts), seeded with today's env-var defaults so the table is never empty for a key the app expects.

**Files:**
- Create: `infra/sql/0005_app_settings.sql`
- Modify: `packages/ts/db/src/schema.ts` (append `appSettings` table)

**Acceptance Criteria:**
- [ ] `app_settings` table exists with columns `key text primary key, value jsonb not null, is_secret boolean not null default false, updated_at timestamptz not null default now(), updated_by uuid references admin_accounts(id)`.
- [ ] Every key listed in Step 1's seed table is present after migration, with the exact default value shown.
- [ ] `packages/ts/db/src/schema.ts` exports `appSettings`.
- [ ] `pnpm --filter @owlnighter/db run typecheck` passes.

**Verify:** After applying migrations, `psql $DATABASE_URL -c "select key, value, is_secret from app_settings order by key;"` lists all 24 seeded keys (list in Step 1).

**Steps:**

- [ ] **Step 1: Write the migration with full seed data**

Create `infra/sql/0005_app_settings.sql`:

```sql
create table public.app_settings (
  key text primary key,
  value jsonb not null,
  is_secret boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.admin_accounts(id)
);

insert into public.app_settings (key, value, is_secret) values
  ('max_books_per_user', '3'::jsonb, false),
  ('flag.groq_quiz_generation', 'true'::jsonb, false),
  ('flag.tts_pregeneration', 'true'::jsonb, false),
  ('flag.grounding_review_queue', 'true'::jsonb, false),
  ('grounding.auto_accept', '0.85'::jsonb, false),
  ('grounding.review_floor', '0.60'::jsonb, false),
  ('catalog.open_library_base_url', '"https://openlibrary.org"'::jsonb, false),
  ('catalog.google_books_api_key', 'null'::jsonb, true),
  ('ai.gemini.model', '"gemini-3.5-flash"'::jsonb, false),
  ('ai.deepgram.tts_model', '"aura-2-thalia-en"'::jsonb, false),
  ('ai_provider.groq.api_key', '""'::jsonb, true),
  ('ai_provider.groq.model', '"qwen-3.6-32b"'::jsonb, false),
  ('ai_provider.groq.system_prompt.plan_generation', '""'::jsonb, false),
  ('ai_provider.groq.system_prompt.quiz_generation', '""'::jsonb, false),
  ('ai_provider.openrouter.api_key', '""'::jsonb, true),
  ('ai_provider.openrouter.model', '""'::jsonb, false),
  ('ai_provider.openrouter.system_prompt.plan_generation', '""'::jsonb, false),
  ('ai_provider.openrouter.system_prompt.quiz_generation', '""'::jsonb, false),
  ('ai_provider.ai_tutor_api.api_key', '""'::jsonb, true),
  ('ai_provider.ai_tutor_api.workflow_id.book_grounding', '""'::jsonb, false),
  ('ai_provider.ai_tutor_api.workflow_id.plan_generation', '""'::jsonb, false),
  ('ai_provider.ai_tutor_api.workflow_id.quiz_generation', '""'::jsonb, false),
  ('ai_provider.default', '"ai_tutor_api"'::jsonb, false),
  ('ai_provider.task_override.quiz_generation', 'null'::jsonb, false),
  ('ai_provider.task_override.rewrite', 'null'::jsonb, false);
```

Note: `DATABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are intentionally never represented here — no migration, seed, or admin route may ever add rows for them.

- [ ] **Step 2: Mirror in Drizzle**

In `packages/ts/db/src/schema.ts`, append after `adminSessions`:

```ts
export const appSettings = pgTable("app_settings", {
  key: text("key").primaryKey(),
  value: jsonb("value").notNull(),
  isSecret: boolean("is_secret").notNull().default(false),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
  updatedBy: uuid("updated_by"),
});
```

- [ ] **Step 3: Typecheck + apply locally**

Run: `pnpm --filter @owlnighter/db run typecheck` → no errors.
Run: `DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:55432/postgres node packages/ts/db/scripts/apply-local.mjs` → ends with `✓ Local dev DB ready`.
Run: `psql postgresql://postgres:postgres@127.0.0.1:55432/postgres -c "select count(*) from app_settings;"` → `25`.

- [ ] **Step 4: Commit**

```bash
git add infra/sql/0005_app_settings.sql packages/ts/db/src/schema.ts
git commit -m "feat(db): add app_settings table with seeded defaults"
```

## Task 3: Relax the provider enum to 4 providers

**Goal:** `"gemini" | "groq"` becomes `"gemini" | "groq" | "openrouter" | "ai_tutor_api"` everywhere it's a hardcoded union — DB CHECK constraints, Zod contracts, and the `ai` package's types — with zero behavior change for existing Gemini/Groq calls.

**Files:**
- Create: `infra/sql/0006_provider_enum_relax.sql`
- Modify: `packages/ts/contracts/src/common.ts` (widen `AiProvider`)
- Modify: `packages/ts/contracts/src/quiz.ts` (use `AiProvider` instead of inline enum)
- Modify: `packages/ts/contracts/src/plan.ts` (use `AiProvider` instead of inline enum, 2 places)
- Modify: `packages/ts/ai/src/types.ts` (add `ProviderName`, widen `ProviderAdapter.name`/`AiObjectResult.provider`/`AiTextResult.provider`)
- Modify: `packages/ts/ai/src/groq.ts` (constructor takes `ProviderRuntimeConfig` instead of `Env` — needed so Task 10 can inject admin-configured keys)
- Modify: `packages/ts/ai/src/router.ts` (`ProviderName` import, `new GroqAdapter(...)` call site)
- Modify: `packages/ts/ai/src/router.test.ts` (update `new GroqAdapter` call site if referenced — it isn't; only `createAiRouter` signature changes in Task 10, not this task)
- Modify: `apps/api/src/deps.ts` (widen the locally-duplicated `GenerateObjectResult.provider`/`GenerateObjectArgs.provider`/`AiRouter.generateText` provider param)
- Modify: `apps/api/src/services/plans.ts` (widen `chooseProvider`'s param/return type)
- Modify: `apps/api/src/services/quiz.ts` (widen the `configured`/`order` local array type)

**Acceptance Criteria:**
- [ ] `reading_plans.provider` and `quiz_instances.provider` CHECK constraints accept `'openrouter'` and `'ai_tutor_api'` in addition to `'gemini'`/`'groq'`.
- [ ] `AiProvider` in `common.ts` is `z.enum(["gemini", "groq", "openrouter", "ai_tutor_api"])`.
- [ ] `pnpm --filter @owlnighter/contracts run typecheck`, `pnpm --filter @owlnighter/ai run typecheck`, and `pnpm --filter @owlnighter/api run typecheck` all pass.
- [ ] `pnpm --filter @owlnighter/ai run test` still passes unchanged (existing Gemini/Groq routing behavior is untouched by this task).

**Verify:** `pnpm --filter @owlnighter/ai run test` → all 4 existing tests in `router.test.ts` pass with no edits needed to their assertions.

**Steps:**

- [ ] **Step 1: Migration to relax the CHECK constraints**

Create `infra/sql/0006_provider_enum_relax.sql`. The constraints were declared inline without an explicit name in `0001_init.sql`, so Postgres auto-named them `<table>_<column>_check`:

```sql
alter table public.reading_plans drop constraint reading_plans_provider_check;
alter table public.reading_plans add constraint reading_plans_provider_check
  check (provider in ('gemini','groq','openrouter','ai_tutor_api'));

alter table public.quiz_instances drop constraint quiz_instances_provider_check;
alter table public.quiz_instances add constraint quiz_instances_provider_check
  check (provider in ('gemini','groq','openrouter','ai_tutor_api'));
```

- [ ] **Step 2: Widen the shared `AiProvider` enum and use it instead of inline duplicates**

In `packages/ts/contracts/src/common.ts`, replace:

```ts
export const AiProvider = z.enum(["gemini", "groq"]);
```

with:

```ts
export const AiProvider = z.enum(["gemini", "groq", "openrouter", "ai_tutor_api"]);
```

In `packages/ts/contracts/src/quiz.ts`, change the import line to `import { AiProvider, Confidence, QuizMode, Uuid } from "./common.js";` and replace `generatedByProvider: z.enum(["gemini", "groq"]),` with `generatedByProvider: AiProvider,`.

In `packages/ts/contracts/src/plan.ts`, change the import to `import { AiProvider, Confidence, PacingMode, QuizMode, Uuid } from "./common.js";` and replace both occurrences of `z.enum(["gemini", "groq"])` (in `PlanGenerateRequest.provider` — keep its `.optional()`, and in `PlanResponse.provider`) with `AiProvider` (keeping `.optional()` on the request one): `provider: AiProvider.optional(),` and `provider: AiProvider,` respectively.

- [ ] **Step 3: Widen `packages/ts/ai/src/types.ts`**

Add near the top (after the `AiTask` export):

```ts
export type ProviderName = "gemini" | "groq" | "openrouter" | "ai_tutor_api";
```

Change `ProviderAdapter.name`'s type from `"gemini" | "groq"` to `ProviderName`, and change both `AiObjectResult.provider` and `AiTextResult.provider` from `"gemini" | "groq"` to `ProviderName`.

- [ ] **Step 4: `GroqAdapter` takes an injectable runtime config instead of `Env`**

This lets Task 10 hand it admin-configured keys/models without touching its request logic. In `packages/ts/ai/src/types.ts` add:

```ts
export interface ProviderRuntimeConfig {
  apiKey: string;
  model: string;
}
```

In `packages/ts/ai/src/groq.ts`, remove the `import type { Env } from "@owlnighter/shared";` line, add `type ProviderRuntimeConfig` to the existing `from "./types.js"` import, and change:

```ts
  constructor(private readonly env: Env) {}

  private modelFor(override?: string): string {
    return override ?? this.env.GROQ_MODEL;
  }

  private headers(): Record<string, string> {
    return {
      "content-type": "application/json",
      authorization: `Bearer ${this.env.GROQ_API_KEY}`,
    };
  }
```

to:

```ts
  constructor(private readonly config: ProviderRuntimeConfig) {}

  private modelFor(override?: string): string {
    return override ?? this.config.model;
  }

  private headers(): Record<string, string> {
    return {
      "content-type": "application/json",
      authorization: `Bearer ${this.config.apiKey}`,
    };
  }
```

- [ ] **Step 5: Update `router.ts`'s construction site (behavior-neutral for now — Task 10 makes it settings-driven)**

In `packages/ts/ai/src/router.ts`, replace the local `type ProviderName = "gemini" | "groq";` with an import of the now-shared type: change the `import type {...} from "./types.js"` block to include `ProviderName`, and delete the local `type ProviderName = "gemini" | "groq";` line. Change:

```ts
  const adapters: Record<ProviderName, ProviderAdapter> = {
    gemini: new GeminiAdapter(env),
    groq: new GroqAdapter(env),
  };
```

to:

```ts
  const adapters: Record<"gemini" | "groq", ProviderAdapter> = {
    gemini: new GeminiAdapter(env),
    groq: new GroqAdapter({ apiKey: env.GROQ_API_KEY, model: env.GROQ_MODEL }),
  };
```

(`adapters` stays keyed by the original 2 providers here — Task 10 replaces this whole function body with the settings-aware version. This step only exists so the package typechecks and tests pass after `GroqAdapter`'s constructor changes.)

- [ ] **Step 6: Widen `apps/api/src/deps.ts`'s locally-duplicated structural types**

In `apps/api/src/deps.ts`, replace every occurrence of the literal union `"gemini" | "groq"` with `"gemini" | "groq" | "openrouter" | "ai_tutor_api"` — this appears in `GenerateObjectResult.provider`, `GenerateObjectArgs.provider`, and the `generateText` method's `provider` param and return type, inside the `AiRouter` interface. There are 4 occurrences total in this file.

- [ ] **Step 7: Widen the two service files' local unions**

In `apps/api/src/services/plans.ts`, change `function chooseProvider(deps: Deps, requested?: "gemini" | "groq"): "gemini" | "groq" {` to `function chooseProvider(deps: Deps, requested?: "gemini" | "groq" | "openrouter" | "ai_tutor_api"): "gemini" | "groq" {` — the return type stays 2-way on purpose: this function's own `has()` check only ever tests Gemini/Groq keys, so it can never actually return the other two; widening only the parameter lets an admin-configured `provider` value type-check when passed through.

In `apps/api/src/services/quiz.ts`, change `const order: Array<"gemini" | "groq"> = useGroqFirst ? ["groq", "gemini"] : ["gemini", "groq"];` — no change needed to this line itself (it stays 2-way; Task 10 does not touch quiz.ts's own Groq/Gemini loop, only the router underneath it). Skip this file in this task — flagged here only to confirm no change is required.

- [ ] **Step 8: Typecheck + test**

Run: `pnpm --filter @owlnighter/contracts run typecheck` → no errors.
Run: `pnpm --filter @owlnighter/ai run typecheck` → no errors.
Run: `pnpm --filter @owlnighter/ai run test` → all 4 tests pass.
Run: `pnpm --filter @owlnighter/api run typecheck` → no errors.

- [ ] **Step 9: Commit**

```bash
git add infra/sql/0006_provider_enum_relax.sql packages/ts/contracts/src/common.ts packages/ts/contracts/src/quiz.ts packages/ts/contracts/src/plan.ts packages/ts/ai/src/types.ts packages/ts/ai/src/groq.ts packages/ts/ai/src/router.ts apps/api/src/deps.ts apps/api/src/services/plans.ts
git commit -m "feat(ai): relax provider enum to gemini/groq/openrouter/ai_tutor_api"
```

---

## Task 4: Session token crypto utility

**Goal:** A small, dependency-free helper generates opaque admin-session tokens and hashes them for storage (never store a raw token).

**Files:**
- Create: `apps/api/src/utils/admin-crypto.ts`
- Test: `apps/api/src/utils/admin-crypto.test.ts`

**Acceptance Criteria:**
- [ ] `generateSessionToken()` returns a URL-safe random string with ≥256 bits of entropy.
- [ ] `hashToken(token)` is deterministic (same input → same output) and one-way (SHA-256 hex digest).
- [ ] Two calls to `generateSessionToken()` never collide in 10,000 iterations.

**Verify:** `node --import tsx --test "apps/api/src/utils/admin-crypto.test.ts"` → all pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

Create `apps/api/src/utils/admin-crypto.test.ts`:

```ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { generateSessionToken, hashToken } from "./admin-crypto.js";

test("generateSessionToken produces long, URL-safe, non-colliding tokens", () => {
  const seen = new Set<string>();
  for (let i = 0; i < 10_000; i++) {
    const t = generateSessionToken();
    assert.ok(t.length >= 32, "token should be reasonably long");
    assert.match(t, /^[A-Za-z0-9_-]+$/, "token should be URL-safe");
    assert.ok(!seen.has(t), "tokens should not collide");
    seen.add(t);
  }
});

test("hashToken is deterministic and one-way", () => {
  const token = "abc123";
  const h1 = hashToken(token);
  const h2 = hashToken(token);
  assert.equal(h1, h2);
  assert.notEqual(h1, token);
  assert.match(h1, /^[a-f0-9]{64}$/, "sha256 hex digest is 64 chars");
});

test("hashToken differs for different tokens", () => {
  assert.notEqual(hashToken("a"), hashToken("b"));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --import tsx --test "apps/api/src/utils/admin-crypto.test.ts"`
Expected: FAIL — `Cannot find module './admin-crypto.js'`.

- [ ] **Step 3: Implement**

Create `apps/api/src/utils/admin-crypto.ts`:

```ts
import { randomBytes, createHash } from "node:crypto";

/** 256 bits of randomness, base64url-encoded (URL/cookie/header safe). */
export function generateSessionToken(): string {
  return randomBytes(32).toString("base64url");
}

/** One-way SHA-256 hex digest. Only the hash is ever persisted — never the raw token. */
export function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --import tsx --test "apps/api/src/utils/admin-crypto.test.ts"` → all 3 pass.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/utils/admin-crypto.ts apps/api/src/utils/admin-crypto.test.ts
git commit -m "feat(api): add admin session token crypto utility"
```

## Task 5: Contracts — admin-auth, settings, AI-provider schemas + endpoint registry

**Goal:** Every new HTTP surface (admin-panel auth, approvals, settings CRUD, model catalog) has a Zod contract and an `ENDPOINTS` entry, and the 8 existing admin routes are retagged to the new `admin_panel` auth type. Pure contracts — no runtime backend code — so this task is fully parallel with Tasks 1, 2, 3, 4.

**Files:**
- Create: `packages/ts/contracts/src/admin-auth.ts`
- Create: `packages/ts/contracts/src/settings.ts`
- Modify: `packages/ts/contracts/src/endpoints.ts` (widen `EndpointDef.auth`, retag 8 endpoints, add 10 new endpoints)
- Modify: `packages/ts/contracts/src/index.ts` (export the 2 new files)
- Modify: `packages/ts/contracts/src/openapi.ts` (add a `cookieAuth`-style scheme label for `admin_panel` — cosmetic accuracy in generated docs)

**Acceptance Criteria:**
- [ ] `EndpointDef.auth` is `"user" | "admin" | "admin_panel" | "none"`.
- [ ] All 8 pre-existing `auth: "admin"` entries in `ENDPOINTS` are now `auth: "admin_panel"`.
- [ ] 10 new endpoints exist: `adminSignup`, `adminLogin`, `adminLogout`, `adminMe`, `adminListPendingAccounts`, `adminApproveAccount`, `adminRejectAccount`, `adminGetSettings`, `adminPutSetting`, `adminGetAiModels`.
- [ ] `pnpm --filter @owlnighter/contracts run typecheck` and `pnpm --filter @owlnighter/contracts run openapi` both succeed.

**Verify:** `pnpm --filter @owlnighter/contracts run openapi && node -e "const d=require('./packages/ts/contracts/dist/../../../apps/api/openapi.json')" ` is unnecessary — instead: `pnpm --filter @owlnighter/contracts run build` → succeeds with no type errors, confirming every new/edited file compiles.

**Steps:**

- [ ] **Step 1: Admin-auth contracts**

Create `packages/ts/contracts/src/admin-auth.ts`:

```ts
import { z } from "zod";
import { IsoDateTime, Uuid } from "./common.js";

const MYTSI_EMAIL = /^[^\s@]+@mytsi\.org$/i;

// ---- POST /v1/admin/auth/signup ----
export const AdminSignupRequest = z.object({
  email: z
    .string()
    .email()
    .refine((e) => MYTSI_EMAIL.test(e), {
      message: "Only @mytsi.org email addresses may request admin access.",
    }),
  password: z.string().min(8).max(200),
});
export type AdminSignupRequest = z.infer<typeof AdminSignupRequest>;

export const AdminSignupResponse = z.object({
  status: z.literal("pending"),
  message: z.string(),
});
export type AdminSignupResponse = z.infer<typeof AdminSignupResponse>;

// ---- POST /v1/admin/auth/login ----
export const AdminLoginRequest = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});
export type AdminLoginRequest = z.infer<typeof AdminLoginRequest>;

export const AdminLoginResponse = z.object({
  token: z.string(),
  expiresAt: IsoDateTime,
  account: z.object({ id: Uuid, email: z.string() }),
});
export type AdminLoginResponse = z.infer<typeof AdminLoginResponse>;

// ---- GET /v1/admin/auth/me ----
export const AdminMeResponse = z.object({
  id: Uuid,
  email: z.string(),
  isAdmin: z.boolean(),
});
export type AdminMeResponse = z.infer<typeof AdminMeResponse>;

// ---- GET /v1/admin/accounts/pending ----
export const AdminAccountStatus = z.enum(["pending", "approved", "rejected"]);
export type AdminAccountStatus = z.infer<typeof AdminAccountStatus>;

export const AdminPendingAccount = z.object({
  id: Uuid,
  email: z.string(),
  status: AdminAccountStatus,
  createdAt: IsoDateTime,
});
export type AdminPendingAccount = z.infer<typeof AdminPendingAccount>;

export const AdminPendingAccountsResponse = z.object({
  accounts: z.array(AdminPendingAccount),
});
export type AdminPendingAccountsResponse = z.infer<typeof AdminPendingAccountsResponse>;

// ---- POST /v1/admin/accounts/:id/approve, /v1/admin/accounts/:id/reject ----
export const AdminAccountActionResponse = z.object({
  id: Uuid,
  status: z.enum(["approved", "rejected"]),
});
export type AdminAccountActionResponse = z.infer<typeof AdminAccountActionResponse>;
```

- [ ] **Step 2: Settings + AI-provider contracts**

Create `packages/ts/contracts/src/settings.ts`:

```ts
import { z } from "zod";
import { IsoDateTime } from "./common.js";

export const AI_PROVIDER_NAMES = ["gemini", "groq", "openrouter", "ai_tutor_api"] as const;
export const AiProviderName = z.enum(AI_PROVIDER_NAMES);
export type AiProviderName = z.infer<typeof AiProviderName>;

/**
 * Per-key Zod validators. The single source of truth for what a setting's
 * `value` may hold. `PUT /v1/admin/settings/:key` validates against this
 * registry (not a single static request schema) because every key has a
 * different shape.
 */
export const SETTINGS_SCHEMA = {
  "max_books_per_user": z.number().int().min(1).max(50),
  "flag.groq_quiz_generation": z.boolean(),
  "flag.tts_pregeneration": z.boolean(),
  "flag.grounding_review_queue": z.boolean(),
  "grounding.auto_accept": z.number().min(0).max(1),
  "grounding.review_floor": z.number().min(0).max(1),
  "catalog.open_library_base_url": z.string().url(),
  "catalog.google_books_api_key": z.string(),
  "ai.gemini.model": z.string().min(1),
  "ai.deepgram.tts_model": z.string().min(1),
  "ai_provider.groq.api_key": z.string(),
  "ai_provider.groq.model": z.string().min(1),
  "ai_provider.groq.system_prompt.plan_generation": z.string(),
  "ai_provider.groq.system_prompt.quiz_generation": z.string(),
  "ai_provider.openrouter.api_key": z.string(),
  "ai_provider.openrouter.model": z.string(),
  "ai_provider.openrouter.system_prompt.plan_generation": z.string(),
  "ai_provider.openrouter.system_prompt.quiz_generation": z.string(),
  "ai_provider.ai_tutor_api.api_key": z.string(),
  "ai_provider.ai_tutor_api.workflow_id.book_grounding": z.string(),
  "ai_provider.ai_tutor_api.workflow_id.plan_generation": z.string(),
  "ai_provider.ai_tutor_api.workflow_id.quiz_generation": z.string(),
  "ai_provider.default": AiProviderName,
  "ai_provider.task_override.quiz_generation": AiProviderName.nullable(),
  "ai_provider.task_override.rewrite": AiProviderName.nullable(),
} as const satisfies Record<string, z.ZodType>;
export type SettingKey = keyof typeof SETTINGS_SCHEMA;
export const SETTING_KEYS = Object.keys(SETTINGS_SCHEMA) as SettingKey[];

/** Keys whose value is a credential — GET responses mask them, PUT accepts a fresh value only. */
export const SECRET_SETTING_KEYS: ReadonlySet<string> = new Set([
  "catalog.google_books_api_key",
  "ai_provider.groq.api_key",
  "ai_provider.openrouter.api_key",
  "ai_provider.ai_tutor_api.api_key",
]);

// ---- GET /v1/admin/settings ----
/** A secret row never carries its real value — only whether one is configured + a masked hint. */
export const AdminSettingRow = z.object({
  key: z.string(),
  value: z.unknown(),
  isSecret: z.boolean(),
  configured: z.boolean().optional(),
  hint: z.string().optional(),
  updatedAt: IsoDateTime,
});
export type AdminSettingRow = z.infer<typeof AdminSettingRow>;

export const AdminSettingsResponse = z.object({ settings: z.array(AdminSettingRow) });
export type AdminSettingsResponse = z.infer<typeof AdminSettingsResponse>;

// ---- PUT /v1/admin/settings/:key ----
export const AdminUpdateSettingRequest = z.object({ value: z.unknown() });
export type AdminUpdateSettingRequest = z.infer<typeof AdminUpdateSettingRequest>;

export const AdminUpdateSettingResponse = z.object({
  key: z.string(),
  updatedAt: IsoDateTime,
});
export type AdminUpdateSettingResponse = z.infer<typeof AdminUpdateSettingResponse>;

// ---- GET /v1/admin/ai/models?provider=groq|openrouter ----
export const AiModelInfo = z.object({
  id: z.string(),
  name: z.string(),
  contextLength: z.number().int().optional(),
  pricing: z.object({ prompt: z.string().optional(), completion: z.string().optional() }).optional(),
  modality: z.string().optional(),
});
export type AiModelInfo = z.infer<typeof AiModelInfo>;

export const AdminAiModelsResponse = z.object({
  provider: z.enum(["groq", "openrouter"]),
  models: z.array(AiModelInfo),
});
export type AdminAiModelsResponse = z.infer<typeof AdminAiModelsResponse>;
```

- [ ] **Step 3: Widen `EndpointDef.auth` and retag the 8 existing admin endpoints**

In `packages/ts/contracts/src/endpoints.ts`, change:

```ts
  auth: "user" | "admin" | "none";
```

to:

```ts
  auth: "user" | "admin" | "admin_panel" | "none";
```

Then change `auth: "admin",` to `auth: "admin_panel",` on all 8 existing entries: `adminGetGrounding`, `adminOverrideBook`, `adminGetMetrics`, `adminGetTts`, `adminInvalidateQuiz`, `adminListPlans`, `adminListQuizzes`, `adminTestPush`.

- [ ] **Step 4: Add the 10 new endpoint entries**

Add imports at the top of `endpoints.ts`:

```ts
import {
  AdminAccountActionResponse,
  AdminLoginRequest,
  AdminLoginResponse,
  AdminMeResponse,
  AdminPendingAccountsResponse,
  AdminSignupRequest,
  AdminSignupResponse,
} from "./admin-auth.js";
import {
  AdminAiModelsResponse,
  AdminSettingsResponse,
  AdminUpdateSettingRequest,
  AdminUpdateSettingResponse,
} from "./settings.js";
```

Append these 10 entries to the `ENDPOINTS` array, before the closing `] as const;`:

```ts
  {
    method: "post",
    path: "/v1/admin/auth/signup",
    operationId: "adminSignup",
    summary: "Request an admin-panel account (@mytsi.org only; requires approval).",
    tag: "admin-auth",
    auth: "none",
    request: AdminSignupRequest,
    response: AdminSignupResponse,
  },
  {
    method: "post",
    path: "/v1/admin/auth/login",
    operationId: "adminLogin",
    summary: "Log in to the admin panel; returns an opaque session token.",
    tag: "admin-auth",
    auth: "none",
    request: AdminLoginRequest,
    response: AdminLoginResponse,
  },
  {
    method: "post",
    path: "/v1/admin/auth/logout",
    operationId: "adminLogout",
    summary: "Revoke the caller's admin session.",
    tag: "admin-auth",
    auth: "admin_panel",
  },
  {
    method: "get",
    path: "/v1/admin/auth/me",
    operationId: "adminMe",
    summary: "Resolve the current admin-panel session.",
    tag: "admin-auth",
    auth: "admin_panel",
    response: AdminMeResponse,
  },
  {
    method: "get",
    path: "/v1/admin/accounts/pending",
    operationId: "adminListPendingAccounts",
    summary: "List admin-panel accounts awaiting approval.",
    tag: "admin-auth",
    auth: "admin_panel",
    response: AdminPendingAccountsResponse,
  },
  {
    method: "post",
    path: "/v1/admin/accounts/:id/approve",
    operationId: "adminApproveAccount",
    summary: "Approve a pending admin-panel account.",
    tag: "admin-auth",
    auth: "admin_panel",
    response: AdminAccountActionResponse,
  },
  {
    method: "post",
    path: "/v1/admin/accounts/:id/reject",
    operationId: "adminRejectAccount",
    summary: "Reject a pending admin-panel account.",
    tag: "admin-auth",
    auth: "admin_panel",
    response: AdminAccountActionResponse,
  },
  {
    method: "get",
    path: "/v1/admin/settings",
    operationId: "adminGetSettings",
    summary: "List every admin-editable setting (secrets masked).",
    tag: "settings",
    auth: "admin_panel",
    response: AdminSettingsResponse,
  },
  {
    method: "put",
    path: "/v1/admin/settings/:key",
    operationId: "adminPutSetting",
    summary: "Update one setting by key, validated against its per-key schema.",
    tag: "settings",
    auth: "admin_panel",
    request: AdminUpdateSettingRequest,
    response: AdminUpdateSettingResponse,
  },
  {
    method: "get",
    path: "/v1/admin/ai/models",
    operationId: "adminGetAiModels",
    summary: "Live model catalog for a given provider. `?provider=groq|openrouter`.",
    tag: "settings",
    auth: "admin_panel",
    response: AdminAiModelsResponse,
  },
```

- [ ] **Step 5: Export the new contract files**

In `packages/ts/contracts/src/index.ts`, add two lines after `export * from "./admin.js";`:

```ts
export * from "./admin-auth.js";
export * from "./settings.js";
```

- [ ] **Step 6: Cosmetic — label `admin_panel` routes with their real auth mechanism in the generated OpenAPI doc**

In `packages/ts/contracts/src/openapi.ts`, change:

```ts
  if (ep.auth !== "none") op["security"] = [{ bearerAuth: [] }];
```

to:

```ts
  if (ep.auth === "admin_panel") op["security"] = [{ adminBearerAuth: [] }];
  else if (ep.auth !== "none") op["security"] = [{ bearerAuth: [] }];
```

and add `adminBearerAuth` next to `bearerAuth` in `components.securitySchemes`:

```ts
    components: {
      securitySchemes: {
        bearerAuth: { type: "http", scheme: "bearer", bearerFormat: "JWT" },
        adminBearerAuth: { type: "http", scheme: "bearer", bearerFormat: "opaque admin session token" },
      },
    },
```

- [ ] **Step 7: Typecheck + build**

Run: `pnpm --filter @owlnighter/contracts run typecheck` → no errors.
Run: `pnpm --filter @owlnighter/contracts run build` → succeeds.

- [ ] **Step 8: Commit**

```bash
git add packages/ts/contracts/src/admin-auth.ts packages/ts/contracts/src/settings.ts packages/ts/contracts/src/endpoints.ts packages/ts/contracts/src/index.ts packages/ts/contracts/src/openapi.ts
git commit -m "feat(contracts): admin-panel auth, settings, and AI model catalog schemas"
```

## Task 6: Backend — admin-panel auth (signup/login/logout/me)

**Goal:** A new Bearer-token auth mechanism (`admin_panel`), fully parallel to the existing Supabase-based `user`/`admin` guards, backed by `admin_accounts`/`admin_sessions`. Passwords are hashed with Postgres `pgcrypto`'s `crypt()`/`gen_salt('bf')` (already enabled — no new dependency).

**Files:**
- Create: `apps/api/src/plugins/admin-session.ts`
- Create: `apps/api/src/services/admin-auth.ts`
- Create: `apps/api/src/routes/admin-auth.ts`
- Create: `apps/api/src/routes/admin-auth.test.ts`
- Modify: `apps/api/src/routes/helpers.ts` (add `admin_panel` branch to `guardFor`)
- Modify: `apps/api/src/app.ts` (register the new routes; fix CORS `credentials`)
- Modify: `apps/api/src/types.ts` (add `AdminPrincipal` + `req.adminAccount`)
- Modify: `apps/api/src/test/helpers.ts` (support mocking `db.execute()` for the pgcrypto calls)

**Acceptance Criteria:**
- [ ] `POST /v1/admin/auth/signup` rejects any non-`@mytsi.org` email with 400 before touching the DB.
- [ ] `POST /v1/admin/auth/login` returns 401 for a wrong password, 403 for a `pending`/`rejected` account, 200 + token for an approved admin.
- [ ] `GET /v1/admin/auth/me` 401s with no/invalid/expired token, 200s with the caller's identity for a valid one.
- [ ] `POST /v1/admin/auth/logout` deletes the session row (idempotent — no error if already gone).
- [ ] CORS allows credentialed cross-origin requests (`origin: true, credentials: true`).

**Verify:** `node --import tsx --test "apps/api/src/routes/admin-auth.test.ts"` → all pass.

**Steps:**

- [ ] **Step 1: Extend the test rig to mock `db.execute()`**

In `apps/api/src/test/helpers.ts`, change the `fakeDb` signature and body:

```ts
export function fakeDb(byTable: Map<unknown, Rows> = new Map(), executeResults: unknown[][] = []): Db {
```

and add `execute: async () => executeResults.shift() ?? [],` as a new property on the `db` object literal (alongside `select`/`insert`/`update`/`delete`).

Add `executeResults?: unknown[][];` to `FakeDepsOptions` (with a comment: `/** Canned results for deps.db.execute(), consumed in call order (pgcrypto hash/verify). */`), and pass it through in `fakeDeps`: change `db: fakeDb(opts.byTable),` to `db: fakeDb(opts.byTable, opts.executeResults ?? []),`.

- [ ] **Step 2: `AdminPrincipal` type + request augmentation**

In `apps/api/src/types.ts`, add after the `AuthUser` interface:

```ts
/** The resolved admin-panel operator, attached after adminPanelGuard runs. */
export interface AdminPrincipal {
  id: string;
  email: string;
  isAdmin: boolean;
}
```

and add `adminAccount?: AdminPrincipal;` inside the `declare module "fastify" { interface FastifyRequest { ... } }` block, alongside the existing `user?: AuthUser;` line.

- [ ] **Step 3: The guard plugin**

Create `apps/api/src/plugins/admin-session.ts`:

```ts
import type { FastifyReply, FastifyRequest } from "fastify";
import { eq } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import type { Deps } from "../deps.js";
import { hashToken } from "../utils/admin-crypto.js";
import { unauthorized } from "./errors.js";
import type { AdminPrincipal } from "../types.js";

function bearer(req: FastifyRequest): string | undefined {
  const header = req.headers.authorization;
  if (!header) return undefined;
  const [scheme, token] = header.split(" ");
  if (!scheme || scheme.toLowerCase() !== "bearer" || !token) return undefined;
  return token;
}

/** Resolve the admin-panel bearer token into an AdminPrincipal, or throw 401. */
export async function resolveAdmin(deps: Deps, req: FastifyRequest): Promise<AdminPrincipal> {
  const token = bearer(req);
  if (!token) throw unauthorized("Missing admin session token.");

  const sessionRows = await deps.db
    .select({ adminAccountId: schema.adminSessions.adminAccountId, expiresAt: schema.adminSessions.expiresAt })
    .from(schema.adminSessions)
    .where(eq(schema.adminSessions.tokenHash, hashToken(token)))
    .limit(1);
  const session = sessionRows[0];
  if (!session) throw unauthorized("Invalid admin session.");
  if (session.expiresAt.getTime() <= Date.now()) throw unauthorized("Admin session expired.");

  const accountRows = await deps.db
    .select({ id: schema.adminAccounts.id, email: schema.adminAccounts.email, isAdmin: schema.adminAccounts.isAdmin, status: schema.adminAccounts.status })
    .from(schema.adminAccounts)
    .where(eq(schema.adminAccounts.id, session.adminAccountId))
    .limit(1);
  const account = accountRows[0];
  if (!account || account.status !== "approved" || !account.isAdmin) {
    throw unauthorized("Admin account is no longer active.");
  }

  return { id: account.id, email: account.email, isAdmin: account.isAdmin };
}

/** Guard for `auth: "admin_panel"` routes. Attaches req.adminAccount. */
export function adminPanelGuard(deps: Deps) {
  return async (req: FastifyRequest, _reply: FastifyReply): Promise<void> => {
    req.adminAccount = await resolveAdmin(deps, req);
  };
}

/** Convenience: assert req.adminAccount is present (routes run behind adminPanelGuard). */
export function requireAdminAccount(req: FastifyRequest): AdminPrincipal {
  if (!req.adminAccount) throw unauthorized();
  return req.adminAccount;
}
```

Two separate selects (session, then account) rather than a join — this stays consistent with `plugins/auth.ts`'s style and is straightforward to exercise with the existing `fakeDb` test rig, which cannot model a real join.

- [ ] **Step 4: The service layer (pgcrypto hash/verify + signup/login/logout/me)**

Create `apps/api/src/services/admin-auth.ts`:

```ts
import { sql, eq } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import type {
  AdminLoginRequest,
  AdminLoginResponse,
  AdminMeResponse,
  AdminSignupRequest,
  AdminSignupResponse,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { badRequest, forbidden, unauthorized } from "../plugins/errors.js";
import { generateSessionToken, hashToken } from "../utils/admin-crypto.js";
import type { AdminPrincipal } from "../types.js";

const SESSION_DAYS = 30;

/** postgres-js's driver returns rows as a plain array; guard the node-postgres
 * `{rows}` shape too so this stays correct if the underlying driver ever changes. */
async function execOne<T>(deps: Deps, query: ReturnType<typeof sql>): Promise<T | undefined> {
  const result = await deps.db.execute(query);
  const rows = Array.isArray(result) ? result : ((result as { rows?: unknown[] }).rows ?? []);
  return rows[0] as T | undefined;
}

async function hashPassword(deps: Deps, password: string): Promise<string> {
  const row = await execOne<{ hash: string }>(deps, sql`select crypt(${password}, gen_salt('bf')) as hash`);
  if (!row) throw new Error("Password hashing failed.");
  return row.hash;
}

/** pgcrypto verify idiom: crypt(candidate, storedHash) re-derives the same hash
 * (using the salt embedded in storedHash) iff candidate is the right password. */
async function verifyPassword(deps: Deps, password: string, storedHash: string): Promise<boolean> {
  const row = await execOne<{ valid: boolean }>(
    deps,
    sql`select (crypt(${password}, ${storedHash}) = ${storedHash}) as valid`,
  );
  return row?.valid ?? false;
}

export async function signup(deps: Deps, req: AdminSignupRequest): Promise<AdminSignupResponse> {
  const existing = await deps.db
    .select({ id: schema.adminAccounts.id })
    .from(schema.adminAccounts)
    .where(sql`lower(${schema.adminAccounts.email}) = lower(${req.email})`)
    .limit(1);
  if (existing[0]) throw badRequest("An account with this email already exists or is pending approval.");

  const passwordHash = await hashPassword(deps, req.password);
  await deps.db.insert(schema.adminAccounts).values({
    email: req.email,
    passwordHash,
    status: "pending",
    isAdmin: false,
  });
  return {
    status: "pending",
    message: "Signup received. An existing admin must approve this account before you can log in.",
  };
}

export async function login(deps: Deps, req: AdminLoginRequest): Promise<AdminLoginResponse> {
  const rows = await deps.db
    .select()
    .from(schema.adminAccounts)
    .where(sql`lower(${schema.adminAccounts.email}) = lower(${req.email})`)
    .limit(1);
  const account = rows[0];
  if (!account) throw unauthorized("Invalid email or password.");

  const ok = await verifyPassword(deps, req.password, account.passwordHash);
  if (!ok) throw unauthorized("Invalid email or password.");

  if (account.status === "pending") throw forbidden("This account is awaiting admin approval.");
  if (account.status === "rejected") throw forbidden("This account's access request was rejected.");
  if (!account.isAdmin) throw forbidden("This account does not have admin access.");

  const token = generateSessionToken();
  const expiresAt = new Date(Date.now() + SESSION_DAYS * 24 * 60 * 60 * 1000);
  await deps.db.insert(schema.adminSessions).values({
    adminAccountId: account.id,
    tokenHash: hashToken(token),
    expiresAt,
  });

  return { token, expiresAt: expiresAt.toISOString(), account: { id: account.id, email: account.email } };
}

export async function logout(deps: Deps, token: string): Promise<void> {
  await deps.db.delete(schema.adminSessions).where(eq(schema.adminSessions.tokenHash, hashToken(token)));
}

export function me(admin: AdminPrincipal): AdminMeResponse {
  return { id: admin.id, email: admin.email, isAdmin: admin.isAdmin };
}
```

- [ ] **Step 5: Route wiring**

Create `apps/api/src/routes/admin-auth.ts`:

```ts
import type { FastifyInstance, FastifyRequest } from "fastify";
import type {
  AdminLoginRequest,
  AdminLoginResponse,
  AdminMeResponse,
  AdminSignupRequest,
  AdminSignupResponse,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { requireAdminAccount } from "../plugins/admin-session.js";
import { badRequest } from "../plugins/errors.js";
import { login, logout, me, signup } from "../services/admin-auth.js";
import { register } from "./helpers.js";

function bearerToken(req: FastifyRequest): string {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) throw badRequest("Missing bearer token.");
  return token;
}

export function registerAdminAuthRoutes(app: FastifyInstance, deps: Deps): void {
  register<AdminSignupRequest, AdminSignupResponse>(app, deps, "adminSignup", async ({ body }) => {
    return signup(deps, body);
  });

  register<AdminLoginRequest, AdminLoginResponse>(app, deps, "adminLogin", async ({ body }) => {
    return login(deps, body);
  });

  register<never, void>(app, deps, "adminLogout", async ({ req }) => {
    await logout(deps, bearerToken(req));
  });

  register<never, AdminMeResponse>(app, deps, "adminMe", async ({ req }) => {
    return me(requireAdminAccount(req));
  });
}
```

- [ ] **Step 6: Wire the new guard into `helpers.ts`, register routes + fix CORS in `app.ts`**

In `apps/api/src/routes/helpers.ts`, add the import `import { adminPanelGuard } from "../plugins/admin-session.js";` and change:

```ts
function guardFor(deps: Deps, auth: EndpointDef["auth"]): preHandlerHookHandler | undefined {
  if (auth === "user") return userGuard(deps) as preHandlerHookHandler;
  if (auth === "admin") return adminGuard(deps) as preHandlerHookHandler;
  return undefined;
}
```

to:

```ts
function guardFor(deps: Deps, auth: EndpointDef["auth"]): preHandlerHookHandler | undefined {
  if (auth === "user") return userGuard(deps) as preHandlerHookHandler;
  if (auth === "admin") return adminGuard(deps) as preHandlerHookHandler;
  if (auth === "admin_panel") return adminPanelGuard(deps) as preHandlerHookHandler;
  return undefined;
}
```

In `apps/api/src/app.ts`, add `import { registerAdminAuthRoutes } from "./routes/admin-auth.js";`, change `await app.register(cors, { origin: true });` to `await app.register(cors, { origin: true, credentials: true });` (needed so the admin console's browser-side cookie-bearing requests work cross-origin — see Task 13), and add `registerAdminAuthRoutes(app, deps);` right before `registerAdminRoutes(app, deps);`.

- [ ] **Step 7: Tests**

Create `apps/api/src/routes/admin-auth.test.ts`:

```ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../app.js";
import { fakeDeps, tableRows } from "../test/helpers.js";

test("signup rejects a non-@mytsi.org email (400)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/admin/auth/signup",
      payload: { email: "someone@gmail.com", password: "longenough1" },
    });
    assert.equal(res.statusCode, 400);
  } finally {
    await app.close();
  }
});

test("signup accepts an @mytsi.org email and reports pending", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows([schema.adminAccounts, []]);
  const app = await buildApp(fakeDeps({ byTable, executeResults: [[{ hash: "hashed" }]] }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/admin/auth/signup",
      payload: { email: "newperson@mytsi.org", password: "longenough1" },
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.json().status, "pending");
  } finally {
    await app.close();
  }
});

test("login rejects a wrong password (401)", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows([
    schema.adminAccounts,
    [{ id: "aaaaaaaa-0000-4000-8000-000000000001", email: "a@mytsi.org", passwordHash: "h", status: "approved", isAdmin: true }],
  ]);
  const app = await buildApp(fakeDeps({ byTable, executeResults: [[{ valid: false }]] }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/admin/auth/login",
      payload: { email: "a@mytsi.org", password: "wrong" },
    });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("login rejects a pending account (403)", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows([
    schema.adminAccounts,
    [{ id: "aaaaaaaa-0000-4000-8000-000000000002", email: "b@mytsi.org", passwordHash: "h", status: "pending", isAdmin: false }],
  ]);
  const app = await buildApp(fakeDeps({ byTable, executeResults: [[{ valid: true }]] }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/admin/auth/login",
      payload: { email: "b@mytsi.org", password: "correct" },
    });
    assert.equal(res.statusCode, 403);
  } finally {
    await app.close();
  }
});

test("login succeeds for an approved admin and issues a token", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows([
    schema.adminAccounts,
    [{ id: "aaaaaaaa-0000-4000-8000-000000000003", email: "c@mytsi.org", passwordHash: "h", status: "approved", isAdmin: true }],
  ]);
  const app = await buildApp(fakeDeps({ byTable, executeResults: [[{ valid: true }]] }));
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/admin/auth/login",
      payload: { email: "c@mytsi.org", password: "correct" },
    });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { token: string; account: { email: string } };
    assert.ok(body.token.length > 0);
    assert.equal(body.account.email, "c@mytsi.org");
  } finally {
    await app.close();
  }
});

test("GET /v1/admin/auth/me requires a valid session (401 with no token)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "GET", url: "/v1/admin/auth/me" });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("GET /v1/admin/auth/me resolves the caller from a valid session token", async () => {
  const { schema } = await import("@owlnighter/db");
  const accountId = "aaaaaaaa-0000-4000-8000-000000000004";
  const byTable = tableRows(
    [schema.adminSessions, [{ adminAccountId: accountId, expiresAt: new Date(Date.now() + 86_400_000) }]],
    [schema.adminAccounts, [{ id: accountId, email: "d@mytsi.org", isAdmin: true, status: "approved" }]],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({
      method: "GET",
      url: "/v1/admin/auth/me",
      headers: { authorization: "Bearer test-token-value" },
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.json().email, "d@mytsi.org");
  } finally {
    await app.close();
  }
});
```

- [ ] **Step 8: Typecheck + test**

Run: `pnpm --filter @owlnighter/api run typecheck` → no errors.
Run: `node --import tsx --test "apps/api/src/routes/admin-auth.test.ts"` → all 7 pass.

- [ ] **Step 9: Commit**

```bash
git add apps/api/src/plugins/admin-session.ts apps/api/src/services/admin-auth.ts apps/api/src/routes/admin-auth.ts apps/api/src/routes/admin-auth.test.ts apps/api/src/routes/helpers.ts apps/api/src/app.ts apps/api/src/types.ts apps/api/src/test/helpers.ts
git commit -m "feat(api): admin-panel auth (signup/login/logout/me)"
```

## Task 7: Backend — admin account approval + migrate existing admin routes' tests

**Goal:** Approved admins can list, approve, and reject pending signups. The 8 pre-existing `/v1/admin/*` routes automatically start enforcing the new `admin_panel` guard (via Task 5's retag + Task 6's `guardFor` branch — no route-file changes needed), so this task's other job is bringing `admin.test.ts` in line with the new auth mechanism.

**Files:**
- Modify: `apps/api/src/services/admin-auth.ts` (add `listPendingAccounts`/`approveAccount`/`rejectAccount`)
- Modify: `apps/api/src/routes/admin-auth.ts` (wire the 3 new routes)
- Modify: `apps/api/src/admin.test.ts` (replace the old Supabase-dev-bearer auth fixtures with admin-panel session fixtures)

**Acceptance Criteria:**
- [ ] `GET /v1/admin/accounts/pending` lists only `status='pending'` accounts, oldest first.
- [ ] `POST /v1/admin/accounts/:id/approve` sets `status='approved', is_admin=true, approved_by, approved_at`.
- [ ] `POST /v1/admin/accounts/:id/reject` sets `status='rejected'` and records `approved_by`/`approved_at`.
- [ ] Both approve/reject 404 for an unknown account id.
- [ ] Every test in `admin.test.ts` authenticates via a valid `admin_panel` session fixture; the file has no remaining references to `DEV_BEARER` or `schema.profiles`-based admin resolution.

**Verify:** `node --import tsx --test "apps/api/src/admin.test.ts" "apps/api/src/routes/admin-auth.test.ts"` → all pass.

**Steps:**

- [ ] **Step 1: Add the 3 service functions**

In `apps/api/src/services/admin-auth.ts`, add `asc, eq` to the `drizzle-orm` import (it currently imports `sql, eq`; change to `import { asc, eq, sql } from "drizzle-orm";`), add `notFound` to the `../plugins/errors.js` import, and add `AdminAccountActionResponse, AdminAccountStatus, AdminPendingAccountsResponse` to the `@owlnighter/contracts` import. Then append:

```ts
export async function listPendingAccounts(deps: Deps): Promise<AdminPendingAccountsResponse> {
  const rows = await deps.db
    .select({
      id: schema.adminAccounts.id,
      email: schema.adminAccounts.email,
      status: schema.adminAccounts.status,
      createdAt: schema.adminAccounts.createdAt,
    })
    .from(schema.adminAccounts)
    .where(eq(schema.adminAccounts.status, "pending"))
    .orderBy(asc(schema.adminAccounts.createdAt));
  return {
    accounts: rows.map((r) => ({
      id: r.id,
      email: r.email,
      status: r.status as AdminAccountStatus,
      createdAt: r.createdAt.toISOString(),
    })),
  };
}

export async function approveAccount(
  deps: Deps,
  admin: AdminPrincipal,
  accountId: string,
): Promise<AdminAccountActionResponse> {
  const rows = await deps.db
    .select({ id: schema.adminAccounts.id })
    .from(schema.adminAccounts)
    .where(eq(schema.adminAccounts.id, accountId))
    .limit(1);
  if (!rows[0]) throw notFound("Account not found.");
  await deps.db
    .update(schema.adminAccounts)
    .set({ status: "approved", isAdmin: true, approvedBy: admin.id, approvedAt: new Date(), updatedAt: new Date() })
    .where(eq(schema.adminAccounts.id, accountId));
  return { id: accountId, status: "approved" };
}

export async function rejectAccount(
  deps: Deps,
  admin: AdminPrincipal,
  accountId: string,
): Promise<AdminAccountActionResponse> {
  const rows = await deps.db
    .select({ id: schema.adminAccounts.id })
    .from(schema.adminAccounts)
    .where(eq(schema.adminAccounts.id, accountId))
    .limit(1);
  if (!rows[0]) throw notFound("Account not found.");
  await deps.db
    .update(schema.adminAccounts)
    .set({ status: "rejected", approvedBy: admin.id, approvedAt: new Date(), updatedAt: new Date() })
    .where(eq(schema.adminAccounts.id, accountId));
  return { id: accountId, status: "rejected" };
}
```

- [ ] **Step 2: Wire the 3 new routes**

In `apps/api/src/routes/admin-auth.ts`, add `AdminAccountActionResponse, AdminPendingAccountsResponse` to the `@owlnighter/contracts` import, add `approveAccount, listPendingAccounts, rejectAccount` to the `../services/admin-auth.js` import, and append inside `registerAdminAuthRoutes`:

```ts
  register<never, AdminPendingAccountsResponse>(app, deps, "adminListPendingAccounts", async () => {
    return listPendingAccounts(deps);
  });

  register<never, AdminAccountActionResponse>(app, deps, "adminApproveAccount", async ({ req, params }) => {
    const admin = requireAdminAccount(req);
    const id = params["id"];
    if (!id) throw badRequest("Missing account id.");
    return approveAccount(deps, admin, id);
  });

  register<never, AdminAccountActionResponse>(app, deps, "adminRejectAccount", async ({ req, params }) => {
    const admin = requireAdminAccount(req);
    const id = params["id"];
    if (!id) throw badRequest("Missing account id.");
    return rejectAccount(deps, admin, id);
  });
```

- [ ] **Step 3: Migrate `admin.test.ts` to the new auth mechanism**

In `apps/api/src/admin.test.ts`:

1. Replace the import line:

```ts
import { DEV_BEARER, DEV_USER_ID, fakeDeps, tableRows, type Rows } from "./test/helpers.js";
```

with:

```ts
import { DEV_USER_ID, fakeDeps, tableRows, type Rows } from "./test/helpers.js";
```

2. Replace the `adminTables` helper (the function starting `/** Admin routes resolve is_admin from profiles... */`) with:

```ts
const ADMIN_ACCOUNT_ID = "90000000-0000-4000-8000-000000000001";
const ADMIN_BEARER = { authorization: "Bearer admin-test-token" } as const;

/** Admin-panel routes resolve the caller via a valid admin_sessions row + its
 * approved admin_accounts row; register both for every admin.test.ts case. */
async function adminAuthTables(...extra: Array<[unknown, Rows]>) {
  const { schema } = await import("@owlnighter/db");
  return tableRows(
    [schema.adminSessions, [{ adminAccountId: ADMIN_ACCOUNT_ID, expiresAt: new Date(Date.now() + 86_400_000) }]],
    [schema.adminAccounts, [{ id: ADMIN_ACCOUNT_ID, email: "admin@mytsi.org", isAdmin: true, status: "approved" }]],
    ...extra,
  );
}
```

3. Replace the two "Auth boundary" tests with three:

```ts
test("admin_panel route rejects a missing bearer (401)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "GET", url: "/v1/admin/metrics" });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("admin_panel route rejects an unknown token (401)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({
      method: "GET",
      url: "/v1/admin/metrics",
      headers: { authorization: "Bearer not-a-real-token" },
    });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("admin_panel route rejects an expired session (401)", async () => {
  const { schema } = await import("@owlnighter/db");
  const byTable = tableRows(
    [schema.adminSessions, [{ adminAccountId: ADMIN_ACCOUNT_ID, expiresAt: new Date(Date.now() - 1000) }]],
    [schema.adminAccounts, [{ id: ADMIN_ACCOUNT_ID, email: "admin@mytsi.org", isAdmin: true, status: "approved" }]],
  );
  const app = await buildApp(fakeDeps({ byTable }));
  try {
    const res = await app.inject({ method: "GET", url: "/v1/admin/metrics", headers: ADMIN_BEARER });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});
```

4. Global find-replace across the rest of the file: every remaining call `adminTables(` → `adminAuthTables(`, and every `headers: DEV_BEARER` → `headers: ADMIN_BEARER` (10 occurrences each — one per remaining test).

- [ ] **Step 4: Typecheck + test**

Run: `pnpm --filter @owlnighter/api run typecheck` → no errors.
Run: `node --import tsx --test "apps/api/src/admin.test.ts" "apps/api/src/routes/admin-auth.test.ts"` → all pass.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/services/admin-auth.ts apps/api/src/routes/admin-auth.ts apps/api/src/admin.test.ts
git commit -m "feat(api): admin account approval + migrate admin route tests to admin_panel auth"
```

## Task 8: Seed script for the 3 admin accounts

**Goal:** One idempotent script seeds the 3 given admin accounts as pre-approved.

**Files:**
- Create: `packages/ts/db/scripts/seed-admin-accounts.mjs`
- Modify: `packages/ts/db/package.json` (add `seed:admin` script)

**Acceptance Criteria:**
- [ ] Running the script twice in a row does not error and does not duplicate rows (upsert by case-insensitive email).
- [ ] All 3 accounts end up `status='approved', is_admin=true`.
- [ ] Passwords are hashed via `crypt(password, gen_salt('bf'))` — never stored in plaintext.

**Verify:** `DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:55432/postgres pnpm --filter @owlnighter/db run seed:admin` → prints `ok` for all 3 emails, then `psql postgresql://postgres:postgres@127.0.0.1:55432/postgres -c "select email, status, is_admin from admin_accounts order by email;"` shows all 3 as `approved`/`t`.

**Steps:**

- [ ] **Step 1: Write the script**

Create `packages/ts/db/scripts/seed-admin-accounts.mjs`:

```js
// Idempotent upsert of the 3 pre-approved admin-panel accounts.
// Usage: DATABASE_URL=... node scripts/seed-admin-accounts.mjs
import postgres from "postgres";

const url = process.env.DATABASE_URL;
if (!url) {
  console.error("DATABASE_URL is required");
  process.exit(1);
}

const ACCOUNTS = [
  { email: "rcohen@mytsi.org", password: "REDACTED_PASSWORD" },
  { email: "nkukaj@mytsi.org", password: "REDACTED_PASSWORD" },
  { email: "afarhadi@mytsi.org", password: "REDACTED_PASSWORD" },
];

const sql = postgres(url, { max: 1 });
try {
  for (const { email, password } of ACCOUNTS) {
    process.stdout.write(`Seeding ${email} ... `);
    await sql`
      insert into admin_accounts (email, password_hash, status, is_admin)
      values (${email}, crypt(${password}, gen_salt('bf')), 'approved', true)
      on conflict (lower(email)) do update
        set password_hash = excluded.password_hash,
            status = 'approved',
            is_admin = true,
            updated_at = now()
    `;
    console.log("ok");
  }
  console.log(`\n✓ Seeded ${ACCOUNTS.length} admin account(s).`);
} finally {
  await sql.end();
}
```

- [ ] **Step 2: Add the package script**

In `packages/ts/db/package.json`, add `"seed:admin": "node ./scripts/seed-admin-accounts.mjs",` to `"scripts"` (alongside the existing `"migrate"` entry).

- [ ] **Step 3: Run it against local dev Postgres**

Run: `DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:55432/postgres pnpm --filter @owlnighter/db run seed:admin` → prints `Seeding rcohen@mytsi.org ... ok` etc. for all 3, ends with `✓ Seeded 3 admin account(s).`
Run it a second time → identical output, no errors (confirms idempotency).
Run: `psql postgresql://postgres:postgres@127.0.0.1:55432/postgres -c "select email, status, is_admin from admin_accounts order by email;"` → 3 rows, all `approved` / `t`.

- [ ] **Step 4: Commit**

```bash
git add packages/ts/db/scripts/seed-admin-accounts.mjs packages/ts/db/package.json
git commit -m "feat(db): seed script for the 3 pre-approved admin accounts"
```

## Task 9: Settings CRUD + `getSetting` cache + wire `max_books_per_user`

**Goal:** Admins can read/edit every `app_settings` row via HTTP (secrets masked), reads are ~30s cached, and adding a 4th active book is rejected with a clear message.

**Files:**
- Create: `packages/ts/db/src/settings.ts`
- Modify: `packages/ts/db/src/index.ts` (export it)
- Modify: `apps/api/src/deps.ts` (add `settings: SettingsCache` to `Deps`)
- Create: `apps/api/src/services/settings.ts`
- Create: `apps/api/src/routes/settings.ts`
- Create: `apps/api/src/routes/settings.test.ts`
- Modify: `apps/api/src/app.ts` (register the new routes)
- Modify: `apps/api/src/routes/library.ts` (enforce `max_books_per_user`; single-query refactor of `addLibraryBook`)
- Modify: `apps/api/src/routes/library.test.ts` (new limit test)
- Modify: `apps/api/src/test/helpers.ts` (add `fakeSettings()`, wire a default into `fakeDeps()`)

**Acceptance Criteria:**
- [ ] `GET /v1/admin/settings` returns every row; secret rows carry `{configured, hint}`, never the real value.
- [ ] `PUT /v1/admin/settings/:key` 404s for an unknown key, 400s for a value that fails that key's Zod schema, 200s + persists otherwise.
- [ ] `deps.settings.get(key, fallback)` caches reads for ~30s and is invalidated immediately on write.
- [ ] `POST /v1/library/books` rejects a new (non-reactivation) addition once the caller's active-book count meets `max_books_per_user`, with a 400 and a human-readable message.

**Verify:** `node --import tsx --test "apps/api/src/routes/settings.test.ts" "apps/api/src/routes/library.test.ts"` → all pass.

**Steps:**

- [ ] **Step 1: The settings cache**

Create `packages/ts/db/src/settings.ts`:

```ts
import { eq } from "drizzle-orm";
import type { Db } from "./client.js";
import { appSettings } from "./schema.js";

const TTL_MS = 30_000;

export interface SettingRow {
  key: string;
  value: unknown;
  isSecret: boolean;
  updatedAt: Date;
}

export interface SettingsCache {
  /** Read a setting's value as T, falling back when the row is missing. Cached ~30s. */
  get<T>(key: string, fallback: T): Promise<T>;
  /** Every row, uncached — used by the admin settings list endpoint. */
  listAll(): Promise<SettingRow[]>;
  /** Upsert a value and drop the cached copy for that key. Returns the new updatedAt. */
  set(key: string, value: unknown, isSecret: boolean, updatedBy: string | undefined): Promise<Date>;
  /** Drop a cached key (or the whole cache when omitted). */
  invalidate(key?: string): void;
}

export function createSettingsCache(db: Db): SettingsCache {
  const cache = new Map<string, { value: unknown; expiresAt: number }>();

  return {
    async get<T>(key: string, fallback: T): Promise<T> {
      const cached = cache.get(key);
      if (cached && cached.expiresAt > Date.now()) return cached.value as T;
      const rows = await db.select().from(appSettings).where(eq(appSettings.key, key)).limit(1);
      const value = (rows[0]?.value ?? fallback) as T;
      cache.set(key, { value, expiresAt: Date.now() + TTL_MS });
      return value;
    },

    async listAll(): Promise<SettingRow[]> {
      const rows = await db.select().from(appSettings);
      return rows.map((r) => ({ key: r.key, value: r.value, isSecret: r.isSecret, updatedAt: r.updatedAt }));
    },

    async set(key: string, value: unknown, isSecret: boolean, updatedBy: string | undefined): Promise<Date> {
      const updatedAt = new Date();
      await db
        .insert(appSettings)
        .values({ key, value, isSecret, updatedAt, updatedBy: updatedBy ?? null })
        .onConflictDoUpdate({ target: appSettings.key, set: { value, updatedAt, updatedBy: updatedBy ?? null } });
      cache.delete(key);
      return updatedAt;
    },

    invalidate(key?: string): void {
      if (key) cache.delete(key);
      else cache.clear();
    },
  };
}
```

In `packages/ts/db/src/index.ts`, add `export * from "./settings.js";`.

- [ ] **Step 2: Wire `settings` into `Deps`**

In `apps/api/src/deps.ts`, change the `@owlnighter/db` import to `import { createSettingsCache, getDb, type Db, type SettingsCache } from "@owlnighter/db";`, add `settings: SettingsCache;` to the `Deps` interface, and in `buildDeps()`:

```ts
  const db = getDb(env.DATABASE_URL);
  const settings = createSettingsCache(db);
```

and add `settings` to the returned object: `cached = { config, db, ai, supabase, ensureTtsAsset, settings };`.

- [ ] **Step 3: Service layer**

Create `apps/api/src/services/settings.ts`:

```ts
import {
  SECRET_SETTING_KEYS,
  SETTINGS_SCHEMA,
  type AdminSettingsResponse,
  type AdminUpdateSettingResponse,
  type SettingKey,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { badRequest, notFound } from "../plugins/errors.js";

function maskHint(value: unknown): string {
  const s = typeof value === "string" ? value : "";
  return s.length === 0 ? "not set" : `…${s.slice(-4)}`;
}

export async function getAllSettings(deps: Deps): Promise<AdminSettingsResponse> {
  const rows = await deps.settings.listAll();
  return {
    settings: rows.map((r) => {
      if (r.isSecret) {
        const configured = typeof r.value === "string" && r.value.length > 0;
        return {
          key: r.key,
          value: undefined,
          isSecret: true,
          configured,
          hint: maskHint(r.value),
          updatedAt: r.updatedAt.toISOString(),
        };
      }
      return { key: r.key, value: r.value, isSecret: false, updatedAt: r.updatedAt.toISOString() };
    }),
  };
}

export async function updateSetting(
  deps: Deps,
  adminId: string,
  key: string,
  rawValue: unknown,
): Promise<AdminUpdateSettingResponse> {
  const schema = SETTINGS_SCHEMA[key as SettingKey];
  if (!schema) throw notFound(`Unknown setting key: ${key}`);
  const parsed = schema.safeParse(rawValue);
  if (!parsed.success) throw badRequest(`Invalid value for "${key}".`, parsed.error.issues);
  const isSecret = SECRET_SETTING_KEYS.has(key);
  const updatedAt = await deps.settings.set(key, parsed.data, isSecret, adminId);
  return { key, updatedAt: updatedAt.toISOString() };
}
```

- [ ] **Step 4: Route wiring**

Create `apps/api/src/routes/settings.ts`:

```ts
import type { FastifyInstance } from "fastify";
import type {
  AdminSettingsResponse,
  AdminUpdateSettingRequest,
  AdminUpdateSettingResponse,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { requireAdminAccount } from "../plugins/admin-session.js";
import { badRequest } from "../plugins/errors.js";
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
}
```

In `apps/api/src/app.ts`, add `import { registerSettingsRoutes } from "./routes/settings.js";` and `registerSettingsRoutes(app, deps);` next to the other route registrations.

- [ ] **Step 5: Extend the test rig with a fake settings cache**

In `apps/api/src/test/helpers.ts`, add the `SettingsCache` import to the `@owlnighter/db` import line, and add:

```ts
export interface FakeSettingsOptions {
  rows?: Array<{ key: string; value: unknown; isSecret?: boolean }>;
}

/** An in-memory SettingsCache for tests — no TTL, no DB. */
export function fakeSettings(opts: FakeSettingsOptions = {}): SettingsCache {
  const store = new Map<string, { value: unknown; isSecret: boolean }>(
    (opts.rows ?? []).map((r) => [r.key, { value: r.value, isSecret: r.isSecret ?? false }]),
  );
  return {
    async get<T>(key: string, fallback: T): Promise<T> {
      return (store.has(key) ? store.get(key)!.value : fallback) as T;
    },
    async listAll() {
      return Array.from(store.entries()).map(([key, r]) => ({
        key,
        value: r.value,
        isSecret: r.isSecret,
        updatedAt: new Date(),
      }));
    },
    async set(key: string, value: unknown, isSecret = false) {
      store.set(key, { value, isSecret });
      return new Date();
    },
    invalidate() {},
  };
}
```

Add `settings?: SettingsCache;` to `FakeDepsOptions`, and change the `fakeDeps` return object's `db: fakeDb(opts.byTable, opts.executeResults ?? []),` line to also include `settings: opts.settings ?? fakeSettings(),` right after it.

- [ ] **Step 6: Enforce `max_books_per_user` in `library.ts`**

In `apps/api/src/routes/library.ts`, add `badRequest` to the `../plugins/errors.js` import (currently only `notFound`), and replace the entire `addLibraryBook` handler body with a version that fetches the caller's library rows once and reuses them for both the reactivation check and the limit check:

```ts
  register<AddLibraryBookRequest, LibraryBook>(app, deps, "addLibraryBook", async ({ req, body }) => {
    const user = requireUser(req);

    const book = await deps.db
      .select({ id: schema.books.id })
      .from(schema.books)
      .where(eq(schema.books.id, body.bookId))
      .limit(1);
    if (!book[0]) throw notFound("Book not found. Ground it first via POST /v1/books/ground.");

    // Single fetch of the caller's library rows — reused for both the
    // reactivate-existing-entry check and the max-books-per-user limit below.
    const userBooksRows = await deps.db
      .select()
      .from(schema.userBooks)
      .where(eq(schema.userBooks.userId, user.id));
    const existingRow = userBooksRows.find((r) => r.bookId === body.bookId);

    if (existingRow) {
      await deps.db
        .update(schema.userBooks)
        .set({ status: "active", targetNightlyPages: body.targetNightlyPages, timezone: body.timezone })
        .where(eq(schema.userBooks.id, existingRow.id));
      return {
        id: existingRow.id,
        bookId: existingRow.bookId,
        status: "active",
        ...(existingRow.currentPage != null ? { currentPage: existingRow.currentPage } : {}),
        targetNightlyPages: body.targetNightlyPages,
      };
    }

    const maxBooks = await deps.settings.get("max_books_per_user", 3);
    const activeCount = userBooksRows.filter((r) => r.status === "active").length;
    if (activeCount >= maxBooks) {
      throw badRequest(
        `You've reached the limit of ${maxBooks} active books. Pause or finish one before adding another.`,
      );
    }

    const inserted = await deps.db
      .insert(schema.userBooks)
      .values({
        userId: user.id,
        bookId: body.bookId,
        status: "active",
        targetNightlyPages: body.targetNightlyPages,
        preferredReadingTimeLocal: body.preferredReadingTimeLocal ?? null,
        timezone: body.timezone,
      })
      .returning({ id: schema.userBooks.id, currentPage: schema.userBooks.currentPage });
    const row = inserted[0]!;
    return {
      id: row.id,
      bookId: body.bookId,
      status: "active",
      ...(row.currentPage != null ? { currentPage: row.currentPage } : {}),
      targetNightlyPages: body.targetNightlyPages,
    };
  });
```

(The `and(eq(userId), eq(bookId))` lookup is intentionally replaced by fetching all of the user's rows once and filtering in JS — the per-user row count is always small, and this is what makes the max-books count derivable from the same query instead of a second DB round trip.)

- [ ] **Step 7: Tests**

Create `apps/api/src/routes/settings.test.ts`:

```ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../app.js";
import { fakeDeps, fakeSettings, tableRows } from "../test/helpers.js";

const ADMIN_ACCOUNT_ID = "90000000-0000-4000-8000-000000000002";
const ADMIN_BEARER = { authorization: "Bearer settings-test-token" } as const;

async function adminAuthTables() {
  const { schema } = await import("@owlnighter/db");
  return tableRows(
    [schema.adminSessions, [{ adminAccountId: ADMIN_ACCOUNT_ID, expiresAt: new Date(Date.now() + 86_400_000) }]],
    [schema.adminAccounts, [{ id: ADMIN_ACCOUNT_ID, email: "settings-admin@mytsi.org", isAdmin: true, status: "approved" }]],
  );
}

test("GET /v1/admin/settings requires admin_panel auth (401)", async () => {
  const app = await buildApp(fakeDeps());
  try {
    const res = await app.inject({ method: "GET", url: "/v1/admin/settings" });
    assert.equal(res.statusCode, 401);
  } finally {
    await app.close();
  }
});

test("GET /v1/admin/settings masks secret values", async () => {
  const byTable = await adminAuthTables();
  const settings = fakeSettings({
    rows: [
      { key: "max_books_per_user", value: 3, isSecret: false },
      { key: "ai_provider.groq.api_key", value: "sk-real-secret-value", isSecret: true },
    ],
  });
  const app = await buildApp(fakeDeps({ byTable, settings }));
  try {
    const res = await app.inject({ method: "GET", url: "/v1/admin/settings", headers: ADMIN_BEARER });
    assert.equal(res.statusCode, 200);
    const body = res.json() as { settings: Array<Record<string, unknown>> };
    const plain = body.settings.find((s) => s["key"] === "max_books_per_user")!;
    assert.equal(plain["value"], 3);
    const secret = body.settings.find((s) => s["key"] === "ai_provider.groq.api_key")!;
    assert.equal(secret["configured"], true);
    assert.equal(secret["value"], undefined);
    assert.ok(!JSON.stringify(secret).includes("sk-real-secret-value"));
  } finally {
    await app.close();
  }
});

test("PUT /v1/admin/settings/:key rejects an invalid value (400)", async () => {
  const byTable = await adminAuthTables();
  const app = await buildApp(fakeDeps({ byTable, settings: fakeSettings() }));
  try {
    const res = await app.inject({
      method: "PUT",
      url: "/v1/admin/settings/max_books_per_user",
      headers: ADMIN_BEARER,
      payload: { value: -1 },
    });
    assert.equal(res.statusCode, 400);
  } finally {
    await app.close();
  }
});

test("PUT /v1/admin/settings/:key rejects an unknown key (404)", async () => {
  const byTable = await adminAuthTables();
  const app = await buildApp(fakeDeps({ byTable, settings: fakeSettings() }));
  try {
    const res = await app.inject({
      method: "PUT",
      url: "/v1/admin/settings/not_a_real_key",
      headers: ADMIN_BEARER,
      payload: { value: 1 },
    });
    assert.equal(res.statusCode, 404);
  } finally {
    await app.close();
  }
});

test("PUT /v1/admin/settings/:key updates a valid value (200)", async () => {
  const byTable = await adminAuthTables();
  const app = await buildApp(fakeDeps({ byTable, settings: fakeSettings() }));
  try {
    const res = await app.inject({
      method: "PUT",
      url: "/v1/admin/settings/max_books_per_user",
      headers: ADMIN_BEARER,
      payload: { value: 5 },
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.json().key, "max_books_per_user");
  } finally {
    await app.close();
  }
});
```

Add to `apps/api/src/routes/library.test.ts` (after the existing 404 test, still inside the same file, reusing its existing imports):

```ts
test("POST /v1/library/books rejects a new addition once max_books_per_user is reached", async () => {
  const { schema } = await import("@owlnighter/db");
  const { fakeSettings } = await import("../test/helpers.js");
  const NEW_BOOK_ID = "33333333-3333-4333-8333-333333333333";
  const byTable = tableRows(
    [schema.profiles, []],
    [schema.books, [{ id: NEW_BOOK_ID }]],
    [
      schema.userBooks,
      [
        { id: "u1", bookId: "aaaaaaaa-0000-4000-8000-000000000001", status: "active" },
        { id: "u2", bookId: "aaaaaaaa-0000-4000-8000-000000000002", status: "active" },
        { id: "u3", bookId: "aaaaaaaa-0000-4000-8000-000000000003", status: "active" },
      ],
    ],
  );
  const app = await buildApp(
    fakeDeps({ byTable, settings: fakeSettings({ rows: [{ key: "max_books_per_user", value: 3 }] }) }),
  );
  try {
    const res = await app.inject({
      method: "POST",
      url: "/v1/library/books",
      headers: DEV_BEARER,
      payload: { bookId: NEW_BOOK_ID },
    });
    assert.equal(res.statusCode, 400);
  } finally {
    await app.close();
  }
});
```

- [ ] **Step 8: Typecheck + test**

Run: `pnpm --filter @owlnighter/db run typecheck` → no errors.
Run: `pnpm --filter @owlnighter/api run typecheck` → no errors.
Run: `node --import tsx --test "apps/api/src/routes/settings.test.ts" "apps/api/src/routes/library.test.ts"` → all pass (5 in settings.test.ts, 5 in library.test.ts).

- [ ] **Step 9: Commit**

```bash
git add packages/ts/db/src/settings.ts packages/ts/db/src/index.ts apps/api/src/deps.ts apps/api/src/services/settings.ts apps/api/src/routes/settings.ts apps/api/src/routes/settings.test.ts apps/api/src/app.ts apps/api/src/routes/library.ts apps/api/src/routes/library.test.ts apps/api/src/test/helpers.ts
git commit -m "feat(api): settings CRUD, cached getSetting, and max_books_per_user enforcement"
```

## Task 10: AI router — settings-driven Groq/OpenRouter + `OpenRouterAdapter`

**Goal:** `packages/ts/ai`'s router reads Groq/OpenRouter keys, models, and (for `quiz_generation`/`rewrite` only) a provider override live from admin settings on every call — no redeploy needed — while Gemini's hardcoded, contract-critical grounding/plan role is untouched. A new `OpenRouterAdapter` mirrors `GroqAdapter`'s proven JSON-object-mode + app-side-validation pattern.

**Files:**
- Modify: `packages/ts/ai/src/types.ts` (add `AiTutorRuntimeConfig`, `SettingsSnapshot`, `SettingsReader`)
- Create: `packages/ts/ai/src/openrouter.ts`
- Modify: `packages/ts/ai/src/router.ts` (full rewrite — supersedes Task 3 Step 5's placeholder body)
- Modify: `packages/ts/ai/src/index.ts` (export `OpenRouterAdapter`)
- Modify: `packages/ts/ai/src/router.test.ts` (settings-aware call sites + 1 new test)
- Create: `apps/api/src/services/ai-settings.ts`
- Modify: `apps/api/src/deps.ts` (`createAiRouter(env, settingsReader)`)

**Acceptance Criteria:**
- [ ] `createAiRouter(env, settings)` — the 2nd param is a `SettingsReader`.
- [ ] Groq's effective API key/model prefer the admin setting, falling back to the env var when the setting is empty.
- [ ] OpenRouter is only considered "configured" when both its api key and model settings are non-empty.
- [ ] `ai_provider.task_override.quiz_generation`/`.rewrite`, when set, override routing for those two tasks only — `book_grounding`/`plan_generation` are never affected by the override.
- [ ] All 4 pre-existing `router.test.ts` tests still pass; a new test proves a task override actually routes to the overridden provider.

**Verify:** `pnpm --filter @owlnighter/ai run test` → 5 tests pass.

**Steps:**

- [ ] **Step 1: Extend `types.ts`**

Append to `packages/ts/ai/src/types.ts` (after the `ProviderRuntimeConfig` interface Task 3 added):

```ts
export interface AiTutorRuntimeConfig {
  apiKey: string;
  workflowIds: Partial<Record<AiTask, string>>;
}

/** What the router asks for on every call — always fresh (the settings-cache
 * layer underneath owns the ~30s TTL), so admin edits apply without a restart. */
export interface SettingsSnapshot {
  groq: ProviderRuntimeConfig;
  openrouter: ProviderRuntimeConfig;
  aiTutorApi: AiTutorRuntimeConfig;
  taskOverrides: Partial<Record<AiTask, ProviderName>>;
}

export interface SettingsReader {
  snapshot(): Promise<SettingsSnapshot>;
}
```

- [ ] **Step 2: `OpenRouterAdapter`**

Create `packages/ts/ai/src/openrouter.ts`:

```ts
import type {
  AiTextResult,
  Citation,
  GenerateObjectOptions,
  GenerateTextOptions,
  ProviderAdapter,
  ProviderRuntimeConfig,
} from "./types.js";

const ENDPOINT = "https://openrouter.ai/api/v1/chat/completions";

/**
 * OpenRouterAdapter — OpenAI-compatible chat completions. Uses the same
 * `json_object` response-format mode as GroqAdapter rather than OpenRouter's
 * model-dependent strict `json_schema` mode (not every routed model supports
 * it); the router's Zod safeParse + retry/fallback validates output exactly
 * like it does for Groq/Qwen today.
 */
export class OpenRouterAdapter implements ProviderAdapter {
  readonly name = "openrouter" as const;

  constructor(private readonly config: ProviderRuntimeConfig) {}

  private headers(): Record<string, string> {
    return {
      "content-type": "application/json",
      authorization: `Bearer ${this.config.apiKey}`,
    };
  }

  async generateObjectRaw(opts: GenerateObjectOptions<unknown>): Promise<{
    raw: unknown;
    citations: Citation[];
    model: string;
  }> {
    const model = opts.model ?? this.config.model;
    const system = `${opts.system}\n\nRespond with a single valid JSON object only. No prose, no markdown fences.`;

    const res = await fetch(ENDPOINT, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify({
        model,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: system },
          { role: "user", content: opts.user },
        ],
      }),
    });
    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      throw new Error(`OpenRouter generateObject failed (${res.status}): ${detail.slice(0, 500)}`);
    }
    const json = (await res.json()) as OpenRouterResponse;
    const content = json.choices?.[0]?.message?.content ?? "";
    if (!content.trim()) throw new Error("OpenRouter returned an empty message.");
    return { raw: JSON.parse(content), citations: [], model };
  }

  async generateText(opts: GenerateTextOptions): Promise<AiTextResult> {
    const model = opts.model ?? this.config.model;
    const res = await fetch(ENDPOINT, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: opts.system },
          { role: "user", content: opts.user },
        ],
      }),
    });
    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      throw new Error(`OpenRouter generateText failed (${res.status}): ${detail.slice(0, 500)}`);
    }
    const json = (await res.json()) as OpenRouterResponse;
    const text = json.choices?.[0]?.message?.content ?? "";
    return { text, provider: "openrouter", model };
  }
}

interface OpenRouterResponse {
  choices?: Array<{ message?: { content?: string } }>;
}
```

Note for whoever executes this task: OpenRouter's exact field names are well-documented and stable (OpenAI-compatible `/chat/completions`), but were not hit live during planning — as part of Step 6's verification, do one real request against `https://openrouter.ai/api/v1/chat/completions` with a real key (if available in this environment) and confirm the response actually has `choices[0].message.content`; adjust `OpenRouterResponse` if it doesn't.

- [ ] **Step 3: Rewrite `router.ts` to be settings-driven (replaces Task 3 Step 5's interim body)**

Replace the entire contents of `packages/ts/ai/src/router.ts` with:

```ts
import type { Env } from "@owlnighter/shared";
import { GeminiAdapter } from "./gemini.js";
import { GroqAdapter } from "./groq.js";
import { OpenRouterAdapter } from "./openrouter.js";
import { AiTutorApiAdapter } from "./aiTutorApi.js";
import type {
  AiObjectResult,
  AiRouter,
  AiTask,
  AiTextResult,
  GenerateObjectOptions,
  GenerateTextOptions,
  ProviderAdapter,
  ProviderName,
  SettingsReader,
} from "./types.js";

/** Only these two tasks may be reassigned via ai_provider.task_override.* —
 * book_grounding/plan_generation keep their hardcoded Gemini-first routing
 * (native Search Grounding and schema-strictness are Gemini-only capabilities
 * today; reassigning those tasks would silently break the honesty guarantees
 * the rest of the app depends on). */
const TASK_OVERRIDABLE: ReadonlySet<AiTask> = new Set(["quiz_generation", "rewrite"]);

function preferredProvider(
  opts: { task: AiTask; requireGrounding?: boolean; requireStrictSchema?: boolean },
  taskOverride: ProviderName | undefined,
): ProviderName {
  if (opts.requireGrounding || opts.requireStrictSchema) return "gemini";
  if (taskOverride && TASK_OVERRIDABLE.has(opts.task)) return taskOverride;
  switch (opts.task) {
    case "book_grounding":
    case "plan_generation":
      return "gemini";
    case "rewrite":
    case "quiz_generation":
      return "groq";
    default:
      return "gemini";
  }
}

export function createAiRouter(env: Env, settings: SettingsReader): AiRouter {
  const gemini = new GeminiAdapter(env);

  async function adapterFor(name: ProviderName): Promise<{ adapter: ProviderAdapter; configured: boolean }> {
    if (name === "gemini") {
      return { adapter: gemini, configured: env.GEMINI_API_KEY.length > 0 };
    }
    const snap = await settings.snapshot();
    if (name === "groq") {
      const apiKey = snap.groq.apiKey || env.GROQ_API_KEY;
      const model = snap.groq.model || env.GROQ_MODEL;
      return { adapter: new GroqAdapter({ apiKey, model }), configured: apiKey.length > 0 };
    }
    if (name === "openrouter") {
      return {
        adapter: new OpenRouterAdapter({ apiKey: snap.openrouter.apiKey, model: snap.openrouter.model }),
        configured: snap.openrouter.apiKey.length > 0 && snap.openrouter.model.length > 0,
      };
    }
    return {
      adapter: new AiTutorApiAdapter({ apiKey: snap.aiTutorApi.apiKey, workflowIds: snap.aiTutorApi.workflowIds }),
      configured: snap.aiTutorApi.apiKey.length > 0,
    };
  }

  /** Whatever the preferred provider is, fall back to Gemini once if it isn't
   * itself Gemini. Generalizes the original 2-provider behavior (a Groq-first
   * call falls back to Gemini; a Gemini-first call never falls back) to 4
   * providers without changing that semantic. */
  function order(pref: ProviderName): ProviderName[] {
    return pref === "gemini" ? ["gemini"] : [pref, "gemini"];
  }

  return {
    async generateObject<T>(opts: GenerateObjectOptions<T>): Promise<AiObjectResult<T>> {
      const snap = await settings.snapshot();
      const override = TASK_OVERRIDABLE.has(opts.task) ? snap.taskOverrides[opts.task] : undefined;
      const pref = preferredProvider(opts, override);

      let attempts = 0;
      let lastError: unknown;
      let triedAny = false;

      for (const providerName of order(pref)) {
        const { adapter, configured } = await adapterFor(providerName);
        if (!configured) continue;
        triedAny = true;
        const maxTriesHere = providerName === pref ? 2 : 1;
        for (let i = 0; i < maxTriesHere; i++) {
          attempts++;
          try {
            const { raw, citations, model } = await adapter.generateObjectRaw(
              opts as GenerateObjectOptions<unknown>,
            );
            const parsed = opts.schema.safeParse(raw);
            if (parsed.success) {
              return { data: parsed.data, provider: providerName, model, citations, attempts };
            }
            lastError = new Error(
              `Schema validation failed for "${opts.schemaName}" on ${providerName}: ` +
                parsed.error.issues.map((x) => x.path.join(".") + " " + x.message).join("; "),
            );
          } catch (err) {
            lastError = err;
          }
        }
      }

      if (!triedAny) {
        throw new Error(
          "No AI provider is configured for this task. Configure a provider's API key in the admin panel's AI Providers page or the environment.",
        );
      }
      throw new Error(
        `generateObject exhausted providers for "${opts.schemaName}". Last error: ` +
          (lastError instanceof Error ? lastError.message : String(lastError)),
      );
    },

    async generateText(opts: GenerateTextOptions): Promise<AiTextResult> {
      const snap = await settings.snapshot();
      const override = TASK_OVERRIDABLE.has(opts.task) ? snap.taskOverrides[opts.task] : undefined;
      const pref = preferredProvider({ task: opts.task }, override);
      for (const name of order(pref)) {
        const { adapter, configured } = await adapterFor(name);
        if (configured) return adapter.generateText(opts);
      }
      throw new Error(
        "No AI provider key configured. Set GEMINI_API_KEY and/or GROQ_API_KEY, or configure a provider in the admin panel.",
      );
    },
  };
}
```

- [ ] **Step 4: Export `OpenRouterAdapter`**

In `packages/ts/ai/src/index.ts`, add `export { OpenRouterAdapter } from "./openrouter.js";` after the `GroqAdapter` export line.

- [ ] **Step 5: Update `router.test.ts` for the new signature + prove the override works**

In `packages/ts/ai/src/router.test.ts`, add `import type { SettingsReader, SettingsSnapshot } from "./types.js";` and add this helper after `fakeEnv`:

```ts
function fakeSettings(overrides: Partial<SettingsSnapshot> = {}): SettingsReader {
  return {
    async snapshot(): Promise<SettingsSnapshot> {
      return {
        groq: { apiKey: "", model: "" },
        openrouter: { apiKey: "", model: "" },
        aiTutorApi: { apiKey: "", workflowIds: {} },
        taskOverrides: {},
        ...overrides,
      };
    },
  };
}
```

Change every `createAiRouter(fakeEnv())` (3 occurrences) to `createAiRouter(fakeEnv(), fakeSettings())`, and `createAiRouter(fakeEnv({ GROQ_API_KEY: "" }))` to `createAiRouter(fakeEnv({ GROQ_API_KEY: "" }), fakeSettings())`. This keeps all 4 tests passing unchanged — with empty settings, groq's effective key/model fall through to `fakeEnv()`'s values exactly as before.

Then append a 5th test:

```ts
test("task override routes quiz_generation to openrouter when configured", async () => {
  // OpenRouter's response shape is OpenAI-compatible, identical to Groq's fixture.
  const restore = scriptFetch([groqBody({ answer: "from-or" })]);
  try {
    const router = createAiRouter(
      fakeEnv({ GROQ_API_KEY: "" }),
      fakeSettings({
        openrouter: { apiKey: "or-key", model: "some/model" },
        taskOverrides: { quiz_generation: "openrouter" },
      }),
    );
    const res = await router.generateObject({
      task: "quiz_generation",
      schemaName: "Schema",
      schema: Schema,
      system: "s",
      user: "u",
    });
    assert.equal(res.provider, "openrouter");
    assert.equal(res.data.answer, "from-or");
  } finally {
    restore();
  }
});
```

- [ ] **Step 6: The API-side settings adapter**

Create `apps/api/src/services/ai-settings.ts`:

```ts
import type { ProviderName, SettingsReader, SettingsSnapshot } from "@owlnighter/ai";
import type { SettingsCache } from "@owlnighter/db";

/** Adapts the API's DB-backed SettingsCache into the shape packages/ts/ai
 * depends on, so the ai package never gains a dependency on packages/ts/db. */
export function createAiSettingsReader(settings: SettingsCache): SettingsReader {
  return {
    async snapshot(): Promise<SettingsSnapshot> {
      const [
        groqApiKey,
        groqModel,
        openrouterApiKey,
        openrouterModel,
        aiTutorApiKey,
        workflowBookGrounding,
        workflowPlanGeneration,
        workflowQuizGeneration,
        quizOverride,
        rewriteOverride,
      ] = await Promise.all([
        settings.get("ai_provider.groq.api_key", ""),
        settings.get("ai_provider.groq.model", ""),
        settings.get("ai_provider.openrouter.api_key", ""),
        settings.get("ai_provider.openrouter.model", ""),
        settings.get("ai_provider.ai_tutor_api.api_key", ""),
        settings.get("ai_provider.ai_tutor_api.workflow_id.book_grounding", ""),
        settings.get("ai_provider.ai_tutor_api.workflow_id.plan_generation", ""),
        settings.get("ai_provider.ai_tutor_api.workflow_id.quiz_generation", ""),
        settings.get<ProviderName | null>("ai_provider.task_override.quiz_generation", null),
        settings.get<ProviderName | null>("ai_provider.task_override.rewrite", null),
      ]);
      return {
        groq: { apiKey: groqApiKey, model: groqModel },
        openrouter: { apiKey: openrouterApiKey, model: openrouterModel },
        aiTutorApi: {
          apiKey: aiTutorApiKey,
          workflowIds: {
            book_grounding: workflowBookGrounding || undefined,
            plan_generation: workflowPlanGeneration || undefined,
            quiz_generation: workflowQuizGeneration || undefined,
          },
        },
        taskOverrides: {
          ...(quizOverride ? { quiz_generation: quizOverride } : {}),
          ...(rewriteOverride ? { rewrite: rewriteOverride } : {}),
        },
      };
    },
  };
}
```

- [ ] **Step 7: Wire it into `deps.ts`**

In `apps/api/src/deps.ts`, add `import { createAiSettingsReader } from "./services/ai-settings.js";`. Change:

```ts
  const ai = createAiRouter(env) as unknown as AiRouter;
```

to:

```ts
  const ai = createAiRouter(env, createAiSettingsReader(settings)) as unknown as AiRouter;
```

(`settings` already exists at this point in `buildDeps()` — Task 9 placed its construction immediately after `db`, which is right before this line.)

- [ ] **Step 8: Typecheck + test**

Run: `pnpm --filter @owlnighter/ai run typecheck` → no errors.
Run: `pnpm --filter @owlnighter/ai run test` → 5 pass.
Run: `pnpm --filter @owlnighter/api run typecheck` → no errors.

- [ ] **Step 9: Commit**

```bash
git add packages/ts/ai/src/types.ts packages/ts/ai/src/openrouter.ts packages/ts/ai/src/router.ts packages/ts/ai/src/index.ts packages/ts/ai/src/router.test.ts apps/api/src/services/ai-settings.ts apps/api/src/deps.ts
git commit -m "feat(ai): settings-driven Groq/OpenRouter routing + OpenRouterAdapter"
```

## Task 11: `AiTutorApiAdapter`

**Goal:** A 4th `ProviderAdapter` that runs a pre-created "workflow" on the user's AI Tutor API (`manage-prompt`) account, per the exact contract confirmed by reading that platform's own source: `POST https://aitutor-api.vercel.app/api/v1/run/{workflowId}` with `Authorization: Bearer <key>`, returning `{success, result: "<json-string>", citations?}`.

**Files:**
- Create: `packages/ts/ai/src/aiTutorApi.ts`
- Create: `packages/ts/ai/src/aiTutorApi.test.ts`
- Modify: `packages/ts/ai/src/index.ts` (export `AiTutorApiAdapter`)

**Acceptance Criteria:**
- [ ] Throws a clear error when no `workflow_id` is configured for the requested task.
- [ ] `generateObjectRaw` `JSON.parse`s the `result` string and returns it as `raw` for the router's existing `schema.safeParse` to validate — a malformed AI Tutor API response fails the same safety net Gemini/Groq/OpenRouter already go through.
- [ ] Citations from the response (if present) map into the shared `Citation` shape.
- [ ] The adapter never sends per-task named template variables — only `{system, user}` — because the workflow's own `template` (Task 16) is a generic `{{system}}\n\n{{user}}` passthrough. This keeps the adapter task-agnostic.

**Verify:** `pnpm --filter @owlnighter/ai run test` → 8 tests pass (5 from `router.test.ts` + 3 new in `aiTutorApi.test.ts`).

**Steps:**

- [ ] **Step 1: The adapter**

Create `packages/ts/ai/src/aiTutorApi.ts`:

```ts
import type {
  AiTextResult,
  AiTutorRuntimeConfig,
  Citation,
  GenerateObjectOptions,
  GenerateTextOptions,
  ProviderAdapter,
} from "./types.js";

const BASE = "https://aitutor-api.vercel.app/api/v1/run";

/**
 * AiTutorApiAdapter — runs a pre-created "workflow" on the caller's AI Tutor
 * API account. Each owlnighter AiTask maps to its own admin-configured
 * workflow_id (ai_provider.ai_tutor_api.workflow_id.* settings). The
 * workflow's `template` is a deliberately generic `{{system}}\n\n{{user}}`
 * passthrough (see docs/ai-tutor-workflows/README.md) — this adapter only
 * ever forwards the same system/user strings every other provider receives,
 * so no per-task variable mapping lives here.
 */
export class AiTutorApiAdapter implements ProviderAdapter {
  readonly name = "ai_tutor_api" as const;

  constructor(private readonly config: AiTutorRuntimeConfig) {}

  private workflowIdFor(task: GenerateObjectOptions<unknown>["task"]): string {
    const id = this.config.workflowIds[task];
    if (!id) {
      throw new Error(
        `AI Tutor API has no workflow_id configured for task "${task}". Set it in the admin panel's AI Providers page.`,
      );
    }
    return id;
  }

  private async run(
    workflowId: string,
    system: string,
    user: string,
  ): Promise<{ result: unknown; citations: Citation[] }> {
    const res = await fetch(`${BASE}/${workflowId}`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${this.config.apiKey}`,
      },
      // The run endpoint uses the request body directly as its template
      // input values (flat object keyed by each input's declared name) —
      // NOT wrapped in an "inputs" envelope. Confirmed against the actual
      // manage-prompt run route source (`inputValues: body`).
      body: JSON.stringify({ system, user }),
    });
    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      throw new Error(`AI Tutor API run failed (${res.status}): ${detail.slice(0, 500)}`);
    }
    const json = (await res.json()) as AiTutorApiResponse;
    if (!json.success) throw new Error("AI Tutor API returned success: false.");
    const citations: Citation[] = (json.citations ?? []).map((c) => ({
      title: c.title ?? c.url ?? "source",
      url: c.url ?? "",
      reason: "Cited by AI Tutor API web search.",
    }));
    return { result: json.result, citations };
  }

  async generateObjectRaw(opts: GenerateObjectOptions<unknown>): Promise<{
    raw: unknown;
    citations: Citation[];
    model: string;
  }> {
    const workflowId = this.workflowIdFor(opts.task);
    const { result, citations } = await this.run(workflowId, opts.system, opts.user);
    if (typeof result !== "string") throw new Error("AI Tutor API result was not a JSON string.");
    return { raw: JSON.parse(result), citations, model: `ai_tutor_api:${workflowId}` };
  }

  async generateText(opts: GenerateTextOptions): Promise<AiTextResult> {
    const workflowId = this.workflowIdFor(opts.task);
    const { result } = await this.run(workflowId, opts.system, opts.user);
    return {
      text: typeof result === "string" ? result : JSON.stringify(result),
      provider: "ai_tutor_api",
      model: `ai_tutor_api:${workflowId}`,
    };
  }
}

interface AiTutorApiResponse {
  success: boolean;
  result: string;
  citations?: Array<{ title?: string; url?: string }>;
}
```

- [ ] **Step 2: Export it**

In `packages/ts/ai/src/index.ts`, add `export { AiTutorApiAdapter } from "./aiTutorApi.js";` after the `OpenRouterAdapter` export.

- [ ] **Step 3: Tests**

Create `packages/ts/ai/src/aiTutorApi.test.ts`:

```ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { AiTutorApiAdapter } from "./aiTutorApi.js";
import type { GenerateObjectOptions } from "./types.js";

function scriptFetch(body: unknown, status = 200): () => void {
  const original = globalThis.fetch;
  globalThis.fetch = (async () =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } })) as typeof fetch;
  return () => {
    globalThis.fetch = original;
  };
}

const baseOpts = { schemaName: "s", schema: undefined as never, system: "sys", user: "usr" };

test("throws when no workflow_id is configured for the task", async () => {
  const adapter = new AiTutorApiAdapter({ apiKey: "k", workflowIds: {} });
  await assert.rejects(
    () => adapter.generateObjectRaw({ task: "quiz_generation", ...baseOpts } as GenerateObjectOptions<unknown>),
    /no workflow_id configured/i,
  );
});

test("generateObjectRaw parses the JSON-string result and maps citations", async () => {
  const restore = scriptFetch({
    success: true,
    result: JSON.stringify({ answer: "ok" }),
    citations: [{ title: "Source A", url: "https://example.com/a" }],
  });
  try {
    const adapter = new AiTutorApiAdapter({ apiKey: "k", workflowIds: { quiz_generation: "wf_123" } });
    const { raw, citations, model } = await adapter.generateObjectRaw({
      task: "quiz_generation",
      ...baseOpts,
    } as GenerateObjectOptions<unknown>);
    assert.deepEqual(raw, { answer: "ok" });
    assert.equal(citations.length, 1);
    assert.equal(citations[0]?.url, "https://example.com/a");
    assert.equal(model, "ai_tutor_api:wf_123");
  } finally {
    restore();
  }
});

test("throws when the API reports success: false", async () => {
  const restore = scriptFetch({ success: false, result: "" });
  try {
    const adapter = new AiTutorApiAdapter({ apiKey: "k", workflowIds: { quiz_generation: "wf_123" } });
    await assert.rejects(() =>
      adapter.generateObjectRaw({ task: "quiz_generation", ...baseOpts } as GenerateObjectOptions<unknown>),
    );
  } finally {
    restore();
  }
});
```

- [ ] **Step 4: Typecheck + test**

Run: `pnpm --filter @owlnighter/ai run typecheck` → no errors.
Run: `pnpm --filter @owlnighter/ai run test` → 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/ts/ai/src/aiTutorApi.ts packages/ts/ai/src/aiTutorApi.test.ts packages/ts/ai/src/index.ts
git commit -m "feat(ai): AI Tutor API provider adapter"
```

## Task 12: Live model catalog endpoint (Groq + OpenRouter)

**Goal:** `GET /v1/admin/ai/models?provider=groq|openrouter` returns a normalized, sorted model list — Groq's list requires the configured Groq key server-side; OpenRouter's is publicly readable.

**Files:**
- Create: `apps/api/src/services/ai-models.ts`
- Create: `apps/api/src/services/ai-models.test.ts`
- Modify: `apps/api/src/routes/settings.ts` (wire `adminGetAiModels`)

**Acceptance Criteria:**
- [ ] `?provider=` anything other than `groq`/`openrouter` → 400.
- [ ] Groq catalog request uses the admin-configured key (falling back to `GROQ_API_KEY`) and 503s with a clear message if neither is set.
- [ ] OpenRouter catalog request needs no key.
- [ ] Both lists are normalized to `{id, name, contextLength?, pricing?, modality?}` and sorted by `id`.

**Verify:** `node --import tsx --test "apps/api/src/services/ai-models.test.ts"` → all pass. Live smoke test (only if real keys are available in this environment): `curl -H "authorization: Bearer <admin token>" "http://localhost:8787/v1/admin/ai/models?provider=openrouter"` returns a non-empty `models` array — OpenRouter needs no key, so this should work in any environment with internet access.

**Steps:**

- [ ] **Step 1: The service**

Create `apps/api/src/services/ai-models.ts`:

```ts
import type { AdminAiModelsResponse, AiModelInfo } from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { badRequest, unavailable } from "../plugins/errors.js";

interface GroqModelsResponse {
  data?: Array<{ id: string; context_window?: number }>;
}
interface OpenRouterModelsResponse {
  data?: Array<{
    id: string;
    name?: string;
    context_length?: number;
    pricing?: { prompt?: string; completion?: string };
    architecture?: { modality?: string };
  }>;
}

async function fetchGroqModels(apiKey: string): Promise<AiModelInfo[]> {
  if (!apiKey) throw unavailable("Groq model catalog unavailable: no Groq API key is configured.");
  const res = await fetch("https://api.groq.com/openai/v1/models", {
    headers: { authorization: `Bearer ${apiKey}` },
  });
  if (!res.ok) {
    const detail = await res.text().catch(() => "");
    throw unavailable(`Groq model catalog request failed (${res.status}): ${detail.slice(0, 300)}`);
  }
  const json = (await res.json()) as GroqModelsResponse;
  return (json.data ?? [])
    .map((m) => ({ id: m.id, name: m.id, contextLength: m.context_window }))
    .sort((a, b) => a.id.localeCompare(b.id));
}

async function fetchOpenRouterModels(): Promise<AiModelInfo[]> {
  const res = await fetch("https://openrouter.ai/api/v1/models");
  if (!res.ok) {
    const detail = await res.text().catch(() => "");
    throw unavailable(`OpenRouter model catalog request failed (${res.status}): ${detail.slice(0, 300)}`);
  }
  const json = (await res.json()) as OpenRouterModelsResponse;
  return (json.data ?? [])
    .map((m) => ({
      id: m.id,
      name: m.name ?? m.id,
      ...(m.context_length != null ? { contextLength: m.context_length } : {}),
      ...(m.pricing ? { pricing: { prompt: m.pricing.prompt, completion: m.pricing.completion } } : {}),
      ...(m.architecture?.modality ? { modality: m.architecture.modality } : {}),
    }))
    .sort((a, b) => a.id.localeCompare(b.id));
}

export async function getAiModels(deps: Deps, provider: string | undefined): Promise<AdminAiModelsResponse> {
  if (provider !== "groq" && provider !== "openrouter") {
    throw badRequest('Query param "provider" must be "groq" or "openrouter".');
  }
  if (provider === "groq") {
    const apiKey = (await deps.settings.get("ai_provider.groq.api_key", "")) || deps.config.env.GROQ_API_KEY;
    return { provider, models: await fetchGroqModels(apiKey) };
  }
  return { provider, models: await fetchOpenRouterModels() };
}
```

Note for whoever executes this task: both response shapes are well-documented, stable, OpenAI-compatible-style `/models` endpoints, but were not hit live during planning — as part of Step 4's verification, do a real request against both (Groq needs a real key) and confirm field names; adjust the two response interfaces if they differ.

- [ ] **Step 2: Wire the route**

In `apps/api/src/routes/settings.ts`, add `AdminAiModelsResponse` to the `@owlnighter/contracts` import, add `import { getAiModels } from "../services/ai-models.js";`, add `requireAdminAccount` to the existing `../plugins/admin-session.js` import, and append inside `registerSettingsRoutes`:

```ts
  register<never, AdminAiModelsResponse>(app, deps, "adminGetAiModels", async ({ req }) => {
    requireAdminAccount(req);
    const provider = (req.query as Record<string, string> | undefined)?.["provider"];
    return getAiModels(deps, provider);
  });
```

- [ ] **Step 3: Tests**

Create `apps/api/src/services/ai-models.test.ts`:

```ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { getAiModels } from "./ai-models.js";
import { fakeDeps, fakeSettings } from "../test/helpers.js";

function scriptFetch(body: unknown, status = 200): () => void {
  const original = globalThis.fetch;
  globalThis.fetch = (async () =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } })) as typeof fetch;
  return () => {
    globalThis.fetch = original;
  };
}

test("rejects an unknown provider", async () => {
  await assert.rejects(() => getAiModels(fakeDeps(), "not-a-provider"));
});

test("fetches and normalizes Groq models, sorted by id", async () => {
  const restore = scriptFetch({
    data: [
      { id: "z-model", context_window: 8192 },
      { id: "a-model", context_window: 4096 },
    ],
  });
  try {
    const deps = fakeDeps({ settings: fakeSettings({ rows: [{ key: "ai_provider.groq.api_key", value: "gk" }] }) });
    const result = await getAiModels(deps, "groq");
    assert.equal(result.provider, "groq");
    assert.equal(result.models.length, 2);
    assert.equal(result.models[0]?.id, "a-model");
  } finally {
    restore();
  }
});

test("groq catalog is unavailable with no key configured", async () => {
  const deps = fakeDeps({ env: { GROQ_API_KEY: "" }, settings: fakeSettings() });
  await assert.rejects(() => getAiModels(deps, "groq"));
});

test("fetches and normalizes OpenRouter models", async () => {
  const restore = scriptFetch({
    data: [
      {
        id: "vendor/model-1",
        name: "Model One",
        context_length: 128000,
        pricing: { prompt: "0.001", completion: "0.002" },
        architecture: { modality: "text->text" },
      },
    ],
  });
  try {
    const result = await getAiModels(fakeDeps(), "openrouter");
    assert.equal(result.provider, "openrouter");
    assert.equal(result.models[0]?.name, "Model One");
    assert.equal(result.models[0]?.modality, "text->text");
  } finally {
    restore();
  }
});
```

- [ ] **Step 4: Typecheck + test**

Run: `pnpm --filter @owlnighter/api run typecheck` → no errors.
Run: `node --import tsx --test "apps/api/src/services/ai-models.test.ts"` → 4 pass.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/services/ai-models.ts apps/api/src/services/ai-models.test.ts apps/api/src/routes/settings.ts
git commit -m "feat(api): live Groq/OpenRouter model catalog endpoint"
```

## Task 13: Admin panel — real auth (login/signup/accounts) + cookie wiring

**Goal:** The admin console gets a real login/signup/approval flow. Fastify's admin-panel auth stays purely Bearer-token based (Task 6); Next.js owns the actual browser cookie via Server Actions (`next/headers`'s `cookies()`), and `lib/api.ts` forwards that token as `Authorization: Bearer <token>` on every `admin: true` call — this sidesteps the cross-origin-cookie problem entirely (a cookie set by `localhost:8787` is never visible to a `localhost:3001` page) without needing `@fastify/cookie` or any new npm dependency.

**Files:**
- Create: `apps/admin/lib/session-constants.ts`
- Create: `apps/admin/lib/session.ts`
- Create: `apps/admin/lib/auth-actions.ts`
- Modify: `apps/admin/lib/api.ts` (cookie-aware `request()`; add admin-auth/settings/models types + methods)
- Create: `apps/admin/middleware.ts`
- Modify: `apps/admin/components/Sidebar.tsx` (hide on `/login`/`/signup`; add Settings/AI Providers/Admin Accounts nav entries + logout button)
- Create: `apps/admin/app/login/page.tsx`
- Create: `apps/admin/app/login/actions.ts`
- Create: `apps/admin/app/signup/page.tsx`
- Create: `apps/admin/app/signup/actions.ts`
- Create: `apps/admin/app/accounts/page.tsx`
- Create: `apps/admin/app/accounts/actions.ts`

**Acceptance Criteria:**
- [ ] Visiting any admin route with no session cookie redirects to `/login` (middleware), except `/login`/`/signup` themselves.
- [ ] `/login` and `/signup` render without the sidebar.
- [ ] Logging in as a seeded admin sets an httpOnly cookie and lands on `/`.
- [ ] `/accounts` lists pending signups with working Approve/Reject buttons.
- [ ] "Log out" clears the cookie and returns to `/login`.
- [ ] Every existing `admin: true` call in `lib/api.ts` (metrics, grounding, tts, quiz, plans, push-test) now sends a real `Authorization: Bearer` header sourced from the cookie, with zero changes needed to the existing page files that call them.

**Verify:** `pnpm dev:api` + `pnpm dev:admin`, then manually: visit `http://localhost:3001/` while logged out → redirected to `/login`; log in as `afarhadi@mytsi.org` / `REDACTED_PASSWORD` (seeded in Task 8) → lands on Overview with real data; visit `/accounts`, submit a signup for a second `@mytsi.org` email at `/signup` in an incognito window, approve it from `/accounts`, confirm the new account can then log in.

**Steps:**

- [ ] **Step 1: Cookie constant + session helpers**

Create `apps/admin/lib/session-constants.ts` (kept import-free so `middleware.ts` can use it without pulling in `next/headers`):

```ts
export const ADMIN_COOKIE_NAME = "owlnighter_admin_token";
```

Create `apps/admin/lib/session.ts`:

```ts
import { cookies } from "next/headers";
import { ADMIN_COOKIE_NAME } from "./session-constants";

export { ADMIN_COOKIE_NAME };

const THIRTY_DAYS_SECONDS = 60 * 60 * 24 * 30;

/** Read the admin session token from the incoming request's cookie. Valid in
 * Server Components, Route Handlers, and Server Actions. */
export async function getAdminToken(): Promise<string | undefined> {
  const store = await cookies();
  return store.get(ADMIN_COOKIE_NAME)?.value;
}

/** Set the httpOnly admin session cookie. Only callable from a Server Action
 * or Route Handler — Next.js forbids cookie writes during plain render. */
export async function setAdminToken(token: string): Promise<void> {
  const store = await cookies();
  store.set(ADMIN_COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: THIRTY_DAYS_SECONDS,
  });
}

export async function clearAdminToken(): Promise<void> {
  const store = await cookies();
  store.delete(ADMIN_COOKIE_NAME);
}
```

- [ ] **Step 2: Cookie-aware `request()` + new API surface**

In `apps/admin/lib/api.ts`, add `import { getAdminToken } from "./session";` near the top, and replace:

```ts
async function request<T>(
  path: string,
  init?: RequestInit & { admin?: boolean },
): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers: {
      "content-type": "application/json",
      // TODO wire real admin auth: forward a Supabase JWT / service token here.
      ...(init?.admin ? { "x-admin": "1" } : {}),
      ...init?.headers,
    },
    cache: "no-store",
  });
```

with:

```ts
async function request<T>(
  path: string,
  init?: RequestInit & { admin?: boolean },
): Promise<T> {
  const authHeader: Record<string, string> = {};
  if (init?.admin) {
    const token = await getAdminToken();
    if (token) authHeader["authorization"] = `Bearer ${token}`;
  }
  const res = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers: {
      "content-type": "application/json",
      ...authHeader,
      ...init?.headers,
    },
    cache: "no-store",
  });
```

(No other line in the function changes — the `!res.ok` handling and return stay exactly as-is.)

Then add these type + `api` method additions (append the interfaces near the other `// ---- admin ... ----` sections, and the methods inside the `api` object, alongside the existing ones):

```ts
// ---- admin-panel auth ----
export interface AdminSignupRequest {
  email: string;
  password: string;
}
export interface AdminSignupResponse {
  status: "pending";
  message: string;
}
export interface AdminLoginRequest {
  email: string;
  password: string;
}
export interface AdminLoginResponse {
  token: string;
  expiresAt: string;
  account: { id: string; email: string };
}
export interface AdminMeResponse {
  id: string;
  email: string;
  isAdmin: boolean;
}
export type AdminAccountStatus = "pending" | "approved" | "rejected";
export interface AdminPendingAccount {
  [key: string]: unknown;
  id: string;
  email: string;
  status: AdminAccountStatus;
  createdAt: string;
}
export interface AdminPendingAccountsResponse {
  accounts: AdminPendingAccount[];
}
export interface AdminAccountActionResponse {
  id: string;
  status: "approved" | "rejected";
}

// ---- settings ----
export interface AdminSettingRow {
  [key: string]: unknown;
  key: string;
  value: unknown;
  isSecret: boolean;
  configured?: boolean;
  hint?: string;
  updatedAt: string;
}
export interface AdminSettingsResponse {
  settings: AdminSettingRow[];
}
export interface AdminUpdateSettingResponse {
  key: string;
  updatedAt: string;
}

// ---- AI model catalog ----
export interface AiModelInfo {
  [key: string]: unknown;
  id: string;
  name: string;
  contextLength?: number;
  pricing?: { prompt?: string; completion?: string };
  modality?: string;
}
export interface AdminAiModelsResponse {
  provider: "groq" | "openrouter";
  models: AiModelInfo[];
}
```

```ts
  adminSignup(body: AdminSignupRequest) {
    return request<AdminSignupResponse>("/v1/admin/auth/signup", {
      method: "POST",
      body: JSON.stringify(body),
    });
  },

  adminLogin(body: AdminLoginRequest) {
    return request<AdminLoginResponse>("/v1/admin/auth/login", {
      method: "POST",
      body: JSON.stringify(body),
    });
  },

  adminLogout() {
    return request<void>("/v1/admin/auth/logout", { method: "POST", admin: true });
  },

  adminMe() {
    return request<AdminMeResponse>("/v1/admin/auth/me", { admin: true });
  },

  adminListPendingAccounts() {
    return request<AdminPendingAccountsResponse>("/v1/admin/accounts/pending", { admin: true });
  },

  adminApproveAccount(id: string) {
    return request<AdminAccountActionResponse>(
      `/v1/admin/accounts/${encodeURIComponent(id)}/approve`,
      { method: "POST", admin: true },
    );
  },

  adminRejectAccount(id: string) {
    return request<AdminAccountActionResponse>(
      `/v1/admin/accounts/${encodeURIComponent(id)}/reject`,
      { method: "POST", admin: true },
    );
  },

  adminGetSettings() {
    return request<AdminSettingsResponse>("/v1/admin/settings", { admin: true });
  },

  adminPutSetting(key: string, value: unknown) {
    return request<AdminUpdateSettingResponse>(`/v1/admin/settings/${encodeURIComponent(key)}`, {
      method: "PUT",
      admin: true,
      body: JSON.stringify({ value }),
    });
  },

  adminGetAiModels(provider: "groq" | "openrouter") {
    return request<AdminAiModelsResponse>(`/v1/admin/ai/models?provider=${provider}`, { admin: true });
  },
```

- [ ] **Step 3: Middleware gate**

Create `apps/admin/middleware.ts`:

```ts
import { NextRequest, NextResponse } from "next/server";
import { ADMIN_COOKIE_NAME } from "./lib/session-constants";

const PUBLIC_PATHS = new Set(["/login", "/signup"]);

/** Presence-only check — is a session cookie attached at all? Full validity
 * (expired/revoked) is enforced by every page's own admin_panel-guarded API
 * call, which already 401s and renders an inline error today; this middleware
 * only needs to keep an unauthenticated visitor out of the sidebar/pages. */
export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  if (PUBLIC_PATHS.has(pathname)) return NextResponse.next();

  const token = req.cookies.get(ADMIN_COOKIE_NAME)?.value;
  if (!token) return NextResponse.redirect(new URL("/login", req.url));
  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
```

- [ ] **Step 4: Logout action (shared) + login/signup pages**

Create `apps/admin/lib/auth-actions.ts`:

```ts
"use server";
import { redirect } from "next/navigation";
import { api } from "./api";
import { clearAdminToken } from "./session";

export async function logoutAction(): Promise<void> {
  try {
    await api.adminLogout();
  } catch {
    // Session may already be invalid/expired server-side; clear the cookie regardless.
  }
  await clearAdminToken();
  redirect("/login");
}
```

Create `apps/admin/app/login/actions.ts`:

```ts
"use server";
import { redirect } from "next/navigation";
import { api, ApiRequestError } from "@/lib/api";
import { setAdminToken } from "@/lib/session";

export interface LoginActionState {
  error?: string;
}

export async function loginAction(
  _prevState: LoginActionState,
  formData: FormData,
): Promise<LoginActionState> {
  const email = String(formData.get("email") ?? "");
  const password = String(formData.get("password") ?? "");
  try {
    const res = await api.adminLogin({ email, password });
    await setAdminToken(res.token);
  } catch (err) {
    if (err instanceof ApiRequestError) return { error: err.body?.error.message ?? "Login failed." };
    return { error: "Login failed." };
  }
  redirect("/");
}
```

Create `apps/admin/app/login/page.tsx`:

```tsx
"use client";
import { useActionState } from "react";
import { loginAction, type LoginActionState } from "./actions";

const initialState: LoginActionState = {};

export default function LoginPage() {
  const [state, formAction, pending] = useActionState(loginAction, initialState);

  return (
    <div className="flex min-h-screen items-center justify-center">
      <form action={formAction} className="w-full max-w-sm space-y-4 rounded-md border border-line bg-ink-800 p-6">
        <h1 className="font-mono text-lg font-semibold text-slate-100">owlnighter admin</h1>
        {state.error ? (
          <div className="rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">{state.error}</div>
        ) : null}
        <label className="block text-sm text-muted">
          Email
          <input
            name="email"
            type="email"
            required
            className="mt-1 w-full rounded border border-line bg-ink-700 px-3 py-2 text-slate-100"
          />
        </label>
        <label className="block text-sm text-muted">
          Password
          <input
            name="password"
            type="password"
            required
            className="mt-1 w-full rounded border border-line bg-ink-700 px-3 py-2 text-slate-100"
          />
        </label>
        <button
          type="submit"
          disabled={pending}
          className="w-full rounded bg-accent px-3 py-2 text-sm font-semibold text-ink-900 disabled:opacity-50"
        >
          {pending ? "Logging in..." : "Log in"}
        </button>
        <a href="/signup" className="block text-center text-sm text-accent">
          Request access
        </a>
      </form>
    </div>
  );
}
```

Create `apps/admin/app/signup/actions.ts`:

```ts
"use server";
import { api, ApiRequestError } from "@/lib/api";

export interface SignupActionState {
  error?: string;
  success?: boolean;
}

export async function signupAction(
  _prevState: SignupActionState,
  formData: FormData,
): Promise<SignupActionState> {
  const email = String(formData.get("email") ?? "");
  const password = String(formData.get("password") ?? "");
  try {
    await api.adminSignup({ email, password });
    return { success: true };
  } catch (err) {
    if (err instanceof ApiRequestError) return { error: err.body?.error.message ?? "Signup failed." };
    return { error: "Signup failed." };
  }
}
```

Create `apps/admin/app/signup/page.tsx`:

```tsx
"use client";
import { useActionState } from "react";
import { signupAction, type SignupActionState } from "./actions";

const initialState: SignupActionState = {};

export default function SignupPage() {
  const [state, formAction, pending] = useActionState(signupAction, initialState);

  if (state.success) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="w-full max-w-sm rounded-md border border-line bg-ink-800 p-6 text-center">
          <h1 className="font-mono text-lg font-semibold text-slate-100">Request submitted</h1>
          <p className="mt-2 text-sm text-muted">
            An existing admin needs to approve this account before you can log in.
          </p>
          <a href="/login" className="mt-4 inline-block text-sm text-accent">
            Back to login
          </a>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen items-center justify-center">
      <form action={formAction} className="w-full max-w-sm space-y-4 rounded-md border border-line bg-ink-800 p-6">
        <h1 className="font-mono text-lg font-semibold text-slate-100">Request admin access</h1>
        <p className="text-sm text-muted">Only @mytsi.org email addresses may request access.</p>
        {state.error ? (
          <div className="rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">{state.error}</div>
        ) : null}
        <label className="block text-sm text-muted">
          Email
          <input
            name="email"
            type="email"
            required
            placeholder="you@mytsi.org"
            className="mt-1 w-full rounded border border-line bg-ink-700 px-3 py-2 text-slate-100"
          />
        </label>
        <label className="block text-sm text-muted">
          Password
          <input
            name="password"
            type="password"
            required
            minLength={8}
            className="mt-1 w-full rounded border border-line bg-ink-700 px-3 py-2 text-slate-100"
          />
        </label>
        <button
          type="submit"
          disabled={pending}
          className="w-full rounded bg-accent px-3 py-2 text-sm font-semibold text-ink-900 disabled:opacity-50"
        >
          {pending ? "Submitting..." : "Request access"}
        </button>
        <a href="/login" className="block text-center text-sm text-accent">
          Back to login
        </a>
      </form>
    </div>
  );
}
```

- [ ] **Step 5: Accounts page**

Create `apps/admin/app/accounts/actions.ts`:

```ts
"use server";
import { revalidatePath } from "next/cache";
import { api } from "@/lib/api";

export async function approveAccountAction(id: string): Promise<void> {
  await api.adminApproveAccount(id);
  revalidatePath("/accounts");
}

export async function rejectAccountAction(id: string): Promise<void> {
  await api.adminRejectAccount(id);
  revalidatePath("/accounts");
}
```

Create `apps/admin/app/accounts/page.tsx`:

```tsx
import { api, ApiRequestError } from "@/lib/api";
import type { AdminPendingAccount } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { DataTable } from "@/components/DataTable";
import { Badge } from "@/components/Badge";
import { approveAccountAction, rejectAccountAction } from "./actions";

export default async function AccountsPage() {
  let accounts: AdminPendingAccount[] = [];
  let error: string | null = null;
  try {
    const res = await api.adminListPendingAccounts();
    accounts = res.accounts;
  } catch (err) {
    error =
      err instanceof ApiRequestError
        ? `${err.status}: ${err.body?.error.message ?? err.message}`
        : (err as Error).message;
  }

  return (
    <div>
      <PageHeader title="Admin Accounts" subtitle="Pending @mytsi.org signup requests awaiting approval." />
      {error ? (
        <div className="mb-4 rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">{error}</div>
      ) : null}
      <DataTable<AdminPendingAccount>
        rowKey={(r) => r.id}
        rows={accounts}
        empty="No pending requests."
        columns={[
          { key: "email", header: "Email" },
          { key: "status", header: "Status", render: (r) => <Badge tone="warn">{r.status}</Badge> },
          { key: "createdAt", header: "Requested" },
          {
            key: "actions",
            header: "Actions",
            render: (r) => (
              <div className="flex gap-2">
                <form action={approveAccountAction.bind(null, r.id)}>
                  <button
                    type="submit"
                    className="rounded border border-good/40 bg-good/10 px-2 py-1 text-xs text-good"
                  >
                    Approve
                  </button>
                </form>
                <form action={rejectAccountAction.bind(null, r.id)}>
                  <button type="submit" className="rounded border border-bad/40 bg-bad/10 px-2 py-1 text-xs text-bad">
                    Reject
                  </button>
                </form>
              </div>
            ),
          },
        ]}
      />
    </div>
  );
}
```

- [ ] **Step 6: Sidebar — hide on auth pages, add new nav entries, add logout**

In `apps/admin/components/Sidebar.tsx`, add `import { logoutAction } from "@/lib/auth-actions";`, extend the `NAV` array (append after the `model-ops` entry):

```ts
  { href: "/settings", label: "Settings", hint: "limits · flags · catalog" },
  { href: "/ai-providers", label: "AI Providers", hint: "keys · models · prompts" },
  { href: "/accounts", label: "Admin Accounts", hint: "pending approvals" },
```

add `if (pathname === "/login" || pathname === "/signup") return null;` as the first line of the `Sidebar()` function body (right after the `useEffect`/`toggleMuted` definitions, before the `return (`), and add a logout form to the footer — change:

```tsx
      <div className="border-t border-line px-4 py-3 text-[11px] text-muted">
        <div className="flex items-center justify-between gap-2">
          <span className="truncate">
            env: {process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8787"}
          </span>
          <button
            type="button"
            onClick={toggleMuted}
            aria-pressed={muted}
            title={muted ? "Sound off — click to enable chimes" : "Sound on — click to mute"}
            className="shrink-0 rounded border border-line px-1.5 py-0.5 text-[11px] text-muted transition-colors hover:border-accent hover:text-accent"
          >
            {muted ? "🔇" : "🔔"}
          </button>
        </div>
      </div>
```

to:

```tsx
      <div className="border-t border-line px-4 py-3 text-[11px] text-muted">
        <div className="flex items-center justify-between gap-2">
          <span className="truncate">
            env: {process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8787"}
          </span>
          <button
            type="button"
            onClick={toggleMuted}
            aria-pressed={muted}
            title={muted ? "Sound off — click to enable chimes" : "Sound on — click to mute"}
            className="shrink-0 rounded border border-line px-1.5 py-0.5 text-[11px] text-muted transition-colors hover:border-accent hover:text-accent"
          >
            {muted ? "🔇" : "🔔"}
          </button>
        </div>
        <form action={logoutAction} className="mt-2">
          <button
            type="submit"
            className="w-full rounded border border-line px-2 py-1 text-[11px] text-muted transition-colors hover:border-bad hover:text-bad"
          >
            Log out
          </button>
        </form>
      </div>
```

- [ ] **Step 7: Typecheck**

Run: `pnpm --filter @owlnighter/admin exec tsc --noEmit` → no errors (confirmed: `apps/admin/package.json` has no `typecheck` script, only `dev/build/start/lint`, so this invokes the local TypeScript devDependency directly).

- [ ] **Step 8: Commit**

```bash
git add apps/admin/lib/session-constants.ts apps/admin/lib/session.ts apps/admin/lib/auth-actions.ts apps/admin/lib/api.ts apps/admin/middleware.ts apps/admin/components/Sidebar.tsx apps/admin/app/login apps/admin/app/signup apps/admin/app/accounts
git commit -m "feat(admin): real login/signup/approval flow with cookie-backed sessions"
```

## Task 14: Admin panel — Settings page

**Goal:** A `/settings` page groups every non-provider-specific setting into cards (Limits, Feature Flags, Grounding thresholds, Catalog, AI Models), each field independently editable and saved via a Server Action. Secret fields render password-style and are only overwritten when the admin actually types a new value (a blank submit leaves the stored secret untouched).

**Files:**
- Create: `apps/admin/app/settings/actions.ts`
- Create: `apps/admin/app/settings/SettingField.tsx`
- Create: `apps/admin/app/settings/page.tsx`

**Acceptance Criteria:**
- [ ] Every non-`ai_provider.*` key from Task 5's `SETTINGS_SCHEMA` is editable somewhere on this page (AI-provider keys belong to `/ai-providers`, Task 15).
- [ ] Saving a field round-trips through `PUT /v1/admin/settings/:key` and shows a "saved" or error indicator without a full page reload (client-side `useActionState`, server-rendered data via `revalidatePath`).
- [ ] Submitting a blank value for a secret field does not overwrite the stored secret.

**Verify:** With `pnpm dev:api` + `pnpm dev:admin` running and logged in, visit `/settings`, change `max_books_per_user` to `5`, click Save, reload the page, and confirm the field still shows `5`.

**Steps:**

- [ ] **Step 1: The save action**

Create `apps/admin/app/settings/actions.ts`:

```ts
"use server";
import { revalidatePath } from "next/cache";
import { api, ApiRequestError } from "@/lib/api";

export interface UpdateSettingState {
  error?: string;
  success?: boolean;
}

export async function updateSettingAction(
  key: string,
  _prevState: UpdateSettingState,
  formData: FormData,
): Promise<UpdateSettingState> {
  const raw = formData.get("value");
  const type = String(formData.get("__type") ?? "string");

  // A blank secret submission means "leave unchanged" — never overwrite a
  // configured credential with an accidental empty value.
  if (type === "secret" && (!raw || String(raw).length === 0)) {
    return { success: true };
  }

  let value: unknown;
  if (type === "number") value = Number(raw);
  else if (type === "boolean") value = raw === "true";
  else value = String(raw ?? "");

  try {
    await api.adminPutSetting(key, value);
  } catch (err) {
    if (err instanceof ApiRequestError) return { error: err.body?.error.message ?? "Update failed." };
    return { error: "Update failed." };
  }
  revalidatePath("/settings");
  return { success: true };
}
```

- [ ] **Step 2: The per-field editor**

Create `apps/admin/app/settings/SettingField.tsx`:

```tsx
"use client";
import { useActionState } from "react";
import { updateSettingAction, type UpdateSettingState } from "./actions";

const initialState: UpdateSettingState = {};

export function SettingField({
  settingKey,
  label,
  type,
  initialValue,
  configured,
}: {
  settingKey: string;
  label: string;
  type: "string" | "number" | "boolean" | "secret";
  initialValue: unknown;
  configured?: boolean;
}) {
  const boundAction = updateSettingAction.bind(null, settingKey);
  const [state, formAction, pending] = useActionState(boundAction, initialState);

  return (
    <form action={formAction} className="flex items-center gap-3 border-b border-line py-2 last:border-b-0">
      <input type="hidden" name="__type" value={type} />
      <label className="w-64 shrink-0 text-sm text-muted">{label}</label>
      {type === "boolean" ? (
        <select
          name="value"
          defaultValue={String(initialValue)}
          className="rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
        >
          <option value="true">true</option>
          <option value="false">false</option>
        </select>
      ) : type === "secret" ? (
        <input
          name="value"
          type="password"
          placeholder={configured ? "•••• configured — enter a new value to replace" : "not set"}
          className="flex-1 rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
        />
      ) : (
        <input
          name="value"
          type={type === "number" ? "number" : "text"}
          step={type === "number" ? "any" : undefined}
          defaultValue={type === "number" ? Number(initialValue) : String(initialValue ?? "")}
          className="flex-1 rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
        />
      )}
      <button
        type="submit"
        disabled={pending}
        className="shrink-0 rounded border border-accent/40 bg-accent/10 px-2 py-1 text-xs text-accent disabled:opacity-50"
      >
        {pending ? "Saving..." : "Save"}
      </button>
      {state.success ? <span className="text-xs text-good">saved</span> : null}
      {state.error ? <span className="text-xs text-bad">{state.error}</span> : null}
    </form>
  );
}
```

- [ ] **Step 3: The page**

Create `apps/admin/app/settings/page.tsx`:

```tsx
import { api, ApiRequestError } from "@/lib/api";
import type { AdminSettingRow } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { SettingField } from "./SettingField";

const GROUPS: Array<{
  title: string;
  fields: Array<{ key: string; label: string; type: "string" | "number" | "boolean" | "secret" }>;
}> = [
  { title: "Limits", fields: [{ key: "max_books_per_user", label: "Max books per user", type: "number" }] },
  {
    title: "Feature Flags",
    fields: [
      { key: "flag.groq_quiz_generation", label: "Groq quiz generation", type: "boolean" },
      { key: "flag.tts_pregeneration", label: "TTS pre-generation", type: "boolean" },
      { key: "flag.grounding_review_queue", label: "Grounding review queue", type: "boolean" },
    ],
  },
  {
    title: "Grounding thresholds",
    fields: [
      { key: "grounding.auto_accept", label: "Auto-accept confidence", type: "number" },
      { key: "grounding.review_floor", label: "Review floor confidence", type: "number" },
    ],
  },
  {
    title: "Catalog",
    fields: [
      { key: "catalog.open_library_base_url", label: "Open Library base URL", type: "string" },
      { key: "catalog.google_books_api_key", label: "Google Books API key", type: "secret" },
    ],
  },
  {
    title: "AI Models (non-provider defaults)",
    fields: [
      { key: "ai.gemini.model", label: "Gemini model", type: "string" },
      { key: "ai.deepgram.tts_model", label: "Deepgram TTS model", type: "string" },
    ],
  },
];

export default async function SettingsPage() {
  let rows: AdminSettingRow[] = [];
  let error: string | null = null;
  try {
    const res = await api.adminGetSettings();
    rows = res.settings;
  } catch (err) {
    error =
      err instanceof ApiRequestError
        ? `${err.status}: ${err.body?.error.message ?? err.message}`
        : (err as Error).message;
  }
  const byKey = new Map(rows.map((r) => [r.key, r]));

  return (
    <div>
      <PageHeader
        title="Settings"
        subtitle="Admin-editable config, backed by app_settings. Env vars are only the seed defaults now."
      />
      {error ? (
        <div className="mb-4 rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">{error}</div>
      ) : null}
      {GROUPS.map((group) => (
        <div key={group.title} className="mb-6 rounded-md border border-line bg-ink-800 p-4">
          <h2 className="mb-2 font-mono text-sm font-semibold text-slate-200">{group.title}</h2>
          {group.fields.map((f) => {
            const row = byKey.get(f.key);
            return (
              <SettingField
                key={f.key}
                settingKey={f.key}
                label={f.label}
                type={f.type}
                initialValue={row?.value}
                configured={row?.configured}
              />
            );
          })}
        </div>
      ))}
    </div>
  );
}
```

- [ ] **Step 4: Typecheck**

Run: `pnpm --filter @owlnighter/admin exec tsc --noEmit` → no errors.

- [ ] **Step 5: Commit**

```bash
git add apps/admin/app/settings
git commit -m "feat(admin): settings page with per-field save actions"
```

## Task 15: Admin panel — AI Providers page

**Goal:** A `/ai-providers` page with one card per provider (Groq, OpenRouter, AI Tutor API), each editable and independently saveable; Groq/OpenRouter cards get a "Fetch models" button that pulls the live catalog into a sortable, filterable table; a top card controls the UI-default provider and the two safe task overrides (quiz generation, rewrite).

**Files:**
- Create: `apps/admin/app/ai-providers/actions.ts`
- Create: `apps/admin/app/ai-providers/ProviderCard.tsx`
- Create: `apps/admin/app/ai-providers/ModelCatalogTable.tsx`
- Create: `apps/admin/app/ai-providers/DefaultProviderCard.tsx`
- Create: `apps/admin/app/ai-providers/page.tsx`

**Acceptance Criteria:**
- [ ] Each provider card saves only its own fields; a blank `api_key` submission leaves the stored secret unchanged.
- [ ] "Fetch models" on the Groq/OpenRouter cards populates a table sortable by model id or context length, filterable by a modality text filter (defaults to showing everything, matching on `text` catching the common LLM modality strings).
- [ ] The default-provider/task-override card explicitly states that book grounding and plan generation are never affected by the override, only quiz generation and rewrite.
- [ ] AI Tutor API's card has no system-prompt field (only API key + 3 workflow IDs), matching the platform's actual template-on-their-side model.

**Verify:** With `pnpm dev:api` + `pnpm dev:admin` running and logged in, visit `/ai-providers`, click "Fetch models" under OpenRouter (needs no key) and confirm a populated, sortable table appears; if a real Groq key is present in this environment, do the same under Groq.

**Steps:**

- [ ] **Step 1: Server Actions**

Create `apps/admin/app/ai-providers/actions.ts`:

```ts
"use server";
import { revalidatePath } from "next/cache";
import { api, ApiRequestError } from "@/lib/api";
import type { AiModelInfo } from "@/lib/api";

export async function fetchModelsAction(provider: "groq" | "openrouter"): Promise<AiModelInfo[]> {
  const res = await api.adminGetAiModels(provider);
  return res.models;
}

export interface SaveProviderState {
  error?: string;
  success?: boolean;
}

/** Saves every field in a provider card in one submit (several settings keys
 * at once). A blank `*.api_key` field is skipped — never overwrite a
 * configured secret with an accidental empty value. */
export async function saveProviderAction(
  keys: string[],
  _prevState: SaveProviderState,
  formData: FormData,
): Promise<SaveProviderState> {
  try {
    for (const key of keys) {
      const raw = formData.get(key);
      if (key.endsWith(".api_key") && (!raw || String(raw).length === 0)) continue;
      await api.adminPutSetting(key, String(raw ?? ""));
    }
  } catch (err) {
    if (err instanceof ApiRequestError) return { error: err.body?.error.message ?? "Save failed." };
    return { error: "Save failed." };
  }
  revalidatePath("/ai-providers");
  return { success: true };
}

export async function saveDefaultProviderAction(
  _prevState: SaveProviderState,
  formData: FormData,
): Promise<SaveProviderState> {
  try {
    await api.adminPutSetting(
      "ai_provider.default",
      String(formData.get("ai_provider.default") ?? "ai_tutor_api"),
    );
    const quiz = String(formData.get("ai_provider.task_override.quiz_generation") ?? "");
    const rewrite = String(formData.get("ai_provider.task_override.rewrite") ?? "");
    await api.adminPutSetting("ai_provider.task_override.quiz_generation", quiz || null);
    await api.adminPutSetting("ai_provider.task_override.rewrite", rewrite || null);
  } catch (err) {
    if (err instanceof ApiRequestError) return { error: err.body?.error.message ?? "Save failed." };
    return { error: "Save failed." };
  }
  revalidatePath("/ai-providers");
  return { success: true };
}
```

- [ ] **Step 2: Generic multi-field provider card**

Create `apps/admin/app/ai-providers/ProviderCard.tsx`:

```tsx
"use client";
import type { ReactNode } from "react";
import { useActionState } from "react";
import { saveProviderAction, type SaveProviderState } from "./actions";

const initialState: SaveProviderState = {};

export interface ProviderField {
  key: string;
  label: string;
  type: "text" | "password" | "textarea";
  defaultValue?: string;
  placeholder?: string;
}

export function ProviderCard({
  title,
  fields,
  children,
}: {
  title: string;
  fields: ProviderField[];
  children?: ReactNode;
}) {
  const boundAction = saveProviderAction.bind(
    null,
    fields.map((f) => f.key),
  );
  const [state, formAction, pending] = useActionState(boundAction, initialState);

  return (
    <div className="mb-6 rounded-md border border-line bg-ink-800 p-4">
      <h2 className="mb-3 font-mono text-sm font-semibold text-slate-200">{title}</h2>
      <form action={formAction} className="space-y-3">
        {fields.map((f) => (
          <label key={f.key} className="block text-sm text-muted">
            {f.label}
            {f.type === "textarea" ? (
              <textarea
                name={f.key}
                defaultValue={f.defaultValue}
                placeholder={f.placeholder}
                rows={3}
                className="mt-1 w-full rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
              />
            ) : (
              <input
                name={f.key}
                type={f.type}
                defaultValue={f.type === "password" ? undefined : f.defaultValue}
                placeholder={f.placeholder}
                className="mt-1 w-full rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
              />
            )}
          </label>
        ))}
        <div className="flex items-center gap-2">
          <button
            type="submit"
            disabled={pending}
            className="rounded border border-accent/40 bg-accent/10 px-3 py-1 text-xs text-accent disabled:opacity-50"
          >
            {pending ? "Saving..." : "Save"}
          </button>
          {state.success ? <span className="text-xs text-good">saved</span> : null}
          {state.error ? <span className="text-xs text-bad">{state.error}</span> : null}
        </div>
      </form>
      {children}
    </div>
  );
}
```

- [ ] **Step 3: Live, sortable model catalog table**

Create `apps/admin/app/ai-providers/ModelCatalogTable.tsx`:

```tsx
"use client";
import { useState, useTransition } from "react";
import { fetchModelsAction } from "./actions";
import type { AiModelInfo } from "@/lib/api";

type SortKey = "id" | "contextLength";

export function ModelCatalogTable({ provider }: { provider: "groq" | "openrouter" }) {
  const [models, setModels] = useState<AiModelInfo[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [sortKey, setSortKey] = useState<SortKey>("id");
  const [sortDir, setSortDir] = useState<1 | -1>(1);
  const [modalityFilter, setModalityFilter] = useState("");
  const [pending, startTransition] = useTransition();

  function load() {
    setError(null);
    startTransition(async () => {
      try {
        setModels(await fetchModelsAction(provider));
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to fetch models.");
      }
    });
  }

  function sortBy(key: SortKey) {
    if (key === sortKey) setSortDir((d) => (d === 1 ? -1 : 1) as 1 | -1);
    else {
      setSortKey(key);
      setSortDir(1);
    }
  }

  const filtered = (models ?? []).filter(
    (m) => !modalityFilter || (m.modality ?? "").toLowerCase().includes(modalityFilter.toLowerCase()),
  );
  const sorted = [...filtered].sort((a, b) => {
    if (sortKey === "contextLength") return ((a.contextLength ?? 0) - (b.contextLength ?? 0)) * sortDir;
    return a.id.localeCompare(b.id) * sortDir;
  });

  return (
    <div className="mt-3">
      <div className="mb-2 flex items-center gap-2">
        <button
          type="button"
          onClick={load}
          disabled={pending}
          className="rounded border border-accent/40 bg-accent/10 px-2 py-1 text-xs text-accent disabled:opacity-50"
        >
          {pending ? "Fetching..." : "Fetch models"}
        </button>
        {models ? (
          <input
            value={modalityFilter}
            onChange={(e) => setModalityFilter(e.target.value)}
            placeholder="filter by modality (e.g. text)"
            className="rounded border border-line bg-ink-700 px-2 py-1 text-xs text-slate-100"
          />
        ) : null}
        {error ? <span className="text-xs text-bad">{error}</span> : null}
      </div>
      {models ? (
        <div className="overflow-x-auto rounded-md border border-line">
          <table className="w-full min-w-[560px] border-collapse text-xs">
            <thead className="bg-ink-700 text-muted">
              <tr>
                <th className="cursor-pointer px-2 py-1 text-left" onClick={() => sortBy("id")}>
                  Model {sortKey === "id" ? (sortDir === 1 ? "▲" : "▼") : ""}
                </th>
                <th className="cursor-pointer px-2 py-1 text-left" onClick={() => sortBy("contextLength")}>
                  Context {sortKey === "contextLength" ? (sortDir === 1 ? "▲" : "▼") : ""}
                </th>
                <th className="px-2 py-1 text-left">Pricing (prompt/completion)</th>
              </tr>
            </thead>
            <tbody>
              {sorted.map((m) => (
                <tr key={m.id} className="border-t border-line bg-ink-800 hover:bg-ink-700">
                  <td className="px-2 py-1 font-mono">{m.id}</td>
                  <td className="px-2 py-1">{m.contextLength ?? "—"}</td>
                  <td className="px-2 py-1">
                    {m.pricing ? `${m.pricing.prompt ?? "—"} / ${m.pricing.completion ?? "—"}` : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {sorted.length === 0 ? (
            <div className="p-3 text-center text-xs text-muted">No models match the filter.</div>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
```

- [ ] **Step 4: Default-provider + task-override card**

Create `apps/admin/app/ai-providers/DefaultProviderCard.tsx`:

```tsx
"use client";
import { useActionState } from "react";
import { saveDefaultProviderAction, type SaveProviderState } from "./actions";

const initialState: SaveProviderState = {};
const PROVIDERS = ["gemini", "groq", "openrouter", "ai_tutor_api"] as const;

export function DefaultProviderCard({
  defaultProvider,
  quizOverride,
  rewriteOverride,
}: {
  defaultProvider: string;
  quizOverride: string;
  rewriteOverride: string;
}) {
  const [state, formAction, pending] = useActionState(saveDefaultProviderAction, initialState);

  return (
    <div className="mb-6 rounded-md border border-line bg-ink-800 p-4">
      <h2 className="mb-1 font-mono text-sm font-semibold text-slate-200">Default provider &amp; task overrides</h2>
      <p className="mb-3 text-xs text-muted">
        The default only pre-selects a provider in this UI. Book grounding and plan generation always stay
        Gemini-first for accuracy; only quiz generation and rewrite may be reassigned below.
      </p>
      <form action={formAction} className="space-y-3">
        <label className="block text-sm text-muted">
          Default provider (UI pre-selection only)
          <select
            name="ai_provider.default"
            defaultValue={defaultProvider}
            className="mt-1 w-full rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
          >
            {PROVIDERS.map((p) => (
              <option key={p} value={p}>
                {p}
              </option>
            ))}
          </select>
        </label>
        <label className="block text-sm text-muted">
          Quiz generation provider override
          <select
            name="ai_provider.task_override.quiz_generation"
            defaultValue={quizOverride}
            className="mt-1 w-full rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
          >
            <option value="">use built-in routing (Groq-first)</option>
            {PROVIDERS.map((p) => (
              <option key={p} value={p}>
                {p}
              </option>
            ))}
          </select>
        </label>
        <label className="block text-sm text-muted">
          Rewrite provider override
          <select
            name="ai_provider.task_override.rewrite"
            defaultValue={rewriteOverride}
            className="mt-1 w-full rounded border border-line bg-ink-700 px-2 py-1 text-sm text-slate-100"
          >
            <option value="">use built-in routing (Groq-first)</option>
            {PROVIDERS.map((p) => (
              <option key={p} value={p}>
                {p}
              </option>
            ))}
          </select>
        </label>
        <div className="flex items-center gap-2">
          <button
            type="submit"
            disabled={pending}
            className="rounded border border-accent/40 bg-accent/10 px-3 py-1 text-xs text-accent disabled:opacity-50"
          >
            {pending ? "Saving..." : "Save"}
          </button>
          {state.success ? <span className="text-xs text-good">saved</span> : null}
          {state.error ? <span className="text-xs text-bad">{state.error}</span> : null}
        </div>
      </form>
    </div>
  );
}
```

- [ ] **Step 5: The page**

Create `apps/admin/app/ai-providers/page.tsx`:

```tsx
import { api, ApiRequestError } from "@/lib/api";
import type { AdminSettingRow } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { ProviderCard } from "./ProviderCard";
import { ModelCatalogTable } from "./ModelCatalogTable";
import { DefaultProviderCard } from "./DefaultProviderCard";

export default async function AiProvidersPage() {
  let rows: AdminSettingRow[] = [];
  let error: string | null = null;
  try {
    const res = await api.adminGetSettings();
    rows = res.settings;
  } catch (err) {
    error =
      err instanceof ApiRequestError
        ? `${err.status}: ${err.body?.error.message ?? err.message}`
        : (err as Error).message;
  }
  const byKey = new Map(rows.map((r) => [r.key, r]));
  const str = (key: string) => (typeof byKey.get(key)?.value === "string" ? (byKey.get(key)!.value as string) : "");
  const configured = (key: string) => byKey.get(key)?.configured ?? false;

  return (
    <div>
      <PageHeader
        title="AI Providers"
        subtitle="Admin-managed keys, models, and per-task system prompts for Groq, OpenRouter, and AI Tutor API."
      />
      {error ? (
        <div className="mb-4 rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">{error}</div>
      ) : null}

      <DefaultProviderCard
        defaultProvider={str("ai_provider.default") || "ai_tutor_api"}
        quizOverride={str("ai_provider.task_override.quiz_generation")}
        rewriteOverride={str("ai_provider.task_override.rewrite")}
      />

      <ProviderCard
        title="Groq"
        fields={[
          {
            key: "ai_provider.groq.api_key",
            label: "API key",
            type: "password",
            placeholder: configured("ai_provider.groq.api_key") ? "•••• configured" : "not set",
          },
          { key: "ai_provider.groq.model", label: "Model", type: "text", defaultValue: str("ai_provider.groq.model") },
          {
            key: "ai_provider.groq.system_prompt.plan_generation",
            label: "System prompt — plan generation (blank = built-in default)",
            type: "textarea",
            defaultValue: str("ai_provider.groq.system_prompt.plan_generation"),
          },
          {
            key: "ai_provider.groq.system_prompt.quiz_generation",
            label: "System prompt — quiz generation (blank = built-in default)",
            type: "textarea",
            defaultValue: str("ai_provider.groq.system_prompt.quiz_generation"),
          },
        ]}
      >
        <ModelCatalogTable provider="groq" />
      </ProviderCard>

      <ProviderCard
        title="OpenRouter"
        fields={[
          {
            key: "ai_provider.openrouter.api_key",
            label: "API key",
            type: "password",
            placeholder: configured("ai_provider.openrouter.api_key") ? "•••• configured" : "not set",
          },
          {
            key: "ai_provider.openrouter.model",
            label: "Model",
            type: "text",
            defaultValue: str("ai_provider.openrouter.model"),
            placeholder: "e.g. anthropic/claude-3.5-haiku",
          },
          {
            key: "ai_provider.openrouter.system_prompt.plan_generation",
            label: "System prompt — plan generation (blank = built-in default)",
            type: "textarea",
            defaultValue: str("ai_provider.openrouter.system_prompt.plan_generation"),
          },
          {
            key: "ai_provider.openrouter.system_prompt.quiz_generation",
            label: "System prompt — quiz generation (blank = built-in default)",
            type: "textarea",
            defaultValue: str("ai_provider.openrouter.system_prompt.quiz_generation"),
          },
        ]}
      >
        <ModelCatalogTable provider="openrouter" />
      </ProviderCard>

      <ProviderCard
        title="AI Tutor API"
        fields={[
          {
            key: "ai_provider.ai_tutor_api.api_key",
            label: "API key",
            type: "password",
            placeholder: configured("ai_provider.ai_tutor_api.api_key") ? "•••• configured" : "not set",
          },
          {
            key: "ai_provider.ai_tutor_api.workflow_id.book_grounding",
            label: "Workflow ID — book grounding",
            type: "text",
            defaultValue: str("ai_provider.ai_tutor_api.workflow_id.book_grounding"),
          },
          {
            key: "ai_provider.ai_tutor_api.workflow_id.plan_generation",
            label: "Workflow ID — plan generation",
            type: "text",
            defaultValue: str("ai_provider.ai_tutor_api.workflow_id.plan_generation"),
          },
          {
            key: "ai_provider.ai_tutor_api.workflow_id.quiz_generation",
            label: "Workflow ID — quiz generation",
            type: "text",
            defaultValue: str("ai_provider.ai_tutor_api.workflow_id.quiz_generation"),
          },
        ]}
      >
        <p className="mt-2 text-xs text-muted">
          Workflow IDs come from importing{" "}
          <code>docs/ai-tutor-workflows/quiz-generation-workflow.json</code> into your AI Tutor API console (see
          that folder&apos;s README).
        </p>
      </ProviderCard>
    </div>
  );
}
```

- [ ] **Step 6: Typecheck**

Run: `pnpm --filter @owlnighter/admin exec tsc --noEmit` → no errors.

- [ ] **Step 7: Commit**

```bash
git add apps/admin/app/ai-providers
git commit -m "feat(admin): AI Providers page with live model catalogs and task overrides"
```

## Task 16: AI Tutor API quiz-generation workflow deliverable

**Goal:** A real, importable workflow JSON that stands in for Groq/OpenRouter on quiz generation, matching the exact contract confirmed by reading `manage-prompt`'s own `WorkflowSchema`, Prisma model, and run-route source (not guessed) — plus a README explaining how to import it and wire the resulting `workflow_id` into the admin panel.

**Files:**
- Create: `docs/ai-tutor-workflows/build.mjs`
- Create: `docs/ai-tutor-workflows/README.md`
- Generated (by running `build.mjs`): `docs/ai-tutor-workflows/quiz-generation-workflow.json`

**Acceptance Criteria:**
- [ ] The generated JSON's top-level keys are exactly `name, model, template, instruction, modelSettings, cacheControlTtl, inputs` — no extra keys (the import route spreads the parsed JSON directly into a Prisma `create()` call; any unrecognized key would make that call throw).
- [ ] `modelSettings` is a JSON-encoded **string** (not an object) whose parsed value has `structuredOutputSchema` also as a JSON-encoded **string** (double-encoded) — matching `WorkflowSchema`'s `modelSettings: z.string().optional().nullable()` and the platform's own `ModelSettings.structuredOutputSchema?: string` type.
- [ ] `structuredOutputSchema`, once parsed, is byte-for-byte the JSON Schema for owlnighter's own `GeneratedQuiz` shape (`apps/api/src/services/quiz.ts`) — not hand-typed twice, generated once from a single JS object so the two can never drift out of sync from a typo.
- [ ] `template` is exactly `"{{system}}\n\n{{user}}"` and `inputs` declares exactly those two named, `textarea`-typed inputs — matching what `AiTutorApiAdapter` (Task 11) actually sends (a flat `{system, user}` body, not an `{inputs: {...}}` envelope).
- [ ] `model` is `"gemini-3.5-flash"` — confirmed (by reading `manage-prompt`'s own `data/workflow.ts` capability map) to be a non-deprecated model supporting both `webSearch` and `structuredOutput` in that platform's catalog.

**Verify:** `node docs/ai-tutor-workflows/build.mjs` → prints `Wrote quiz-generation-workflow.json`; `node -e "const w=require('./docs/ai-tutor-workflows/quiz-generation-workflow.json'); const ms=JSON.parse(w.modelSettings); console.log(typeof ms.structuredOutputSchema, JSON.parse(ms.structuredOutputSchema).required)"` prints `string [ 'questions' ]`, confirming the double-encoding round-trips correctly.

**Steps:**

- [ ] **Step 1: The generator script**

Create `docs/ai-tutor-workflows/build.mjs`:

```js
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
```

- [ ] **Step 2: Generate the JSON**

Run: `node docs/ai-tutor-workflows/build.mjs` → creates `docs/ai-tutor-workflows/quiz-generation-workflow.json`, printing `Wrote quiz-generation-workflow.json`.

- [ ] **Step 3: README**

Create `docs/ai-tutor-workflows/README.md`:

```markdown
# AI Tutor API workflow: quiz generation

`quiz-generation-workflow.json` is generated by `build.mjs` — **regenerate it
with `node docs/ai-tutor-workflows/build.mjs`** whenever
`apps/api/src/services/quiz.ts`'s `GeneratedQuiz` schema changes; never
hand-edit the JSON file directly.

## What it is

- `template` is a generic `{{system}}\n\n{{user}}` passthrough. owlnighter's
  `AiTutorApiAdapter` (`packages/ts/ai/src/aiTutorApi.ts`) always sends exactly
  those two named inputs as a flat request body, whatever task it runs — so
  this one workflow shape works for any owlnighter task, not just quizzes.
- `modelSettings.enableWebSearch: true` — quiz accuracy benefits from live
  search grounding.
- `modelSettings.structuredOutputSchema` is the real JSON Schema for
  owlnighter's `GeneratedQuiz` shape, generated from the same object every
  time `build.mjs` runs — so it can never silently drift from
  `apps/api/src/services/quiz.ts`'s actual Zod schema.
- `model: "gemini-3.5-flash"` is *this platform's own* model catalog entry
  (confirmed, by reading `manage-prompt`'s `data/workflow.ts` capability map,
  to support both `webSearch` and `structuredOutput` and not be deprecated) —
  it is unrelated to owlnighter's own `GEMINI_MODEL` env var / Gemini adapter;
  don't confuse the two even though the name looks similar.

## How to use it

1. In your AI Tutor API console, import this file (drag-and-drop the
   `.json`, or `PUT https://aitutor-api.vercel.app/api/workflows/import` with
   the file's bytes as the request body and your account's Bearer key).
2. Note the `shortId` (`wf_...`) the platform assigns on import — this file's
   own `name` field is overwritten by the import route regardless of what's
   in the file, so don't expect the name you see in the JSON to survive.
3. In owlnighter's admin panel, go to **AI Providers → AI Tutor API** and
   paste that id into **Workflow ID — quiz generation**.
4. Set an AI Tutor API key in the same card, and optionally reassign quiz
   generation to `ai_tutor_api` under **Default provider & task overrides**.

Importing is a manual, explicit step by design — the Bearer key belongs to a
real, possibly-billable account, so owlnighter never calls
`PUT /api/workflows/import` automatically on anyone's behalf.
```

- [ ] **Step 4: Verify the round trip**

Run:

```bash
node -e "const w=require('./docs/ai-tutor-workflows/quiz-generation-workflow.json'); const ms=JSON.parse(w.modelSettings); console.log(typeof ms.structuredOutputSchema, JSON.parse(ms.structuredOutputSchema).required)"
```

Expected output: `string [ 'questions' ]`.

- [ ] **Step 5: Commit**

```bash
git add docs/ai-tutor-workflows/build.mjs docs/ai-tutor-workflows/quiz-generation-workflow.json docs/ai-tutor-workflows/README.md
git commit -m "docs(ai-tutor): importable quiz-generation workflow + generator script"
```

## Task 17: End-to-end verification — admin panel live + Android emulator

> **USER-ORDERED GATE — NON-SKIPPABLE.** This task was requested by the user in the current conversation ("test it with android emulator and by launching the admin panel"). It MUST NOT be closed by walking around it, by declaring it "verified inline", or by substituting a cheaper check. Close only after every item in Acceptance Criteria has been re-validated independently, with output captured.

**Goal:** Prove the whole feature actually works — full backend test suite green, a real click-through of the admin panel's new auth/settings/AI-providers surfaces against a live API + local Postgres, and confirmation that the Android emulator's existing reading loop is unaffected except for the one intended behavior change (4th book rejected).

**Files:** None created — this task only runs and observes the system built by Tasks 1–16.

**Acceptance Criteria:**
- [ ] `pnpm -r run typecheck` passes across the whole monorepo.
- [ ] `pnpm -r run test` passes across the whole monorepo (every `.test.ts` file touched or added by Tasks 3–12).
- [ ] With `pnpm --filter @owlnighter/db run migrate` (or `apply-local.mjs` against local dev Postgres) and `pnpm --filter @owlnighter/db run seed:admin` applied, `pnpm dev:api` + `pnpm dev:admin` running: signing up with a non-`@mytsi.org` email at `/signup` shows a validation error and never reaches the pending state.
- [ ] Logging in as `afarhadi@mytsi.org` / `REDACTED_PASSWORD` (seeded in Task 8) succeeds and lands on the Overview page with live data (not the pre-existing "GET /v1/admin/metrics failed" error banner).
- [ ] A fresh signup for a second `@mytsi.org` email appears on `/accounts`; clicking Approve makes that account able to log in afterward.
- [ ] On `/settings`, changing `max_books_per_user` to a new value, reloading the page, shows the new value persisted (proves the DB write + settings-cache invalidation both work, not just the form submit).
- [ ] On `/ai-providers`, clicking "Fetch models" under OpenRouter (needs no key) populates a non-empty, sortable table.
- [ ] Android emulator: the existing reading loop (search → ground → add to library → generate plan → complete a step → take a quiz) still works exactly as before this feature (no regression — this feature made zero mobile-app-code changes).
- [ ] Android emulator: with `max_books_per_user` still at its default of `3` (or whatever was set during the settings-page check above), adding a 4th book is rejected with the human-readable limit message from Task 9, surfaced somewhere visible in the mobile UI (even if only as the raw API error text, since no mobile UI polish was in scope for this feature).

**Verify:** Every bullet above, performed live, with actual command output / screenshots captured — not asserted from memory of the code.

**Steps:**

- [ ] **Step 1: Full monorepo typecheck + test**

Run: `pnpm -r run typecheck` → 0 failing packages. Note: `apps/admin/package.json` has no `typecheck` script (only `dev/build/start/lint`), so pnpm silently skips it here — separately run `pnpm --filter @owlnighter/admin exec tsc --noEmit` to actually cover the admin app.
Run: `pnpm -r run test` → 0 failing packages. Capture the summary output (pass/fail counts per package).

- [ ] **Step 2: Apply migrations + seed admin accounts against local dev Postgres**

Run: `DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:55432/postgres node packages/ts/db/scripts/apply-local.mjs` → ends with `✓ Local dev DB ready`.
Run: `DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:55432/postgres pnpm --filter @owlnighter/db run seed:admin` → all 3 accounts seeded `ok`.

- [ ] **Step 3: Launch API + admin panel**

Run (background): `pnpm dev:api` — confirm it logs a listening message on port 8787.
Run (background): `pnpm dev:admin` — confirm it logs a ready message on port 3001.

- [ ] **Step 4: Walk the admin panel live**

In a browser at `http://localhost:3001`:
1. Confirm an unauthenticated visit redirects to `/login`.
2. At `/signup`, submit `someone@gmail.com` — confirm a validation error appears and no pending-state screen is shown.
3. At `/login`, log in with `afarhadi@mytsi.org` / `REDACTED_PASSWORD` — confirm redirect to `/` and real metrics tiles render (not an error banner).
4. In a second (incognito) browser context, submit `/signup` with a second real-looking `@mytsi.org` address and a valid password — confirm the "request submitted" screen appears.
5. Back in the logged-in session, visit `/accounts`, find the new pending request, click Approve.
6. In the incognito context, log in with that just-approved account — confirm it succeeds.
7. Visit `/settings`, change `max_books_per_user` to `5`, click Save, confirm the "saved" indicator, then hard-reload the page — confirm the field still shows `5`.
8. Visit `/ai-providers`, click "Fetch models" under OpenRouter — confirm a populated table appears; if a real Groq key is present in this dev environment's settings, repeat under Groq.
9. Click "Log out" in the sidebar — confirm redirect to `/login` and that visiting `/` again redirects back to `/login`.

- [ ] **Step 5: Android emulator — regression + the one intended behavior change**

Launch the Android emulator and run the mobile app against the same local API (per this repo's existing mobile-dev instructions — check `apps/mobile/README.md` or `GOAL.md` for the exact emulator run command already established in this project, since that tooling predates this feature and isn't being changed here).

1. Exercise the existing core loop once, end to end (search a book → ground it → add to library → generate a plan → open a step → complete a quiz) — confirm it behaves identically to before this feature (no visible regression).
2. With `max_books_per_user` set to `5` from Step 4.7 above, add books until the 5th active book is rejected — confirm the app surfaces the limit-reached error from `POST /v1/library/books` (Task 9) rather than silently failing or crashing.

- [ ] **Step 6: Record the outcome**

Summarize, in the PR description or a commit message, which of the above passed live and which (if any) could not be fully exercised in this environment (e.g., Groq's catalog fetch if no real Groq key is configured here) — per the spec's own Verification Plan section, that gap is expected and acceptable, not a failure, as long as it's stated explicitly rather than silently skipped.

---

## Verification plan (cross-reference)

This mirrors the spec's own Verification Plan section (see `docs/superpowers/specs/2026-07-15-admin-panel-safeguards-design.md`):
- **Backend unit tests** — covered by Tasks 4, 6, 7, 9, 10, 11, 12's own test steps, re-run in aggregate by Task 17 Step 1.
- **Admin panel, driven live** — Task 17 Steps 3–4.
- **Android emulator** — Task 17 Step 5.

## File/migration plan (summary)

- `infra/sql/0004_admin_accounts.sql`, `0005_app_settings.sql`, `0006_provider_enum_relax.sql` + mirrored Drizzle tables (Tasks 1–3).
- `packages/ts/db/scripts/seed-admin-accounts.mjs` (Task 8).
- `packages/ts/contracts/src/admin-auth.ts`, `settings.ts` + `endpoints.ts` changes (Task 5).
- `apps/api/src/plugins/admin-session.ts`, `routes/admin-auth.ts`, `routes/settings.ts`, `services/admin-auth.ts`, `services/settings.ts`, `services/ai-models.ts`, `services/ai-settings.ts`, `utils/admin-crypto.ts` (Tasks 4, 6, 7, 9, 10, 12).
- `packages/ts/ai/src/openrouter.ts`, `aiTutorApi.ts`, router changes (Tasks 10, 11).
- `apps/admin/app/login`, `/signup`, `/accounts`, `/settings`, `/ai-providers` + `lib/session*.ts`, `lib/auth-actions.ts`, `middleware.ts`, `lib/api.ts` changes (Tasks 13–15).
- `docs/ai-tutor-workflows/quiz-generation-workflow.json` + `build.mjs` + `README.md` (Task 16).

