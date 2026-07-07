# owlnighter — Flutter app

The reader-facing mobile app. A nightly reading-habit loop with Duolingo-style
motion: read tonight's step → take a short quiz → keep your streak.

## Prerequisites (codegen + deps)

The Flutter SDK is required. This tree was authored by hand; before it will
analyze or run you MUST fetch deps and run codegen:

```bash
# From the Dart workspace root (melos):
melos bootstrap          # or: dart pub get in each package

# Generate Drift database code (packages/dart/offline/lib/src/database.g.dart):
melos run gen            # runs build_runner with --delete-conflicting-outputs
#   or, in packages/dart/offline:
#   dart run build_runner build --delete-conflicting-outputs

# Run the app (point API_BASE_URL at your local Fastify API):
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8787 \
  --dart-define=APP_LINK_HOST=app.example.com
```

> `10.0.2.2` is the Android emulator's alias for the host loopback. On iOS
> simulator use `http://localhost:8787`.

`database.g.dart` is intentionally not committed — it is generated output.

## Architecture

Layered (UI → Logic → Data), feature-first. The app is the composition root
that wires the workspace packages together:

| Package | Responsibility |
| --- | --- |
| `design_system` | tokens, theme, motion primitives (RewardButton, PathNode, ProgressRing, StreakFlame, AnimatedCardSwitcher, XpBurst) |
| `app_core` | immutable domain models + repository interfaces + session (pure Dart) |
| `api_client` | Dio client with typed methods per API endpoint + bearer interceptor |
| `offline` | Drift database (offline stores) + SyncQueue orchestrator |

```text
lib/
  bootstrap/   main() + ProviderScope + guarded error zone + session restore
  app/         App widget, go_router config, bottom-nav shell
  features/    auth, onboarding, library, reading_path, nightly_session,
               quiz, streaks, audio, notifications, settings, admin_debug
               (each: presentation widgets + a Riverpod controller)
  services/    api (providers + repo impls), push, deep_links, analytics,
               offline_sync
  shared/      widgets, motion re-exports, theme re-exports, util
```

### State & data flow

- **Riverpod** for state. Features depend only on interface-typed repository
  providers (`libraryRepositoryProvider`, `planRepositoryProvider`,
  `quizRepositoryProvider`), never on the API client or Drift directly.
- **Repositories over services**: `services/api/repositories_impl.dart`
  composes the network client with the offline cache. Reads are offline-first;
  mutations that must survive offline go through the `SyncQueue`.
- **Session**: `SessionController` (in `app_core`) holds the `AuthSession`;
  tokens are persisted only via `flutter_secure_storage`. The API client reads
  the bearer token lazily so a refresh is always reflected.

### The core loop

`reading_path` (scrollable `CustomPainter` serpentine map of unlockable nodes)
→ `nightly_session` (tonight's step + recap audio, offline-first from the
prefetched cache) → `quiz` (`AnimatedCardSwitcher` between questions) →
`streaks` (flame mascot + XP burst celebration).

### Deep links

One entry path via `go_router` for push opens, email links, and admin
"open on device":

- Universal/app links: `https://<APP_LINK_HOST>/plan/{planId}/step/{stepId}`
- Native scheme: `readingpath://plan/{planId}/step/{stepId}`

`services/deep_links/deep_links.dart` normalizes inbound URIs to a router
location. Native platform config (Android `intent-filter`, iOS associated
domains + `CFBundleURLTypes`) must still be added under `android/` and `ios/`.

### Motion & accessibility

All motion primitives live in `design_system` and respect
`MediaQuery.disableAnimations` (reduced motion). Rive powers the stateful
streak flame (`assets/rive/streak_flame.riv`, not yet bundled — a static
placeholder renders until it ships).

## Known seams (need backend/native wiring)

- Auth token exchange / refresh (`AuthRepositoryImpl` TODOs) — backend owns the
  endpoints; persistence + `SessionController` side is implemented.
- Firebase init + `PushService.init()` are gated out of bootstrap until native
  Firebase config is added.
- `TODO` in `api_client`: replace the hand-written client with the
  OpenAPI-generated dart-dio client from `packages/ts/contracts/openapi.json`.
- No list-library / plan-by-book read endpoints in the contract yet; the
  library tab is cache-backed.
