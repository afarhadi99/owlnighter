<div align="center">

# 🦉 owlnighter

### _Pull an owl-nighter — build a nightly reading habit._

A Duolingo-style reading-habit platform: add a book, get a paced nightly reading
path, read your pages, take a short quiz to lock in the day, keep your streak
alive, and drift off to a calm audio recap. Book facts are **grounded** with
citations so the app never fakes precision it doesn't have.

</div>

---

> **Status:** runs end-to-end. The Flutter app runs on an Android emulator
> against the live local API with dev auth (Google Books/Open Library search →
> Gemini grounding → library → Gemini/Groq plan generation → quiz → streak),
> and the admin console's live pages render against the same API. The full
> on-device loop is verified: path map → nightly session → quiz → 4/4 → streak
> celebration → real local push notifications → a Duolingo-style home-screen
> widget whose owl visibly changes mood with the day. **74 backend tests**
> (`node:test`, no Postgres required) + **174 Dart tests** are green, the
> OpenAPI contract emits **21 paths**, and the Android debug APK builds.
> This is a real, structured monorepo built from
> [`docs/reading-research.md`](docs/reading-research.md). See
> [`GOAL.md`](GOAL.md) for the live build plan and what is done vs. pending,
> or [`docs/reports/round9-feature-report.html`](docs/reports/round9-feature-report.html)
> for a screenshot-driven walkthrough of the latest round.

## Screenshots

<div align="center">

| Library | Reading path | Tonight's reading | Quiz |
| :---: | :---: | :---: | :---: |
| <img src="docs/screenshots/library.jpg" width="200"> | <img src="docs/screenshots/reading-path.jpg" width="200"> | <img src="docs/screenshots/nightly-session.jpg" width="200"> | <img src="docs/screenshots/quiz.jpg" width="200"> |
| **Night complete** | **Streak + mood owl** | **Real reminders** | **Home-screen widget** |
| <img src="docs/screenshots/completion.jpg" width="200"> | <img src="docs/screenshots/streaks-mood.jpg" width="200"> | <img src="docs/screenshots/settings-reminder.jpg" width="200"> | <img src="docs/screenshots/home-widget.jpg" width="200"> |

</div>

The owl mascot's mood — calm, worried, angry, or cheerful — reflects whether
tonight's reading is done yet and how late it is, on both the Streaks tab and
the home-screen widget; the **Streak + mood owl** shot above shows the
cheerful state, right after finishing a session.

## What's in the box

`owlnighter` is a **polyglot monorepo**:

| Path | What it is | Stack |
| --- | --- | --- |
| `apps/mobile` | Reader app | **Flutter** · Riverpod · go_router · drift · Rive/Lottie |
| `apps/admin` | Ops + content QA console | **Next.js** App Router |
| `apps/api` | Authoritative API + AI/workflow layer | **Fastify** + TypeScript |
| `packages/ts/contracts` | Source-of-truth request/response schemas | **Zod → JSON Schema → OpenAPI** |
| `packages/ts/ai` | Provider abstraction | **Gemini** (grounding) · **Groq** (low-latency) |
| `packages/ts/db` | Schema + migrations | **Drizzle** over **Supabase Postgres** + pgvector |
| `packages/ts/jobs` | Scheduled/queued work | TTS pre-gen, reminders |
| `packages/ts/shared` | Cross-cutting utils | logging, ids, env, flags |
| `packages/dart/*` | Shared Dart libs | `app_core`, `api_client`, `design_system`, `offline` |
| `infra/` | SQL, docker, firebase, cloud-run | — |

## Core design decisions

- **Flutter over Expo** — one rendering stack for iOS/Android, full motion control.
- **OpenAPI, not tRPC** — Flutter can't consume TS types; Zod is the contract
  source, converted to JSON Schema/OpenAPI, then codegen'd to **TS + Dart** clients.
- **Two-pass grounding** — deterministic catalog lookup (Google Books + Open
  Library) → **Gemini Search Grounding** reconciliation with citations → persisted
  "truth layer" → **Groq Qwen** does fast downstream generation from grounded facts.
- **Honest quiz modes** — `grounded` · `preview` · `user_text` · `fallback`. The
  app never claims page-specific precision when the evidence is weak.
- **Motion, mapped not copied** — native Flutter animations by default, Rive for
  stateful mascot/reward interactions, Lottie sparingly, `CustomPainter` for the
  reading path. Respects `MediaQuery.disableAnimations`.
- **Keys stay on the backend** — no Gemini/Groq/Deepgram keys ever ship to the client.

## Architecture

```mermaid
flowchart TD
    Reader[Flutter app] -->|HTTPS| API[Fastify API]
    Reader -->|Auth session| Supabase[(Supabase PG/Auth/Storage)]
    Admin[Next.js admin] -->|HTTPS| API
    API -->|SQL + Storage + Auth admin| Supabase
    API -->|Grounding + structured output| Gemini[Gemini 3.5 Flash]
    API -->|Low-latency generation| Groq[Groq Qwen 3.6]
    API -->|TTS synth| Deepgram[Deepgram Aura]
    API -->|Push| FCM[FCM / APNs]
    Books[Google Books / Open Library] --> API
```

## Quick Start

Cloned this with **nothing installed**? One command sets up everything —
dependencies, API keys, `.env`, and a seeded local Postgres:

```bash
./scripts/setup.sh      # macOS / Linux / Git Bash on Windows
./scripts/setup.ps1     # Windows PowerShell
```

It preflight-checks your tools, walks you through the API keys, stands up a
`pgvector` Postgres in Docker, and applies the migrations + seeds admin/demo
data. Then:

```bash
pnpm dev:api      # API   → http://localhost:8787
pnpm dev:admin    # Admin → http://localhost:3001  (log in with a seeded admin)

# Mobile (needs the Flutter SDK + an Android emulator):
cd apps/mobile && flutter run --dart-define API_BASE_URL=http://10.0.2.2:8787
```

**Prerequisites** (the script detects these and links installers for any that
are missing): Git, Node ≥20 (`corepack enable` for pnpm), Docker Desktop, and —
for the mobile app — the Flutter SDK + Android Studio/emulator.

**→ Full walkthrough, API-key sources, env reference, and troubleshooting:
[`docs/SETUP.md`](docs/SETUP.md).**  
For the fast API-only curl loop, see [`docs/local-dev.md`](docs/local-dev.md).

## Testing

See **[`docs/testing.md`](docs/testing.md)** for the full list. In short:

```bash
# Backend — 74 tests, node:test, no Postgres required
pnpm --filter @owlnighter/api test

# Every Dart package — analyze + test (api_client is analyze-only, no tests yet)
cd apps/mobile && flutter analyze && flutter test              # 66 tests
cd packages/dart/app_core && flutter analyze && flutter test   # 22 tests
cd packages/dart/offline && flutter analyze && flutter test    # 19 tests
cd packages/dart/design_system && flutter analyze && flutter test  # 67 tests
cd packages/dart/api_client && flutter analyze

# OpenAPI contract must be regenerated & committed after any Zod change
pnpm contracts:openapi
```

## Repo conventions

- **TypeScript** side is a `pnpm` workspace. **Dart/Flutter** side is a `melos`
  workspace. They coexist in one git repo.
- Contracts flow **one direction**: edit Zod in `packages/ts/contracts` → regenerate
  OpenAPI → regenerate clients. Never hand-edit generated clients.
- Every AI call is `model → parse → validate (Zod) → retry/downgrade → persist`.

## License

[MIT](LICENSE) © 2026 Alisher Farhadi
