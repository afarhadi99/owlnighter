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
| Flutter / Dart SDK | ✅ 3.44.5 / Dart 3.12.2 | installed; **builds Android debug APK** |
| Android SDK | ✅ build-capable | platforms 34/36, build-tools ≤36.1.0, AVD `Medium_Phone` |
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
| Flutter app + Dart pkgs | `apps/mobile` + `packages/dart/*` | ✅ **runs on emulator** · dev-auth + live API (library loads) · APK builds · analyze-clean · widget tests pass |
| Infra (Docker/CloudRun/FCM) | `infra/*` | 🟡 authored — YAML valid, not deployed |
| CI (GitHub Actions) | `.github/workflows` | ✅ mirrors local green checks |

**Full-workspace `pnpm -r build`: green (all 8 TS/Next projects).**

### End-to-end verification (2026-07-08)

Ran the real API against local Postgres (`:55432`) + live Gemini/Groq keys. The
**entire reading loop passed**: `books/search` (Google Books + Open Library merge)
→ `books/ground` (Gemini, confidence 0.95, `pageLevelUnsafe` honoured) →
`library/books` → `plans/generate` (Gemini, real chapters) → `steps/:id/quiz`
(router auto-fell-back Groq→Gemini) → `quiz/:id/submit` → **passed 4/4, streak=1,
+20 XP**. Two real bugs found + fixed along the way (grounded-prompt shape;
missing book identity in the plan prompt). See `docs/local-dev.md` to reproduce.

### Round 2 — parallel testing + implementation (2026-07-09)

Fanned out 3 agents on disjoint domains (opus/high for mobile + backend,
sonnet/medium for admin). Results, all **verified by the controller**:
- **Mobile:** Android platform generated; **`flutter build apk --debug` → 212 MB APK**;
  11 widget tests pass; analyze clean. Android SDK now build-capable (AVD present).
- **Backend:** 5 new endpoints (openapi now **15 paths**) — library list, step-start,
  admin metrics/tts/quiz-invalidate; migration `0003` (quiz invalidation); Deepgram
  TTS wired with graceful 503. **15/15 node:test** pass; all 5 endpoints exercised
  **live against Postgres** (200s).
- **Admin:** Overview + TTS inspector + Quiz-QA wired to the live endpoints; `next build` compiles.

### Round 3 — runs on device (2026-07-10)

Fanned out 3 more agents (opus/high mobile + backend, sonnet/med admin).
- **Mobile:** dev-auth + `10.0.2.2` emulator host + core loop wired to real repos.
  **VERIFIED ON DEVICE (emulator-5554):** app launches → boots past auth →
  `GET /healthz` + `GET /v1/library/books` return **200 over 10.0.2.2** → the
  seeded book renders in "Your library". analyze clean; 7 widget tests pass; APK builds.
- **Backend:** `GET /v1/admin/plans`, `GET /v1/admin/quizzes`, FCM HTTP v1 push
  (service-account JWT via node:crypto, graceful `not_configured`), `POST
  /v1/admin/push/test`. openapi now **18 paths**; **20/20** tests.
- **Admin:** Plans QA + Quiz QA wired to the live list endpoints.
- Known follow-up: the library-list endpoint returns book ids, not titles — the
  card shows "Book 3ce25e75". Enrich `LibraryBooksResponse` with title/author/cover.

### Round 4 — Phase 4 + test-all (2026-07-10)

Fanned out 3 agents (opus/high backend + mobile, sonnet/med admin), then a full
controller regression + live e2e + on-device drive.
- **Library enriched** (title/author/cover via join) — VERIFIED on emulator:
  the card now reads "The Left Hand of Darkness / Ursula K. Le Guin".
- **Tests added:** backend **63** (inject tests for every endpoint + units) and
  **70 dart** (app_core round-trips, offline cache/SyncQueue, widgets). Full
  regression green: `pnpm -r build`+typecheck, 63 api tests, 5-pkg analyze, 70
  flutter tests, APK builds.
- **Backend fix (found by testing):** `DEV_USER_ID` wasn't a valid UUID → `z.uuid()`
  rejected it in bodies (push/test 400). Changed to a valid v4 across the codebase;
  migrated the seeded dev data; push/test now validates + degrades cleanly.
- **Admin:** notifications "send test push"; honest states elsewhere.
- **⚠️ On-device finding:** plan generation via Gemini took **~58s** (v3 persisted
  server-side), which **exceeds the mobile Dio timeout** — the book-tap spins then
  silently returns to Library without navigating, and the app **regenerates a plan
  on every open** (no get-or-create). Top phase-5 item: make plan generation
  async/faster + get-or-create + a real loading/error state on the path screen.

### Round 5 — THE FULL LOOP RUNS ON DEVICE (2026-07-10)

Fanned out 3 agents (backend get-or-create + Groq-first plans; mobile launcher
UX + motion; CI/docs hardening), then drove the complete loop on emulator-5554:

**library (title) → path map (opened in <1s via plan reuse — was 58s timeout) →
nightly session (`steps/:id/start` 200) → 4-question Gemini quiz about the real
book (Genly Ai, the Ekumen, kemmering, the ice) → submit 200 →
"Nice reading tonight!" 4/4 correct · 🔥 1-day streak · ⚡ +20 XP.**

- `GET /v1/plans?bookId=` + `ifExists:"reuse"` (default): live reuse in **292ms**,
  no AI call. Plans now Groq-first (blueprint two-pass), Gemini fallback.
- Mobile PlanLauncher: instant open for existing plans; "Crafting your nightly
  path…" + retryable error for fresh ones. 74 dart tests (4 new).
- CI: Flutter analyze/test now **blocking** across all packages; api suite in CI.
- Suites: **68 backend + 74 dart tests green**; openapi **19 paths**; APK builds.

**Stage 1 (core reading loop) acceptance is now fully verified on device.**
Stage 4 (motion) partially verified live: path nodes, card transitions,
celebration + haptics. Remaining: Rive flame asset, XP overlay flourish,
frame profiling.

### Round 6 — SVG art + sound (2026-07-12)

Delegated to opus (design_system art → mobile SFX/integration pipeline) and
sonnet (admin), then verified on device:
- **design_system/art:** five SVG-path CustomPainter widgets — NightSky (seeded
  twinkling stars + crescent moon), OwlMascot (idle/cheer/sleepy — the mascot
  exists!), FlameFlicker (3-layer organic flame; StreakFlame now delegates to it,
  Rive placeholder retired), ConfettiBurst (physics particles), PathScenery.
  All reduced-motion safe. +20 widget tests (suite 33).
- **mobile:** six original synthesized WAV SFX (tools/gen_sfx.mjs) + SfxService
  with a persisted Settings toggle; art wired into path map (night sky + moon),
  nightly (sleepy owl), quiz (tap/correct/wrong cues), celebration (confetti +
  cheering owl + flame + fanfare). Dart suite now **106 tests**.
- **admin:** inline-SVG blinking OwlLogo, count-up StatTiles, orbiting-star
  spinner, WebAudio chimes (no assets), reduced-motion + mute respected.
- **ON DEVICE:** starfield path map with the wave-5 chapter shown as a green ✓
  node, sleepy owl on the nightly screen, and a real 4/4 pass ending in the
  cheering owl + flame celebration (submit 200; streak intact).
- Known cosmetic follow-up: NightSky on the nightly screen covers only the top
  content area (bottom half plain) — extend the backdrop to full height.

### Round 7 — user audit: "far from Duolingo" (2026-07-12)

User audit (on-device, every screen) called out real gaps: cheap synthesized
sounds, no per-question feedback (batch-only quiz), the celebration sheet
**dead-ended** instead of returning to the path, streak tab hardcoded to 0,
flat non-tactile UI, dead Settings rows, bare add-book search results.
Fanned out sonnet (backend) + opus (design-system → mobile pipeline), fixed
every finding, verified **on device end-to-end**:

- **Backend:** `GET /v1/me/stats` (real streak/XP/7-day week) + `POST
  /v1/quiz/:id/check` (instant per-question verdict, key stays server-side;
  final `submit` unchanged). 74/74 tests, openapi 21 paths.
- **design_system "juice kit":** ChunkyButton (3D pressed-edge), PathNode v2
  (glow + bobbing START callout + green-check completed + amber in-progress
  arc), FeedbackBanner, JuicyProgressBar, XpCounter, StatCard. 54 tests.
- **mobile:** sound synthesis rewritten (detuned ensembles, harmonic-partial
  decay physics, lowpass, echo, saturation — still fully original/synthesized);
  quiz is now select→CHECK→banner+SFX→CONTINUE per question; a real full-screen
  **CompletionPage** (confetti/owl/XP roll-up/stat cards) whose CONTINUE
  **returns to Library and refreshes the plan**; streak tab hydrated; nightly
  sky full-height; Settings/add-book/library polish. 42 mobile tests (dart
  total **137**).
- **VERIFIED ON DEVICE, full loop, this round:** tapped an available path node
  → 4 questions each with live CHECK → green/red FeedbackBanner → CONTINUE →
  **CompletionPage** (100% accuracy, +20 XP, streak 1) → CONTINUE → **Library**
  → re-opened path → **finished node green, next node glowing START**. The
  "doesn't go anywhere" complaint is closed.

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

## Stage 1 — Core reading loop  🟡 (API path verified e2e; Flutter UI unrun)

- ✅ Book search (Google Books + Open Library merge) — **verified**
- ✅ Reading plan creation + steps — **verified** (real chapters)
- 🟡 Path screen with unlockable nodes — Flutter authored, not compiled
- ✅ Nightly step → quiz generate/submit — **verified** end-to-end
- ✅ Streak update logic — **verified** (streak=1, +20 XP on pass)
- 🟡 Offline cache for current step + quiz (drift) — Flutter authored, needs codegen

**Acceptance:** ✅ add a book → generated path; ✅ quiz completion updates streak.
Remaining: offline render (Flutter) + admin plan/quiz-provenance inspection UI wiring.

## Stage 2 — Grounding & quality layer  🟡 (pipeline verified)

- ✅ Gemini grounding pipeline + provenance tables — **verified** (persists runs/sources/facts)
- ✅ Confidence scoring + buckets (auto/review/limited) — **verified**
- ✅ `quizMode` derivation + clamping to grounding guarantee — **verified** (`fallback` when weak)
- ✅ Groq→Gemini invalid-output retry/fallback — **verified** (quiz fell back automatically)
- 🟡 Admin review-queue UI — page exists, list endpoints still TODO

**Acceptance:** ✅ books carry a grounding status; ✅ facts have source provenance;
✅ no fake page-specificity (`pageLevelUnsafe` → `partial`/`fallback`). Admin
review-queue wiring remains.

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
- `fix(ai,api): grounded-prompt shape + book identity in plan prompt`
- `chore(dev): local Postgres harness (auth shim + seed) and docs`
- `docs(goal): record end-to-end verification of the reading loop`
- `fix(mobile): Flutter analyze-clean across app + all Dart packages`
- `docs(goal): Flutter SDK installed; app + packages analyze-clean`
- `feat(api): library list, step-start, admin metrics/tts/quiz-invalidate + Deepgram TTS + tests`
- `feat(admin): wire Overview, TTS inspector, and Quiz QA to live endpoints`
- `feat(mobile): Android platform + debug APK builds; widget tests`
- `docs(goal): record round-2 (Android APK build, 5 endpoints, admin wiring)`
- `feat(api,jobs): admin plan/quiz lists + FCM push pipeline`
- `feat(admin): wire Plans QA + Quiz QA to live list endpoints`
- `feat(mobile): dev-auth + emulator host — core loop runs against live API`
- `docs(goal): record round-3 — app runs on emulator against live API`
- `feat(api): enrich library list + comprehensive backend tests; fix dev user UUID`
- `feat(mobile): library titles, navigable loop, offline prefetch, audio + tests`
- `feat(admin): notifications send-test-push + honest states on remaining pages`
