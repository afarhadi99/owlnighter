# @owlnighter/admin

The owlnighter **grounding inspection console** — a Next.js 15 (App Router)
admin surface. It is *not* just CRUD: the operational differentiator is
**source provenance**, so every grounded fact links back to the exact catalog
candidates or web sources that produced it (blueprint §"Admin dashboard feature
set").

## Run

```bash
pnpm install          # from the repo root
cp .env.local.example .env.local
pnpm --filter @owlnighter/admin dev   # http://localhost:3001
```

It talks to the Fastify API at `NEXT_PUBLIC_API_URL` (default
`http://localhost:8787`).

## Modules (sidebar)

| Route              | Module                      | Data source                                   |
| ------------------ | --------------------------- | --------------------------------------------- |
| `/`                | Overview health tiles       | **mock** (no metrics endpoint yet)            |
| `/books`           | Books & reconciliation      | live `POST /v1/books/search`                  |
| `/grounding/[id]`  | Grounding review + override | live `GET`/`POST /v1/admin/books/:id/...`     |
| `/plans`           | Plan QA                     | **mock** (shape mirrors `PlanStep`)           |
| `/quiz`            | Quiz QA + invalidation      | **mock**                                      |
| `/tts`             | TTS QA (cache, voices)      | **mock**                                      |
| `/notifications`   | Templates + delivery health | **mock**                                      |
| `/support`         | User support / repair       | **mock**                                      |
| `/model-ops`       | Routing + fallback logs     | **mock**                                      |

Live surfaces call the API through the hand-written typed client in
[`lib/api.ts`](./lib/api.ts). Mock surfaces are clearly marked with a
`TODO wire to API` banner and note the endpoint that still needs to exist.

## Design notes

- **Standalone app.** Intentionally *not* part of the strict pnpm workspace TS
  build and does *not* extend `tsconfig.base.json` — it uses Next's bundler
  module resolution. `lib/api.ts` re-declares the contract shapes rather than
  importing `@owlnighter/contracts` to keep it dependency-light.
- **Security.** No Gemini/Groq/Deepgram keys ever reach this app; only
  `NEXT_PUBLIC_*` vars are browser-exposed. Admin calls send an `x-admin`
  marker header today — replace with a real Supabase JWT / service token
  (see the `TODO` in `lib/api.ts`).
- **UI.** Dense, dark, monospace-leaning ops aesthetic via Tailwind. Shared
  primitives in `components/`: `Sidebar`, `StatTile`, `DataTable`,
  `ProvenanceList`, `Badge`, `PageHeader`.

## Follow-ups (endpoints the contract does not yet define)

- metrics/observability endpoint for the Overview tiles
- admin list endpoints for plans, quizzes, TTS assets, notification templates
- `POST /v1/admin/quiz/:id/invalidate`
- admin user-lookup + repair mutations (streak repair, plan reset)
- signed-URL TTS preview
