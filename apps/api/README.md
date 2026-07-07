# @owlnighter/api

Fastify + TypeScript API for owlnighter. Implements every route in the
`@owlnighter/contracts` `ENDPOINTS` registry — the same registry the OpenAPI
document is generated from, so the running server can't drift from the spec.

## Run

```bash
pnpm dev:api        # tsx watch src/server.ts (from repo root)
# or, in this package:
pnpm dev            # watch mode
pnpm build          # tsc -> dist/
pnpm start          # node dist/server.js
pnpm typecheck      # tsc --noEmit
```

The server listens on `API_HOST:API_PORT` (default `0.0.0.0:8787`).

- `GET /healthz` — liveness probe (no auth).
- `GET /openapi.json` — the generated OpenAPI 3.1 document.

## Environment

Copy the repo-root `.env.example` to `.env`. Keys this service actually uses:

| Var | Purpose | Behaviour when missing |
| --- | --- | --- |
| `DATABASE_URL` | Postgres (Supabase) via Drizzle | required |
| `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | verify user JWTs | auth fails closed (see dev note) |
| `GEMINI_API_KEY`, `GEMINI_MODEL` | grounding + plans | grounding/plans return `503 service_unavailable` |
| `GROQ_API_KEY`, `GROQ_MODEL` | quiz generation (Groq-first) | falls back to Gemini |
| `GOOGLE_BOOKS_API_KEY` | catalog search (optional key) | search still works unauthenticated, lower quota |
| `DEEPGRAM_API_KEY` | TTS generation | `/v1/tts/generate` returns `503` unless already cached |
| `GROUNDING_AUTO_ACCEPT`, `GROUNDING_REVIEW_FLOOR` | confidence buckets | defaults 0.85 / 0.60 |

Nothing is faked: when an external dependency is unconfigured, the affected
route degrades to a clear `503 service_unavailable` (or `401` for auth) rather
than returning a fabricated success.

## Auth

Protected routes expect `Authorization: Bearer <supabase-jwt>`. The token is
verified with `supabase.auth.getUser()`; `profiles.is_admin` gates admin routes.

**Dev auth** (only when `NODE_ENV=development`): send `Authorization: Bearer DEV`
to authenticate as the fixed dev user `00000000-0000-0000-0000-0000000000de`,
or `Bearer DEV:<uuid>` to impersonate a specific user id. This path never
contacts Supabase and is hard-disabled outside development.

## Layout

```
src/
  config.ts        env + logger + flags, resolved once
  deps.ts          db / ai router / supabase / jobs, assembled once
  types.ts         Fastify request augmentation (requestId, user)
  app.ts           build the Fastify instance (cors, plugins, routes, /healthz, /openapi.json)
  server.ts        listen on API_HOST/API_PORT
  plugins/         request-id, error envelope, auth (user + admin guards)
  services/        catalog, grounding, plans, quiz — the real logic
  routes/          one file per contract tag, registered from ENDPOINTS
```
