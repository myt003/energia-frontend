import 'package:material_ui/material_ui.dart';

import '../../../core/theme/energia_theme.dart';
import '../domain/offline_queue.dart';

/// Visible pending queue state with an explicit user-initiated retry.
class OfflineQueueIndicator extends StatelessWidget {
  const OfflineQueueIndicator({
    required this.coordinator,
    this.onRetry,
    super.key,
  });

  final OfflineQueueCoordinator coordinator;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<OfflineOperation>>(
      valueListenable: coordinator.operations,
      builder: (context, operations, _) {
        final pending = operations
            .where(
              (item) =>
                  item.status == OfflineOperationStatus.pending ||
                  item.status == OfflineOperationStatus.inFlight ||
                  item.status == OfflineOperationStatus.retryScheduled,
            )
            .toList();
        return Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: EnergiaColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: pending.isEmpty ? EnergiaColors.line : EnergiaColors.warning,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    pending.isEmpty
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_sync_outlined,
                    color: pending.isEmpty
                        ? EnergiaColors.success
                        : EnergiaColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: pending.isEmpty
                        ? const Text(
                            'All work synchronized',
                            key: Key('offline-all-synced'),
                          )
                        : Text(
                            'Pending sync: ${pending.length}',
                            key: const Key('offline-pending-count'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                  ),
                  if (onRetry != null && pending.isNotEmpty)
                    OutlinedButton(
                      key: const Key('offline-retry-now'),
                      onPressed: onRetry,
                      child: const Text('Retry now'),
                    ),
                ],
              ),
              if (pending.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final operation in pending.take(3))
                  Padding(
                    key: Key('offline-item-${operation.id}'),
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${operation.kind} → ${operation.path}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '${operation.status.name} · attempt ${operation.attempts}'
                          '${operation.nextAttemptAt == null ? '' : ' · next ${operation.nextAttemptAt!.toIso8601String()}'}'
                          '${operation.lastError == null ? '' : ' · ${operation.lastError}'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: EnergiaColors.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
