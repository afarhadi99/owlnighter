# Local development — running the API end-to-end

This is the fastest loop to exercise the real API (Google Books + Open Library,
Gemini grounding, Groq/Gemini plan + quiz generation, streaks) against a local
Postgres, **without** a full Supabase project.

> Verified working on 2026-07-08: the full loop (search → ground → library add →
> plan → quiz → submit → streak) passes against live Gemini/Groq keys.

## 1. Start Postgres (pgvector)

```bash
docker run -d --name owlnighter-pg \
  -e POSTGRES_PASSWORD=postgres -e POSTGRES_USER=postgres -e POSTGRES_DB=postgres \
  -p 55432:5432 pgvector/pgvector:pg16
```

> Port note: Supabase's default `54322` is inside a Windows-reserved range on some
> machines (`bind: forbidden`). We use `55432` here and point `DATABASE_URL` at it.

## 2. Apply schema + dev auth shim + seed

Our migrations reference `auth.users` / `auth.uid()`, which real Supabase provides.
For a plain Postgres, `apply-local.mjs` first applies a **dev-only** stub
(`infra/sql/dev/0000_auth_shim.sql`), then the real migrations, then seeds the dev user.

```bash
cd packages/ts/db
DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:55432/postgres \
  node scripts/apply-local.mjs
```

(Against a real Supabase DB use `scripts/apply-sql.mjs` instead — no shim.)

## 3. Configure `.env`

Copy `.env.example` → `.env` and set `GEMINI_API_KEY`, `GROQ_API_KEY`, and
`DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:55432/postgres`.
Valid live model ids: `GEMINI_MODEL=gemini-3.5-flash`, `GROQ_MODEL=qwen/qwen3.6-27b`.

## 4. Run the API

```bash
pnpm --filter @owlnighter/api build
node --env-file=.env apps/api/dist/server.js
# or: pnpm dev:api   (tsx watch — but load .env yourself, e.g. via --env-file)
```

## 5. Dev auth

No Supabase is needed for local API work: send `Authorization: Bearer DEV` to
authenticate as the seeded dev user (`is_admin=true`, so admin routes work too).
This is hard-gated to `NODE_ENV=development`.

## 6. Drive the loop

```bash
AUTH='-H "Authorization: Bearer DEV" -H "Content-Type: application/json"'

# search (Google Books + Open Library)
curl -s $AUTH -X POST localhost:8787/v1/books/search \
  -d '{"title":"The Left Hand of Darkness","author":"Ursula K. Le Guin"}'

# ground (Gemini) — persists the book, returns bookId
curl -s $AUTH -X POST localhost:8787/v1/books/ground \
  -d '{"title":"The Left Hand of Darkness","author":"Ursula K. Le Guin"}'

# then: POST /v1/library/books, POST /v1/plans/generate,
#       POST /v1/steps/:id/quiz, POST /v1/quiz/:id/submit
```

Health + spec: `GET /healthz`, `GET /openapi.json`.
