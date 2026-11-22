import 'package:flutter/foundation.dart';

import '../domain/in_app_notification.dart';

abstract interface class InAppNotificationRepository {
  ValueListenable<List<InAppNotification>> get notifications;

  Future<void> add(InAppNotification notification);

  Future<void> markRead(String id);

  Future<void> markAllRead();
}

/// Observable in-memory notification inbox used by the staff shell.
class InMemoryInAppNotificationRepository
    implements InAppNotificationRepository {
  InMemoryInAppNotificationRepository({List<InAppNotification>? initial})
    : _notifications = ValueNotifier<List<InAppNotification>>(
        List.unmodifiable(initial ?? _demoNotifications()),
      );

  final ValueNotifier<List<InAppNotification>> _notifications;

  @override
  ValueListenable<List<InAppNotification>> get notifications => _notifications;

  static List<InAppNotification> _demoNotifications() {
    final now = DateTime(2026, 11, 22, 9);
    return [
      InAppNotification(
        id: 'task-idle-state',
        title: 'Idle-state check due',
        body: 'Verify the packaging line idle controls before handover.',
        category: InAppNotificationCategory.task,
        severity: InAppNotificationSeverity.info,
        createdAt: now,
      ),
      InAppNotification(
        id: 'evidence-review',
        title: 'Evidence needs review',
        body: 'A guided video is waiting for an authorized reviewer.',
        category: InAppNotificationCategory.evidence,
        severity: InAppNotificationSeverity.warning,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      InAppNotification(
        id: 'score-published',
        title: 'November score published',
        body: 'Your score breakdown and trend are now available.',
        category: InAppNotificationCategory.score,
        severity: InAppNotificationSeverity.success,
        createdAt: now.subtract(const Duration(days: 1)),
        isRead: true,
      ),
    ];
  }

  @override
  Future<void> add(InAppNotification notification) async {
    _notifications.value = [notification, ..._notifications.value];
  }

  @override
  Future<void> markRead(String id) async {
    _notifications.value = [
      for (final notification in _notifications.value)
        notification.id == id ? notification.markRead() : notification,
    ];
  }

  @override
  Future<void> markAllRead() async {
    _notifications.value = [
      for (final notification in _notifications.value) notification.markRead(),
    ];
  }
}
