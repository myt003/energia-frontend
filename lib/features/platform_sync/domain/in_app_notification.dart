enum InAppNotificationCategory { task, evidence, score, system }

enum InAppNotificationSeverity { info, success, warning, critical }

class InAppNotification {
  const InAppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.severity,
    required this.createdAt,
    this.isRead = false,
    this.targetRoute,
  });

  final String id;
  final String title;
  final String body;
  final InAppNotificationCategory category;
  final InAppNotificationSeverity severity;
  final DateTime createdAt;
  final bool isRead;
  final String? targetRoute;

  InAppNotification markRead() => copyWith(isRead: true);

  InAppNotification copyWith({
    bool? isRead,
    String? targetRoute,
    bool clearTargetRoute = false,
  }) {
    return InAppNotification(
      id: id,
      title: title,
      body: body,
      category: category,
      severity: severity,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      targetRoute: clearTargetRoute ? null : targetRoute ?? this.targetRoute,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'category': category.name,
    'severity': severity.name,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
    'targetRoute': targetRoute,
  };
}
