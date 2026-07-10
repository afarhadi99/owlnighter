# Testing — every suite and how to run it

This is the one-stop list of everything that gets tested in this repo, and the
exact command for each. All of these run in CI (`.github/workflows/ci.yml`);
the sections below are how to run the same checks locally.

## 1. Backend — `apps/api` (63 tests)

Plain `node:test` via `tsx`, no Postgres or network access required — these are
unit and inject-based smoke tests against an in-process Fastify instance.

```bash
pnpm --filter @owlnighter/api test
```

Related, also blocking in CI:

```bash
pnpm -r build       # every TS/Next workspace builds
pnpm -r typecheck    # every TS workspace typechecks

# OpenAPI is generated from Zod schemas in packages/ts/contracts and committed
# at packages/ts/contracts/openapi.json (currently 18 paths). Regenerate and
# diff after any contract change:
pnpm contracts:openapi
git diff --exit-code -- packages/ts/contracts/openapi.json
```

## 2. Dart / Flutter — 70 tests across 4 packages

Each Dart package is independent (no melos required for CI — `flutter pub get`
per package is enough). Run `dart format`, `flutter analyze`, then `flutter
test` in each:

```bash
# apps/mobile — widget + unit tests for the reader app
cd apps/mobile
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test

# packages/dart/app_core — shared models/state (models_test.dart)
cd packages/dart/app_core
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test

# packages/dart/offline — drift cache + sync queue
cd packages/dart/offline
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test

# packages/dart/design_system — widget tests (path_node, progress_ring,
# reward_button, streak_flame)
cd packages/dart/design_system
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test

# packages/dart/api_client — generated-client wrapper, no test/ directory yet:
# analyze-only.
cd packages/dart/api_client
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
```

CI runs this as a matrix over the five package paths above and skips the
`flutter test` step for any package with no `test/` directory (currently only
`api_client`).

> An Android APK build (`flutter build apk`) is intentionally **not** part of
> CI — it's a multi-minute Gradle/AGP cold start that's too slow for every
> push/PR. It's a good candidate for a separate, less-frequent release
> workflow later.

## 3. Admin console — `apps/admin`

No automated test suite yet; the check that matters today is that it still
builds and typechecks (both covered by the root `pnpm -r build` /
`pnpm -r typecheck` above). To sanity-check the live pages manually:

```bash
pnpm dev:admin   # http://localhost:3001, talks to the same API as the mobile app
```

## 4. Live end-to-end (manual) — the real reading loop

For exercising the actual API against a local Postgres with live Gemini/Groq
keys (search → ground → library → plan → quiz → submit → streak), follow
**[`docs/local-dev.md`](local-dev.md)** step by step. This is not part of CI
(it needs real API keys and a running Postgres) — run it locally before/after
touching the AI or plan/quiz flow.

## 5. On-device smoke test (manual)

To confirm a change works in the actual Flutter app on an emulator/device
against the live local API:

1. Bring up the API locally per `docs/local-dev.md` (steps 1–4), so it's
   listening on `localhost:8787`.
2. From `apps/mobile`, run codegen once if you haven't (`melos run gen` — see
   `apps/mobile/README.md`), then:
   ```bash
   flutter run \
     --dart-define=API_BASE_URL=http://10.0.2.2:8787 \
     --dart-define=APP_LINK_HOST=app.example.com
   ```
3. **`10.0.2.2` is the Android emulator's alias for the host machine's
   loopback** — it is *not* a typo and won't work on a physical device on a
   different network (point it at your machine's LAN IP instead) or on iOS
   simulator (use `http://localhost:8787` there).
4. Confirm dev auth works (the app should load the seeded dev user's library
   with real book titles), then walk the loop: open a book → plan generates
   (or loads, if already generated) → read a step → take the quiz → streak
   increments.
