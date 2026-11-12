/// Tab lọc thông báo (GET /me/notifications?tab=).
enum NotificationInboxTab {
  all('all'),
  movement('movement'),
  aiAlert('ai_alert');

  final String apiValue;
  const NotificationInboxTab(this.apiValue);
}

/// [type] nguyên văn BE: BudgetThreshold|BalanceChange|AnomalyDetected|RecurringBillDue|ForecastReady|GoalMilestone.
class UserNotificationEntity {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final DateTime createdAt;
  final DateTime? readAt;

  const UserNotificationEntity({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.relatedEntityType,
    required this.relatedEntityId,
    required this.createdAt,
    required this.readAt,
  });

  bool get isUnread => readAt == null;

  /// Khớp cách BE chia tab: 'movement' = BalanceChange/GoalMilestone, còn lại là 'ai_alert'.
  bool get isMovementType => type == 'BalanceChange' || type == 'GoalMilestone';

  UserNotificationEntity markAsRead(DateTime at) => UserNotificationEntity(
        id: id,
        type: type,
        title: title,
        body: body,
        relatedEntityType: relatedEntityType,
        relatedEntityId: relatedEntityId,
        createdAt: createdAt,
        readAt: at,
      );

  factory UserNotificationEntity.fromJson(Map<String, dynamic> json) => UserNotificationEntity(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        relatedEntityType: json['relatedEntityType'] as String?,
        relatedEntityId: json['relatedEntityId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        readAt: json['readAt'] == null ? null : DateTime.parse(json['readAt'] as String).toLocal(),
      );
}

class NotificationTabCounts {
  final int total;
  final int unread;

  const NotificationTabCounts({required this.total, required this.unread});

  factory NotificationTabCounts.fromJson(Map<String, dynamic> json) =>
      NotificationTabCounts(total: json['total'] as int, unread: json['unread'] as int);
}

/// GET /me/notifications: danh sách của tab đang xem + số lượng của cả 3 tab (để hiện badge trên chip).
class NotificationInboxPage {
  final List<UserNotificationEntity> items;
  final NotificationTabCounts all;
  final NotificationTabCounts movement;
  final NotificationTabCounts aiAlert;

  const NotificationInboxPage({
    required this.items,
    required this.all,
    required this.movement,
    required this.aiAlert,
  });

  factory NotificationInboxPage.fromJson(Map<String, dynamic> json) => NotificationInboxPage(
        items: (json['items'] as List).map((e) => UserNotificationEntity.fromJson(e as Map<String, dynamic>)).toList(),
        all: NotificationTabCounts.fromJson(json['all'] as Map<String, dynamic>),
        movement: NotificationTabCounts.fromJson(json['movement'] as Map<String, dynamic>),
        aiAlert: NotificationTabCounts.fromJson(json['aiAlert'] as Map<String, dynamic>),
      );
}
