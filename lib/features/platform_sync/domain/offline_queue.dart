import 'package:material_ui/material_ui.dart';

enum OfflineOperationStatus { pending, inFlight, retryScheduled, succeeded, failed }

class OfflineOperation {
  const OfflineOperation({
    required this.id,
    required this.kind,
    required this.path,
    required this.payload,
    required this.createdAt,
    this.status = OfflineOperationStatus.pending,
    this.attempts = 0,
    this.nextAttemptAt,
    this.lastError,
    this.idempotencyKey,
  });

  final String id;
  final String kind;
  final String path;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final OfflineOperationStatus status;
  final int attempts;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final String? idempotencyKey;

  OfflineOperation copyWith({
    OfflineOperationStatus? status,
    int? attempts,
    DateTime? nextAttemptAt,
    String? lastError,
    bool clearNextAttemptAt = false,
    bool clearLastError = false,
  }) {
    return OfflineOperation(
      id: id,
      kind: kind,
      path: path,
      payload: payload,
      createdAt: createdAt,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: clearNextAttemptAt ? null : nextAttemptAt ?? this.nextAttemptAt,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      idempotencyKey: idempotencyKey,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'path': path,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'attempts': attempts,
    'nextAttemptAt': nextAttemptAt?.toIso8601String(),
    'lastError': lastError,
    'idempotencyKey': idempotencyKey,
  };
}

/// Deterministic exponential backoff; no random state makes retries testable.
class OfflineRetryPolicy {
  const OfflineRetryPolicy({
    this.baseDelay = const Duration(seconds: 2),
    this.multiplier = 2,
    this.maxDelay = const Duration(minutes: 5),
    this.maxAttempts = 5,
  });

  final Duration baseDelay;
  final int multiplier;
  final Duration maxDelay;
  final int maxAttempts;

  Duration delayFor(int failedAttempts) {
    var microseconds = baseDelay.inMicroseconds;
    final factor = multiplier < 1 ? 1 : multiplier;
    for (var attempt = 1; attempt < failedAttempts; attempt++) {
      final scaled = microseconds * factor;
      microseconds = scaled > maxDelay.inMicroseconds
          ? maxDelay.inMicroseconds
          : scaled;
    }
    return Duration(microseconds: microseconds);
  }
}

abstract interface class OfflineQueueStore {
  Future<void> upsert(OfflineOperation operation);

  Future<void> remove(String id);

  Future<List<OfflineOperation>> load();
}

class InMemoryOfflineQueueStore implements OfflineQueueStore {
  final Map<String, OfflineOperation> _operations = {};

  @override
  Future<void> upsert(OfflineOperation operation) async {
    _operations[operation.id] = operation;
  }

  @override
  Future<void> remove(String id) async {
    _operations.remove(id);
  }

  @override
  Future<List<OfflineOperation>> load() async {
    final values = _operations.values.toList()
      ..sort((first, second) => first.createdAt.compareTo(second.createdAt));
    return List.unmodifiable(values);
  }
}

typedef OfflineDispatcher = Future<void> Function(OfflineOperation operation);

/// Owns queue state, visible pending counts, retry and backoff scheduling.
class OfflineQueueCoordinator {
  OfflineQueueCoordinator({
    required this.store,
    this.retryPolicy = const OfflineRetryPolicy(),
    DateTime Function()? now,
    Future<void> Function(Duration)? sleeper,
  }) : _now = now ?? DateTime.now,
       _sleep = sleeper ?? Future.delayed;

  final OfflineQueueStore store;
  final OfflineRetryPolicy retryPolicy;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _sleep;
  final ValueNotifier<List<OfflineOperation>> operations = ValueNotifier(
    const <OfflineOperation>[],
  );

  int get pendingCount => operations.value
      .where(
        (operation) =>
            operation.status == OfflineOperationStatus.pending ||
            operation.status == OfflineOperationStatus.inFlight ||
            operation.status == OfflineOperationStatus.retryScheduled,
      )
      .length;

  Future<void> refresh() async {
    operations.value = await store.load();
  }

  Future<OfflineOperation> enqueue({
    required String kind,
    required String path,
    required Map<String, Object?> payload,
    String? idempotencyKey,
    DateTime? createdAt,
  }) async {
    final operation = OfflineOperation(
      id: idempotencyKey ?? '$kind-${(createdAt ?? _now()).microsecondsSinceEpoch}',
      kind: kind,
      path: path,
      payload: Map.unmodifiable(payload),
      createdAt: createdAt ?? _now(),
      idempotencyKey: idempotencyKey,
    );
    await store.upsert(operation);
    await refresh();
    return operation;
  }

  bool isDue(OfflineOperation operation, DateTime at) {
    if (operation.status == OfflineOperationStatus.pending) return true;
    if (operation.status != OfflineOperationStatus.retryScheduled) return false;
    final next = operation.nextAttemptAt;
    return next != null && !next.isAfter(at);
  }

  Future<void> _persist(OfflineOperation operation) async {
    await store.upsert(operation);
    await refresh();
  }

  Future<int> drain(OfflineDispatcher dispatch) async {
    await refresh();
    final due = operations.value.where((item) => isDue(item, _now())).toList();
    var sent = 0;
    for (final operation in due) {
      await _persist(operation.copyWith(status: OfflineOperationStatus.inFlight));
      try {
        await dispatch(operation);
        await store.remove(operation.id);
        sent++;
      } catch (error) {
        final attempts = operation.attempts + 1;
        final exhausted = attempts >= retryPolicy.maxAttempts;
        await _persist(
          operation.copyWith(
            attempts: attempts,
            status: exhausted
                ? OfflineOperationStatus.failed
                : OfflineOperationStatus.retryScheduled,
            nextAttemptAt: exhausted
                ? null
                : _now().add(retryPolicy.delayFor(attempts)),
            lastError: error.toString(),
          ),
        );
      }
    }
    await refresh();
    return sent;
  }

  /// User-initiated retry: clears backoff and attempt counts for failed work.
  Future<int> retryAllNow(OfflineDispatcher dispatch) async {
    final items = await store.load();
    for (final operation in items) {
      if (operation.status == OfflineOperationStatus.retryScheduled ||
          operation.status == OfflineOperationStatus.failed) {
        await store.upsert(
          operation.copyWith(
            status: OfflineOperationStatus.pending,
            attempts: 0,
            clearNextAttemptAt: true,
            clearLastError: true,
          ),
        );
      }
    }
    await refresh();
    return drain(dispatch);
  }

  /// Optional polling loop; injectable sleep keeps tests deterministic.
  Future<void> startPolling({
    required OfflineDispatcher dispatch,
    Duration interval = const Duration(seconds: 30),
  }) async {
    while (true) {
      await drain(dispatch);
      await _sleep(interval);
    }
  }
}
