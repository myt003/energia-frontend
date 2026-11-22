import 'package:energia/core/theme/energia_theme.dart';
import 'package:energia/features/platform_sync/data/in_app_notification_repository.dart';
import 'package:energia/features/platform_sync/domain/in_app_notification.dart';
import 'package:energia/features/platform_sync/presentation/in_app_notification_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('repository marks individual and all notifications as read', () async {
    final repository = InMemoryInAppNotificationRepository();
    expect(repository.notifications.value.where((item) => !item.isRead), hasLength(2));

    await repository.markRead('task-idle-state');
    expect(
      repository.notifications.value
          .firstWhere((item) => item.id == 'task-idle-state')
          .isRead,
      isTrue,
    );
    await repository.markAllRead();
    expect(repository.notifications.value.where((item) => !item.isRead), isEmpty);

    await repository.add(
      InAppNotification(
        id: 'new',
        title: 'New',
        body: 'A new notification.',
        category: InAppNotificationCategory.system,
        severity: InAppNotificationSeverity.info,
        createdAt: DateTime(2026, 11, 22, 10),
      ),
    );
    expect(repository.notifications.value.first.id, 'new');
    expect(repository.notifications.value.first.toJson()['isRead'], isFalse);
  });

  testWidgets('list shows unread state, opens items and filters read items', (
    tester,
  ) async {
    final repository = InMemoryInAppNotificationRepository();
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: EnergiaTheme.light,
        home: Scaffold(
          body: InAppNotificationList(
            repository: repository,
            onOpen: (item) => opened.add(item.id),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('notifications-unread-count')), findsOneWidget);
    expect(find.textContaining('2 unread'), findsOneWidget);
    expect(find.byKey(const Key('notification-unread-task-idle-state')), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-task-idle-state')));
    await tester.pumpAndSettle();
    expect(opened, ['task-idle-state']);
    expect(find.textContaining('1 unread'), findsOneWidget);
    expect(find.byKey(const Key('notification-unread-task-idle-state')), findsNothing);

    await tester.tap(find.byKey(const Key('notifications-unread-filter')));
    await tester.pump();
    expect(find.byKey(const Key('notification-evidence-review')), findsOneWidget);
    expect(find.byKey(const Key('notification-score-published')), findsNothing);

    await tester.tap(find.byKey(const Key('notifications-mark-all-read')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notifications-empty')), findsOneWidget);
  });
}
