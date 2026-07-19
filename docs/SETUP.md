# owlnighter — developer setup (from scratch)

This guide takes a freshly cloned repo on a machine with **nothing installed** to a
running app: dependencies installed, API keys + env configured, a local Postgres
stood up and seeded, and the API / admin / mobile app running.

> **TL;DR** — install Git + Node ≥20 + Docker (and Flutter for mobile), then run
> **one command**:
>
> ```bash
> ./scripts/setup.sh            # macOS / Linux / Git Bash on Windows
> ./scripts/setup.ps1           # Windows PowerShell
> ```
>
> It walks you through API keys, writes `.env`, installs deps, and stands up +
> seeds a local Postgres. Then `pnpm dev:api` + `pnpm dev:admin` and you're live.

---

## 1. Prerequisites

Install these first. The setup script **detects** all of them and prints install
hints for anything missing — but it will not auto-install the heavy tools
(Docker, Flutter), because scripting those installs is fragile.

| Tool | Needed for | Install |
| --- | --- | --- |
| **Git** | cloning the repo | https://git-scm.com/downloads |
| **Node ≥ 20** | all TypeScript (API, admin, DB scripts) | https://nodejs.org/en/download (LTS) |
| **pnpm** | the workspace package manager | `corepack enable` (ships with Node ≥16) |
| **Docker** | the local Postgres database | Docker Desktop: https://www.docker.com/products/docker-desktop/ |
| **Flutter SDK** | the mobile app only | https://docs.flutter.dev/get-started/install |
| **Android Studio + SDK + emulator** | running the mobile app | https://developer.android.com/studio |

Notes:

- **pnpm**: don't `npm i -g pnpm`. Node ships **corepack**, which pins the exact
  pnpm version this repo expects (`packageManager` in `package.json`). Just run
  `corepack enable` once. The setup script does this for you if pnpm is missing.
- **Docker** must be **running** (Docker Desktop launched / the daemon started)
  before the database step — the script checks and tells you if it isn't.
- **Flutter/Android** are only needed for the mobile app. The API and admin
  console run without them.

---

## 2. The one-command path

From the repo root:

```bash
# macOS / Linux / Git Bash on Windows
./scripts/setup.sh

# Windows PowerShell (if blocked once: powershell -ExecutionPolicy Bypass -File scripts/setup.ps1)
./scripts/setup.ps1
```

What the bootstrap wrapper does:

1. Ensures **Node ≥ 20** and **pnpm** exist (installs Node via `brew`/`apt`/`dnf`/
   `winget` if missing; enables pnpm via corepack). It does **not** touch Docker
   or Flutter.
2. Hands off to **`scripts/setup.mjs`**, the cross-platform orchestrator, which:
   - **Preflight** — prints a ✓/✗ table for node / pnpm / docker / flutter, with
     per-OS install hints for anything missing.
   - **Env + keys** — copies `.env.example` → `.env` (if absent), then walks you
     through each provider API key (paste or press Enter to skip), and pins
     `DATABASE_URL` to the local Postgres it manages.
   - **Admin passwords** — the 3 admin-panel logins: auto-generate strong ones
     (printed **once**) or type your own.
   - **Install** — `pnpm install`.
   - **Database** — starts a `pgvector/pgvector:pg16` container named
     `owlnighter-db` on port **55432**, waits until it's ready, then applies the
     dev auth shim → canonical migrations → dev seed, and seeds the admin
     accounts + demo data.
   - **Finish** — prints exactly how to run the API / admin / mobile app.

Every step is **idempotent** — safe to re-run. On a second run it detects the
existing schema and skips migrations, re-seeding (idempotently) only.

### Non-interactive / CI

```bash
./scripts/setup.sh --non-interactive     # or: pnpm setup -- --non-interactive
```

Scaffolds `.env` from `.env.example` with **no prompts** (fill the keys in later),
auto-generates admin passwords, installs, and stands up + seeds the DB. Useful
for CI or a quick "just get it running" pass.

Other flags: `--skip-db`, `--skip-install`, `--skip-flutter-check`.

### Just the pieces (npm scripts)

```bash
pnpm setup          # node scripts/setup.mjs (interactive)
pnpm db:up          # start the pgvector container on :55432
pnpm db:migrate     # apply dev shim + migrations + dev seed (reads .env)
pnpm db:seed        # seed admin accounts + demo data (reads .env)
```

---

## 3. API keys — where to get them, what needs what

The app is **backend-keyed**: no AI/TTS keys ever ship to the mobile client. Set
them in `.env` (gitignored). **The app runs with just one AI key** — provider
routing falls back automatically.

| Env var | Provider | Get a key | Required? |
| --- | --- | --- | --- |
| `GEMINI_API_KEY` | Google Gemini — grounding, plan + quiz generation (default brain) | https://aistudio.google.com/apikey | **Recommended.** At least one AI key is needed; Gemini is the safest single choice. |
| `GROQ_API_KEY` | Groq (Qwen) — fast downstream generation | https://console.groq.com/keys | Optional. Speeds up quiz/plan gen; falls back to Gemini without it. |
| `DEEPGRAM_API_KEY` | Deepgram Aura — TTS for the nightly audio recap | https://console.deepgram.com/ | Optional. Only for TTS/audio. |
| `GOOGLE_BOOKS_API_KEY` | Google Books — richer catalog search | https://console.cloud.google.com/apis/credentials (enable **Books API**, create an API key) | Optional. Open Library search works without it. |

Which features need which:

- **Quiz / plan / grounding** — need at least one AI key (`GEMINI_API_KEY`, or
  `GROQ_API_KEY` for the routable tasks). Gemini alone is enough.
- **Nightly audio recap (TTS)** — needs `DEEPGRAM_API_KEY`. Everything else works
  without it.
- **Catalog search** — always works via Open Library; `GOOGLE_BOOKS_API_KEY` just
  broadens coverage.

### The AI Tutor API (default provider) — key goes in the admin panel

owlnighter now defaults individual AI tasks to the **AI Tutor API** provider.
Its key is **not** an env var — it's configured in the **admin panel → AI
Providers → AI Tutor API**, stored in the `app_settings` table.

Two of the three workflows (`book_grounding`, `plan_generation`) currently **fall
back to Gemini** regardless — routing for them is hardcoded to Gemini today, so
you need a Gemini key for grounding + plan generation to work. The AI Tutor
workflow definitions and settings keys are prepared for forward-compatibility.
To import the workflows and paste their ids into admin settings, follow
[`docs/ai-tutor-workflows/README.md`](ai-tutor-workflows/README.md) (importing is
a manual browser step in the AI Tutor console; the workflow JSON lives in
`docs/ai-tutor-workflows/`).

---

## 4. Environment variable reference

Full template with comments: [`.env.example`](../.env.example). Copy it to `.env`
(the setup script does this) and fill in. **Never commit `.env`.**

| Variable | What it's for | Required? | Default |
| --- | --- | --- | --- |
| `NODE_ENV` | run mode; `development` enables dev auth | yes | `development` |
| `API_HOST` / `API_PORT` | API bind host/port | yes | `0.0.0.0` / `8787` |
| `API_PUBLIC_URL` | public base URL of the API | yes | `http://localhost:8787` |
| `LOG_LEVEL` | log verbosity | no | `info` |
| `GEMINI_API_KEY` | Gemini key (grounding, plan/quiz gen) | recommended (1 AI key min) | — |
| `GEMINI_MODEL` | Gemini model id | no | `gemini-3.5-flash` |
| `GROQ_API_KEY` | Groq key (fast generation) | optional | — |
| `GROQ_MODEL` | Groq model id | no | `qwen/qwen3.6-27b` |
| `DEEPGRAM_API_KEY` | Deepgram TTS key | optional (TTS only) | — |
| `DEEPGRAM_TTS_MODEL` | Deepgram voice model | no | `aura-2-thalia-en` |
| `SUPABASE_URL` | Supabase project/local URL | for full Supabase auth/storage | `http://127.0.0.1:54321` |
| `SUPABASE_ANON_KEY` | Supabase anon key | for full Supabase | — |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role key | for full Supabase | — |
| `DATABASE_URL` | Postgres connection string | **yes** | set by setup → `…@127.0.0.1:55432/postgres` |
| `GOOGLE_BOOKS_API_KEY` | Google Books catalog key | optional | — |
| `OPEN_LIBRARY_BASE_URL` | Open Library base URL | no | `https://openlibrary.org` |
| `FCM_PROJECT_ID` | Firebase project id (push) | optional (push only) | — |
| `FCM_SERVICE_ACCOUNT_JSON` | FCM service account JSON | optional (push only) | — |
| `GROUNDING_AUTO_ACCEPT` | confidence ≥ this → auto-accept a grounding | no | `0.85` |
| `GROUNDING_REVIEW_FLOOR` | confidence ≥ this → needs review (below → limited) | no | `0.60` |
| `SEED_ADMIN_PASSWORD_RCOHEN` | admin-panel login for rcohen@mytsi.org | for `seed:admin` | — (placeholder `changeme` rejected) |
| `SEED_ADMIN_PASSWORD_NKUKAJ` | admin-panel login for nkukaj@mytsi.org | for `seed:admin` | — |
| `SEED_ADMIN_PASSWORD_AFARHADI` | admin-panel login for afarhadi@mytsi.org | for `seed:admin` | — |

> The **AI Tutor API key** is intentionally absent here — it lives in the admin
> panel (`app_settings`), not `.env`.

---

## 5. The database

The setup script manages a **plain pgvector Postgres** (not the full Supabase
stack) so local API work needs only Docker:

- **Image**: `pgvector/pgvector:pg16` (provides the `vector` extension that
  `infra/sql/0001_init.sql` requires).
- **Container**: `owlnighter-db`, host port **55432** → `DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:55432/postgres`.
- **Why 55432 and not 54322?** Supabase's default `54322` falls in a
  Windows-reserved port range on some machines (`bind: forbidden`), so we use
  `55432`.

What the DB step applies, in order (this **order matters**):

1. **`infra/sql/dev/0000_auth_shim.sql`** — a dev-only stand-in for the parts of
   Supabase's `auth` schema (`auth.users`, `auth.uid()`, the anon/authenticated/
   service_role roles) that the product migrations FK against. It **must** run
   before `0001_init.sql`.
2. **`infra/sql/*.sql`** — the canonical migrations (schema, RLS, admin accounts,
   app settings, …), in filename order.
3. **`infra/sql/dev/0001_seed_dev.sql`** — the fixed local dev user.
4. **`seed-admin-accounts.mjs`** — upserts the 3 admin-panel logins from the
   `SEED_ADMIN_PASSWORD_*` env vars (bcrypt-hashed; the `changeme` placeholder is
   rejected).
5. **`seed-demo-data.mjs`** — idempotent demo readers, books (across grounding
   states), plans, quizzes, streaks, and grounding provenance.

> The order is why the setup path uses `apply-local.mjs`, **not** the
> `docker-compose.yml` init-mount — that compose file auto-runs the canonical
> migrations on first boot, which fails on a plain Postgres because `0001_init`
> references `auth.users` before the dev shim creates it.

### Re-seeding / resetting

```bash
pnpm db:seed                        # re-run admin + demo seeds (idempotent)

# Full reset (throws away all local data):
docker rm -f owlnighter-db
pnpm setup                          # recreates the container and re-applies everything
```

Against a **real Supabase** DB, use `packages/ts/db/scripts/apply-sql.mjs`
(canonical migrations only — Supabase already provides `auth`), not the dev shim.

---

## 6. Running the app

Two terminals (API + admin). Both read `.env`.

```bash
# Terminal 1 — API  → http://localhost:8787
pnpm dev:api
#   health check:  GET http://localhost:8787/healthz
#   OpenAPI spec:  GET http://localhost:8787/openapi.json

# Terminal 2 — Admin console → http://localhost:3001
pnpm dev:admin
#   log in with a seeded admin, e.g. afarhadi@mytsi.org
#   (password: the one you set / the auto-generated one printed during setup)
```

**Dev auth (no Supabase needed):** send `Authorization: Bearer DEV` to
authenticate as the seeded dev user (`is_admin=true`). Hard-gated to
`NODE_ENV=development`. See [`docs/local-dev.md`](local-dev.md) for a full
search → ground → plan → quiz → streak curl walkthrough.

### Mobile app (Flutter)

The Android emulator reaches your host machine's API at `10.0.2.2`:

```bash
cd apps/mobile
flutter pub get
# (first time, for the Dart workspace)  dart pub global activate melos && melos bootstrap
flutter run --dart-define API_BASE_URL=http://10.0.2.2:8787
```

Make sure `pnpm dev:api` is running first.

---

## 7. Troubleshooting

- **"Docker isn't available/running"** — launch Docker Desktop (or start the
  daemon), then re-run `node scripts/setup.mjs --skip-flutter-check`. The DB step
  is the only one that needs Docker; everything before it already ran.
- **Port already in use** — the DB uses **55432**, API **8787**, admin **3001**.
  If 55432 is taken, stop the conflicting container (`docker ps`) or override:
  `SETUP_DB_PORT=55433 pnpm setup` (this also rewrites `DATABASE_URL`).
- **`seed:admin` refuses to run** — a `SEED_ADMIN_PASSWORD_*` is still `changeme`
  or empty. Set real values in `.env` (or let setup auto-generate them).
- **Emulator launches a disabled icon / blank alias** — the launcher sometimes
  starts the wrong activity alias. Force the real one:
  `adb shell am start -n app.owlnighter/.MainActivity`.
- **First-launch "database is locked" (mobile)** — a transient SQLite race on the
  on-device cache DB; tap **Retry** and it clears.
- **pnpm store hiccup / half-installed deps** — run `pnpm install` again; the
  store is content-addressed and self-heals.
- **`pnpm` not found after install** — corepack needs a fresh shell to update
  PATH. Open a new terminal, run `corepack enable`, and re-run setup.
- **Wrong model id errors from Gemini/Groq** — use the ids in `.env.example`
  (`GEMINI_MODEL=gemini-3.5-flash`, `GROQ_MODEL=qwen/qwen3.6-27b`).

---

## 8. See also

- [`docs/local-dev.md`](local-dev.md) — the fast API-only loop + curl walkthrough.
- [`docs/testing.md`](testing.md) — running the backend + Dart test suites.
- [`docs/ai-tutor-workflows/README.md`](ai-tutor-workflows/README.md) — importing
  AI Tutor API workflows and wiring their ids into admin settings.
