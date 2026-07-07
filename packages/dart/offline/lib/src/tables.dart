import 'package:drift/drift.dart';

/// Drift table definitions for the offline-first store.
///
/// Design rule from the blueprint: "the nightly session must work offline after
/// content is prefetched." So the current step, its quiz contract, recap audio,
/// and a slice of plan metadata are all persisted locally and mutations are
/// enqueued for later sync. JSON payloads are stored as text columns to stay
/// resilient to contract evolution without a migration per field.

/// Books the user has added, cached for offline library rendering.
class LocalUserBooks extends Table {
  TextColumn get id => text()(); // user_book id (uuid)
  TextColumn get bookId => text()();
  TextColumn get status => text()(); // UserBookStatus.wire
  IntColumn get currentPage => integer().nullable()();
  IntColumn get targetNightlyPages => integer().nullable()();
  TextColumn get bookJson => text().nullable()(); // cached Book identity
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Steps of the active plan(s), one row per step. Enough to render the path map
/// and start tonight's session offline.
class LocalPlanSteps extends Table {
  TextColumn get stepId => text()();
  TextColumn get planId => text()();
  IntColumn get stepIndex => integer()();
  TextColumn get status => text()(); // StepStatus.wire
  TextColumn get stepJson => text()(); // full PlanStep payload
  DateTimeColumn get unlocksAt => dateTime().nullable()();
  TextColumn get ttsAssetId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {stepId};
}

/// Prefetched quiz contracts so the quiz can be taken with no network.
class LocalQuizInstances extends Table {
  TextColumn get quizId => text()();
  TextColumn get stepId => text()();
  TextColumn get quizMode => text()();
  TextColumn get quizJson => text()(); // full QuizInstance payload
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {quizId};
}

/// Analytics / behavioral events captured locally, flushed opportunistically.
class LocalSessionEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get eventType => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get occurredAt => dateTime()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

/// Received push notifications, so the app can render an inbox and reconcile
/// deep-link opens even when it was offline at delivery time.
class LocalPushInbox extends Table {
  TextColumn get messageId => text()();
  TextColumn get title => text().nullable()();
  TextColumn get body => text().nullable()();
  TextColumn get deepLink => text().nullable()();
  TextColumn get dataJson => text().nullable()();
  DateTimeColumn get receivedAt => dateTime()();
  BoolColumn get read => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {messageId};
}

/// Local file references for prefetched TTS audio, keyed by content hash so we
/// never re-download identical audio.
class LocalAudioCache extends Table {
  TextColumn get assetKey => text()(); // hash of text + voice params
  TextColumn get assetId => text().nullable()();
  TextColumn get stepId => text().nullable()();
  TextColumn get localPath => text()(); // on-device file path
  IntColumn get durationMs => integer().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {assetKey};
}

/// The outbound mutation queue. Each row is an intent to call the API; the
/// SyncQueue drains it in FIFO order when connectivity returns.
class LocalSyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Logical operation name, e.g. "submitQuiz", "addLibraryBook".
  TextColumn get operation => text()();

  /// JSON-encoded arguments for the operation.
  TextColumn get payloadJson => text()();

  /// Idempotency key so a retried op is not applied twice server-side.
  TextColumn get idempotencyKey => text()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
}
