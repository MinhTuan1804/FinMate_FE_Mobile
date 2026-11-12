import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/notifications_inbox/domain/notification_entity.dart';

final notificationsInboxRepositoryProvider = Provider<NotificationsInboxRepository>(
  (ref) => NotificationsInboxRepository(apiClient: ref.watch(apiClientProvider)),
);

class NotificationsInboxRepository {
  final ApiClient apiClient;

  NotificationsInboxRepository({required this.apiClient});

  /// GET /me/notifications?tab=
  Future<NotificationInboxPage> getNotifications({required NotificationInboxTab tab}) async {
    final response = await apiClient.get(
      '/api/v1/me/notifications',
      queryParameters: {'tab': tab.apiValue},
      fromJsonT: (json) => NotificationInboxPage.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// PATCH /me/notifications/{id}/read
  Future<UserNotificationEntity> markRead(String id) async {
    final response = await apiClient.patch(
      '/api/v1/me/notifications/$id/read',
      fromJsonT: (json) => UserNotificationEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// PATCH /me/notifications/read-all: trả số lượng đã đánh dấu.
  Future<int> markAllRead() async {
    final response = await apiClient.patch(
      '/api/v1/me/notifications/read-all',
      fromJsonT: (json) => json as int,
    );
    return response.data ?? 0;
  }

  /// DELETE /me/notifications/{id}
  Future<void> delete(String id) => apiClient.delete('/api/v1/me/notifications/$id');

  /// DELETE /me/notifications (không id): xóa tất cả.
  Future<void> deleteAll() => apiClient.delete('/api/v1/me/notifications');
}
