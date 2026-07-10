import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline/offline.dart';

/// SyncQueue ordering, retry/backoff, poison-drop, and success semantics,
/// driven by a programmable fake handler over an in-memory sqlite.
void main() {
  late OfflineDatabase db;

  setUp(() => db = OfflineDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// A handler whose outcome is chosen per-operation-name, recording the order
  /// in which ops were attempted.
  ({SyncQueue queue, List<String> seen}) makeQueue(
    Map<String, SyncOutcome> outcomes, {
    int maxAttempts = 6,
  }) {
    final seen = <String>[];
    final queue = SyncQueue(
      db: db,
      maxAttempts: maxAttempts,
      handler: (op) async {
        seen.add(op.operation);
        return outcomes[op.operation] ?? SyncOutcome.success;
      },
    );
    return (queue: queue, seen: seen);
  }

  Future<void> enqueue(SyncQueue q, String op) => q.enqueue(
        operation: op,
        payload: {'op': op},
        idempotencyKey: 'key-$op',
      );

  test('enqueue increments the pending count', () async {
    final h = makeQueue(const {});
    expect(await h.queue.pendingCount(), 0);
    await enqueue(h.queue, 'a');
    await enqueue(h.queue, 'b');
    expect(await h.queue.pendingCount(), 2);
  });

  test('drains successful ops in FIFO order and empties the queue', () async {
    final h = makeQueue(const {});
    await enqueue(h.queue, 'first');
    await enqueue(h.queue, 'second');
    await enqueue(h.queue, 'third');

    await h.queue.drain();

    expect(h.seen, ['first', 'second', 'third']);
    expect(await h.queue.pendingCount(), 0);
  });

  test('a dropped (permanent-failure) op is removed, not retried', () async {
    final h = makeQueue({'bad': SyncOutcome.drop});
    await enqueue(h.queue, 'bad');
    await h.queue.drain();
    expect(await h.queue.pendingCount(), 0);
  });

  test('a transient failure keeps the op and stops draining to preserve order',
      () async {
    final h = makeQueue({'a': SyncOutcome.retry});
    await enqueue(h.queue, 'a');
    await enqueue(h.queue, 'b');

    await h.queue.drain();

    // Only 'a' was attempted; draining halted so 'b' keeps its place behind it.
    expect(h.seen, ['a']);
    expect(await h.queue.pendingCount(), 2);

    final rowA = await (db.select(db.localSyncQueue)
          ..where((t) => t.operation.equals('a')))
        .getSingle();
    expect(rowA.attempts, 1);
    expect(rowA.nextAttemptAt, isNotNull); // backoff scheduled
  });

  test('backoff gates re-attempts until nextAttemptAt has passed', () async {
    final h = makeQueue({'a': SyncOutcome.retry});
    await enqueue(h.queue, 'a');
    await h.queue.drain(); // attempt 1 -> schedules future nextAttemptAt

    // Immediately draining again must NOT re-attempt (still backing off).
    await h.queue.drain();
    expect(h.seen, ['a']);

    // Simulate time passing by clearing the backoff gate.
    await (db.update(db.localSyncQueue)).write(
      const LocalSyncQueueCompanion(nextAttemptAt: Value<DateTime?>(null)),
    );
    await h.queue.drain();
    expect(h.seen, ['a', 'a']); // now re-attempted
  });

  test('poison message is dropped once maxAttempts is reached', () async {
    // maxAttempts=1 => the first retry pushes attempts to 1 >= 1 => drop.
    final h = makeQueue({'poison': SyncOutcome.retry}, maxAttempts: 1);
    await enqueue(h.queue, 'poison');

    await h.queue.drain();

    expect(h.seen, ['poison']);
    expect(await h.queue.pendingCount(), 0); // dropped, queue not wedged
  });

  test('a handler that throws is treated as a transient retry', () async {
    var calls = 0;
    final queue = SyncQueue(
      db: db,
      maxAttempts: 6,
      handler: (op) async {
        calls++;
        throw StateError('network blew up');
      },
    );
    await queue.enqueue(
      operation: 'x',
      payload: const {},
      idempotencyKey: 'k',
    );
    await queue.drain();

    expect(calls, 1);
    // Kept for a later retry with the error recorded.
    final row = await db.select(db.localSyncQueue).getSingle();
    expect(row.attempts, 1);
    expect(row.lastError, contains('network blew up'));
  });

  test('the payload and idempotency key survive the round-trip to the handler',
      () async {
    Map<String, dynamic>? gotPayload;
    String? gotKey;
    final queue = SyncQueue(
      db: db,
      handler: (op) async {
        gotPayload = op.payload;
        gotKey = op.idempotencyKey;
        return SyncOutcome.success;
      },
    );
    await queue.enqueue(
      operation: 'submitQuiz',
      payload: {'quizId': 'qi1', 'answers': []},
      idempotencyKey: 'idem-123',
    );
    await queue.drain();

    expect(gotPayload, {'quizId': 'qi1', 'answers': []});
    expect(gotKey, 'idem-123');
  });
}
