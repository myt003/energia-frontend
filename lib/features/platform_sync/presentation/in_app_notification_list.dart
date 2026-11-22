import 'package:material_ui/material_ui.dart';

import '../../../core/theme/energia_theme.dart';
import '../data/in_app_notification_repository.dart';
import '../domain/in_app_notification.dart';

/// In-app notification inbox with unread filtering and read-on-open.
class InAppNotificationList extends StatefulWidget {
  const InAppNotificationList({
    required this.repository,
    this.onOpen,
    super.key,
  });

  final InAppNotificationRepository repository;
  final ValueChanged<InAppNotification>? onOpen;

  @override
  State<InAppNotificationList> createState() => _InAppNotificationListState();
}

class _InAppNotificationListState extends State<InAppNotificationList> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<InAppNotification>>(
      valueListenable: widget.repository.notifications,
      builder: (context, notifications, _) {
        final unread = notifications.where((item) => !item.isRead).length;
        final visible = _unreadOnly
            ? notifications.where((item) => !item.isRead).toList()
            : notifications;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Notifications · $unread unread',
                    key: const Key('notifications-unread-count'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  key: const Key('notifications-unread-filter'),
                  onPressed: () => setState(() => _unreadOnly = !_unreadOnly),
                  icon: const Icon(Icons.filter_list),
                  label: Text(_unreadOnly ? 'Show all' : 'Unread only'),
                ),
                if (unread > 0)
                  TextButton(
                    key: const Key('notifications-mark-all-read'),
                    onPressed: widget.repository.markAllRead,
                    child: const Text('Mark all read'),
                  ),
              ],
            ),
            if (visible.isEmpty)
              Container(
                key: const Key('notifications-empty'),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: EnergiaColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EnergiaColors.line),
                ),
                child: const Text('Nothing here right now.'),
              )
            else
              for (final notification in visible)
                Card(
                  key: Key('notification-${notification.id}'),
                  child: ListTile(
                    leading: Icon(
                      _iconFor(notification.category),
                      color: _colorFor(notification.severity),
                    ),
                    title: Text(notification.title),
                    subtitle: Text(notification.body),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!notification.isRead)
                          Container(
                            key: Key('notification-unread-${notification.id}'),
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: EnergiaColors.teal,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          '${notification.createdAt.hour.toString().padLeft(2, '0')}:${notification.createdAt.minute.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    onTap: () async {
                      await widget.repository.markRead(notification.id);
                      widget.onOpen?.call(notification);
                    },
                  ),
                ),
          ],
        );
      },
    );
  }
}

IconData _iconFor(InAppNotificationCategory category) => switch (category) {
  InAppNotificationCategory.task => Icons.task_alt,
  InAppNotificationCategory.evidence => Icons.photo_camera_outlined,
  InAppNotificationCategory.score => Icons.insights_outlined,
  InAppNotificationCategory.system => Icons.info_outline,
};

Color _colorFor(InAppNotificationSeverity severity) => switch (severity) {
  InAppNotificationSeverity.info => EnergiaColors.teal,
  InAppNotificationSeverity.success => EnergiaColors.success,
  InAppNotificationSeverity.warning => EnergiaColors.warning,
  InAppNotificationSeverity.critical => EnergiaColors.critical,
};
