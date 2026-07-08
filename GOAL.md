# 🎯 owlnighter — Build Goal & Progress

**Goal:** Implement the full platform described in
[`docs/reading-research.md`](docs/reading-research.md) — a Flutter reader app, a
Next.js admin console, and a Fastify API over Supabase, with Gemini grounding,
Groq low-latency generation, Deepgram TTS, and FCM push — as a coherent,
inspectable, honestly-scoped monorepo.

This file is the **living checklist**. It is updated as each piece lands.

**Live repo:** https://github.com/afarhadi99/owlnighter (public) — pushed 2026-07-08.

Legend: ✅ done & buildable · 🟡 authored (not runnable in this env) · 🔨 in progress · ⬜ not started

---

## Environment reality check (surfaced up front)

| Capability | State | Note |
| --- | --- | --- |
| Node / pnpm / TypeScript | ✅ | installed & used to verify TS builds |
| Docker | ✅ | available for local Postgres/Supabase |
| Flutter / Dart SDK | ❌ not installed | Flutter source is **authored, not compiled** here |
| GitHub `gh` CLI / token | ❌ | repo publish requires a decision with the owner |
| Gemini + Groq keys | ✅ | pulled from sibling repos into local `.env` |
| Supabase / Deepgram / FCM | 🟡 local | placeholders per instruction; wire real creds later |

---

## Component build status

The whole architecture is now scaffolded. TypeScript is built & verified; the
Flutter tree is authored but can't compile here (no SDK).

| Component | Path | Status |
| --- | --- | --- |
| Contracts (Zod → OpenAPI) | `packages/ts/contracts` | ✅ builds · OpenAPI emits 11 paths |
| Shared (env/log/ids/flags) | `packages/ts/shared` | ✅ builds |
| DB (Drizzle + SQL/RLS/pgvector) | `packages/ts/db` + `infra/sql` | ✅ builds |
| AI router (Gemini + Groq) | `packages/ts/ai` | ✅ builds · 4/4 unit tests pass |
| Jobs (TTS/reminders) | `packages/ts/jobs` | ✅ builds |
| Fastify API (11 routes) | `apps/api` | ✅ typechecks · inject smoke test passes |
| Next.js admin console | `apps/admin` | ✅ `next build` compiles (11 routes) |
| Flutter app + Dart pkgs | `apps/mobile` + `packages/dart/*` | 🟡 authored — needs SDK + codegen |
| Infra (Docker/CloudRun/FCM) | `infra/*` | 🟡 authored — YAML valid, not deployed |
| CI (GitHub Actions) | `.github/workflows` | ✅ mirrors local green checks |

**Full-workspace `pnpm -r build`: green (all 8 TS/Next projects).**

---

## Stage 0 — Foundation scaffold  ✅

- ✅ Monorepo layout (`apps/`, `packages/ts/`, `packages/dart/`, `infra/`)
- ✅ Root config: `pnpm-workspace.yaml`, `melos.yaml`, `tsconfig.base.json`, lint/format
- ✅ `.gitignore` (secrets-safe), `.env.example`, local `.env` with keys
- ✅ `README.md`, `LICENSE`, this `GOAL.md`
- ✅ `packages/ts/contracts` — Zod schemas → JSON Schema → OpenAPI (**verified**: emits 11 paths)
- ✅ `packages/ts/shared` — env parsing, logging, ids, feature flags (**verified**: builds)
- ✅ `packages/ts/db` — Drizzle schema + `infra/sql` migrations (RLS, pgvector) (**verified**: builds)
- ✅ git init on `main` + 4 granular commits

**Acceptance:** ✅ TS packages typecheck; contracts emit a valid OpenAPI doc.

## Stage 1 — Core reading loop  ⬜

- ⬜ Book search (Google Books + Open Library merge)
- ⬜ Reading plan creation + steps
- ⬜ Path screen with unlockable nodes
- ⬜ Nightly step screen + quiz generate/submit
- ⬜ Streak update logic
- ⬜ Offline cache for current step + quiz (drift)

**Acceptance:** add a book → generated path; quiz completion updates streak; step
renders offline after prefetch; admin can inspect a plan + quiz provenance.

## Stage 2 — Grounding & quality layer  ⬜

- ⬜ Gemini grounding pipeline + provenance tables
- ⬜ Confidence scoring + admin review queue
- ⬜ `quizMode` derivation + fallbacks
- ⬜ Groq→Gemini invalid-output retry/fallback

**Acceptance:** every book has a visible grounding status; every fact has source
provenance; low-confidence titles are reviewable; no fake page-specificity.

## Stage 3 — Audio, push & habit reinforcement  ⬜

- ⬜ FCM/APNs registration + send pipeline
- ⬜ Local notification fallback
- ⬜ Deepgram pre-generation + caching (Supabase Storage + `tts_assets`)
- ⬜ `just_audio` playback for recap clips
- ⬜ Bedtime reminder + streak-warning rules

**Acceptance:** nightly reminders deep-link into the correct step; recap clips play
from cache offline; push tokens rotate without duplication.

## Stage 4 — Motion & premium polish  ⬜

- ⬜ Rive streak flame / reward badge states
- ⬜ Lesson card transitions, path-node unlock animations
- ⬜ Reward overlays + haptics
- ⬜ Reduced-motion compliance

**Acceptance:** consistent microinteractions; motion honors "reduce motion"; no
dropped-frame hotspots on core flows.

## Stage 5 — Admin hardening & ops  ⬜

- ⬜ Grounding review queue, plan/quiz QA, TTS cache inspector
- ⬜ Model routing controls, user-support actions
- ⬜ Analytics + tracing dashboards

**Acceptance:** operators can explain why a title grounded the way it did, disable
or regenerate content, and diagnose provider incidents without app rebuilds.

---

## Commit log (high level)

_Updated as we go. Full detail in `git log`._

- `chore: scaffold owlnighter polyglot monorepo`
- `feat(contracts): Zod source-of-truth contracts + OpenAPI generation`
- `feat(shared): env parsing, structured logging, ids, feature flags`
- `feat(db): Drizzle schema + SQL migrations with RLS and pgvector`
- `feat(ai,jobs): provider router (Gemini grounding + Groq) and job layer`
- `feat(api): Fastify server implementing the full contract surface`
- `feat(admin): Next.js grounding-inspection console`
- `feat(mobile): Flutter app + Dart packages (feature-first, motion, offline)`
- `build(infra,ci): Docker, Cloud Run, Firebase, Codemagic, GitHub Actions`
