import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

// build_runner generates database.g.dart from this part directive. Run:
//   dart run build_runner build --delete-conflicting-outputs
// (or `melos run gen`). The .g.dart is intentionally NOT committed here.
part 'database.g.dart';

@DriftDatabase(
  tables: [
    LocalUserBooks,
    LocalPlanSteps,
    LocalQuizInstances,
    LocalSessionEvents,
    LocalPushInbox,
    LocalAudioCache,
    LocalSyncQueue,
  ],
)
class OfflineDatabase extends _$OfflineDatabase {
  OfflineDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  /// Opens the database on a background isolate using the bundled sqlite3
  /// (sqlite3_flutter_libs), so heavy queries never jank the UI thread.
  static QueryExecutor _openConnection() =>
      driftDatabase(name: 'owlnighter_offline');
}
