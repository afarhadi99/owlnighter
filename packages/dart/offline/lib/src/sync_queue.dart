import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

/// Outcome of attempting a single queued operation.
enum SyncOutcome {
  /// Applied server-side; drop the row.
  success,

  /// Transient failure (offline, 5xx); keep the row and back off.
  retry,

  /// Permanent failure (validation/4xx); drop the row so we don't loop forever.
  drop,
}

/// A queued mutation handed to the caller's handler.
class SyncOp {
  const SyncOp({
    required this.id,
    required this.operation,
    required this.payload,
    required this.idempotencyKey,
    required this.attempts,
  });

  final int id;
  final String operation;
  final Map<String, dynamic> payload;
  final String idempotencyKey;
  final int attempts;
}

/// Signature the app provides to actually perform an operation against the API.
typedef SyncHandler = Future<SyncOutcome> Function(SyncOp op);

/// Drains [LocalSyncQueue] in FIFO order when connectivity returns.
///
/// This orchestrator owns *ordering, retry, and backoff* but is deliberately
/// ignorant of HTTP: the app wires a [SyncHandler] that maps `operation` names
/// to `OwlnighterApi` calls. That keeps the offline package free of a Dio
/// dependency and makes the queue unit-testable with a fake handler.
class SyncQueue {
  SyncQueue({
    required this.db,
    required this.handler,
    this.maxAttempts = 6,
  });

  final OfflineDatabase db;
  final SyncHandler handler;
  final int maxAttempts;

  bool _draining = false;

  /// Enqueue an intent. [idempotencyKey] MUST be stable across retries so the
  /// server can dedupe (e.g. a client-generated uuid for the mutation).
  Future<void> enqueue({
    required String operation,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  }) async {
    await db.into(db.localSyncQueue).insert(
          LocalSyncQueueCompanion.insert(
            operation: operation,
            payloadJson: jsonEncode(payload),
            idempotencyKey: idempotencyKey,
            createdAt: DateTime.now(),
          ),
        );
  }

  /// Number of pending operations. Useful for a "syncing…" badge.
  Future<int> pendingCount() async {
    final count = db.localSyncQueue.id.count();
    final row = await (db.selectOnly(db.localSyncQueue)..addColumns([count]))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Attempt to flush the queue. Safe to call repeatedly (e.g. on connectivity
  /// regained, on app resume); concurrent calls are coalesced.
  Future<void> drain() async {
    if (_draining) return;
    _draining = true;
    try {
      final now = DateTime.now();
      final rows = await (db.select(db.localSyncQueue)
            ..where((t) =>
                t.nextAttemptAt.isSmallerOrEqualValue(now) |
                t.nextAttemptAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

      for (final row in rows) {
        final op = SyncOp(
          id: row.id,
          operation: row.operation,
          payload: jsonDecode(row.payloadJson) as Map<String, dynamic>,
          idempotencyKey: row.idempotencyKey,
          attempts: row.attempts,
        );

        SyncOutcome outcome;
        String? error;
        try {
          outcome = await handler(op);
        } catch (e) {
          outcome = SyncOutcome.retry;
          error = e.toString();
        }

        switch (outcome) {
          case SyncOutcome.success:
          case SyncOutcome.drop:
            await (db.delete(db.localSyncQueue)
                  ..where((t) => t.id.equals(row.id)))
                .go();
          case SyncOutcome.retry:
            final attempts = row.attempts + 1;
            if (attempts >= maxAttempts) {
              // Give up: drop so the queue can't wedge on a poison message.
              await (db.delete(db.localSyncQueue)
                    ..where((t) => t.id.equals(row.id)))
                  .go();
            } else {
              await (db.update(db.localSyncQueue)
                    ..where((t) => t.id.equals(row.id)))
                  .write(
                LocalSyncQueueCompanion(
                  attempts: Value(attempts),
                  lastError: Value(error),
                  nextAttemptAt: Value(now.add(_backoff(attempts))),
                ),
              );
              // Stop draining on first transient failure to preserve ordering.
              return;
            }
        }
      }
    } finally {
      _draining = false;
    }
  }

  /// Exponential backoff capped at 5 minutes.
  Duration _backoff(int attempts) {
    final seconds = (1 << attempts).clamp(1, 300);
    return Duration(seconds: seconds);
  }
}
