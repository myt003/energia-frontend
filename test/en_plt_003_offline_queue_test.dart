import 'package:energia/core/theme/energia_theme.dart';
import 'package:energia/features/platform_sync/domain/offline_queue.dart';
import 'package:energia/features/platform_sync/presentation/offline_queue_indicator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('backoff is deterministic and capped', () {
    const policy = OfflineRetryPolicy(
      baseDelay: Duration(seconds: 2),
      multiplier: 2,
      maxDelay: Duration(seconds: 10),
      maxAttempts: 4,
    );
    expect(policy.delayFor(1), const Duration(seconds: 2));
    expect(policy.delayFor(2), const Duration(seconds: 4));
    expect(policy.delayFor(3), const Duration(seconds: 8));
    expect(policy.delayFor(4), const Duration(seconds: 10));
  });

  test('queue retries with backoff and clears pending after success', () async {
    final start = DateTime(2026, 11, 22, 9);
    var now = start;
    final coordinator = OfflineQueueCoordinator(
      store: InMemoryOfflineQueueStore(),
      now: () => now,
      sleeper: (duration) async {},
    );

    final operation = await coordinator.enqueue(
      kind: 'form_submission',
      path: '/me/tasks/task-1/submissions/',
      payload: const {'idempotency_key': 'form-1'},
      idempotencyKey: 'queue-1',
      createdAt: start,
    );
    expect(operation.status, OfflineOperationStatus.pending);
    expect(coordinator.pendingCount, 1);

    var attempts = 0;
    final failed = await coordinator.drain((item) async {
      attempts++;
      throw StateError('offline');
    });
    expect(failed, 0);
    var retry = coordinator.operations.value.single;
    expect(retry.status, OfflineOperationStatus.retryScheduled);
    expect(retry.attempts, 1);
    expect(retry.nextAttemptAt, start.add(const Duration(seconds: 2)));
    expect(retry.lastError, contains('offline'));
    expect(coordinator.pendingCount, 1);

    now = retry.nextAttemptAt!;
    final sent = await coordinator.drain((item) async {
      attempts++;
      expect(item.idempotencyKey, 'queue-1');
    });
    expect(sent, 1);
    expect(attempts, 2);
    expect(coordinator.pendingCount, 0);
    expect(coordinator.operations.value, isEmpty);
  });

  test('user retry resets exhausted backoff state', () async {
    final start = DateTime(2026, 11, 22, 9);
    var now = start;
    final coordinator = OfflineQueueCoordinator(
      store: InMemoryOfflineQueueStore(),
      retryPolicy: const OfflineRetryPolicy(maxAttempts: 1),
      now: () => now,
      sleeper: (duration) async {},
    );
    await coordinator.enqueue(
      kind: 'evidence',
      path: '/me/evidence/',
      payload: const {},
      idempotencyKey: 'evidence-1',
      createdAt: start,
    );
    await coordinator.drain((item) async => throw StateError('offline'));
    expect(coordinator.operations.value.single.status, OfflineOperationStatus.failed);

    final sent = await coordinator.retryAllNow((item) async {});
    expect(sent, 1);
    expect(coordinator.pendingCount, 0);
  });

  testWidgets('indicator exposes pending count and retry control', (tester) async {
    final coordinator = OfflineQueueCoordinator(
      store: InMemoryOfflineQueueStore(),
      now: () => DateTime(2026, 11, 22, 9),
      sleeper: (duration) async {},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: EnergiaTheme.light,
        home: Scaffold(
          body: OfflineQueueIndicator(
            coordinator: coordinator,
            onRetry: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('offline-all-synced')), findsOneWidget);

    await coordinator.enqueue(
      kind: 'form_submission',
      path: '/me/submissions/',
      payload: const {'idempotency_key': 'f-1'},
      idempotencyKey: 'queue-2',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('offline-pending-count')), findsOneWidget);
    expect(find.text('Pending sync: 1'), findsOneWidget);
    expect(find.byKey(const Key('offline-item-queue-2')), findsOneWidget);
    expect(find.byKey(const Key('offline-retry-now')), findsOneWidget);
  });
}
