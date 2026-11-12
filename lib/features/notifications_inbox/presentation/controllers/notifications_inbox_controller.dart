import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/notifications_inbox/data/notifications_inbox_repository.dart';
import 'package:finmate/features/notifications_inbox/domain/notification_entity.dart';

/// Hộp thư thông báo của tab đang xem; đánh dấu đã đọc/xóa đều sửa state cục bộ thay vì tải lại,
/// trừ đổi tab (phải tải lại vì mỗi tab có danh sách riêng).
class NotificationsInboxController extends StateNotifier<AsyncValue<NotificationInboxPage>> {
  final NotificationsInboxRepository repository;
  NotificationInboxTab _currentTab = NotificationInboxTab.all;

  NotificationsInboxController(this.repository) : super(const AsyncValue.loading()) {
    load();
  }

  NotificationInboxTab get currentTab => _currentTab;

  Future<void> load({NotificationInboxTab? tab}) async {
    _currentTab = tab ?? _currentTab;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repository.getNotifications(tab: _currentTab));
  }

  Future<void> changeTab(NotificationInboxTab tab) async {
    if (tab == _currentTab) return;
    await load(tab: tab);
  }

  UserNotificationEntity? _find(List<UserNotificationEntity> items, String id) {
    for (final n in items) {
      if (n.id == id) return n;
    }
    return null;
  }

  Future<void> markRead(String id) async {
    final page = state.value;
    final existing = page == null ? null : _find(page.items, id);
    if (existing == null || !existing.isUnread) {
      await repository.markRead(id);
      return;
    }
    final updated = await repository.markRead(id);
    state = AsyncValue.data(
      NotificationInboxPage(
        items: [for (final n in page!.items) n.id == id ? updated : n],
        all: NotificationTabCounts(total: page.all.total, unread: page.all.unread - 1),
        movement: existing.isMovementType
            ? NotificationTabCounts(total: page.movement.total, unread: page.movement.unread - 1)
            : page.movement,
        aiAlert: existing.isMovementType
            ? page.aiAlert
            : NotificationTabCounts(total: page.aiAlert.total, unread: page.aiAlert.unread - 1),
      ),
    );
  }

  Future<void> markAllRead() async {
    await repository.markAllRead();
    await load();
  }

  Future<void> delete(String id) async {
    await repository.delete(id);
    final page = state.value;
    if (page == null) return;
    final removed = _find(page.items, id);
    state = AsyncValue.data(
      NotificationInboxPage(
        items: [for (final n in page.items) if (n.id != id) n],
        all: NotificationTabCounts(
          total: page.all.total - 1,
          unread: removed != null && removed.isUnread ? page.all.unread - 1 : page.all.unread,
        ),
        movement: removed != null && removed.isMovementType
            ? NotificationTabCounts(
                total: page.movement.total - 1,
                unread: removed.isUnread ? page.movement.unread - 1 : page.movement.unread,
              )
            : page.movement,
        aiAlert: removed != null && !removed.isMovementType
            ? NotificationTabCounts(
                total: page.aiAlert.total - 1,
                unread: removed.isUnread ? page.aiAlert.unread - 1 : page.aiAlert.unread,
              )
            : page.aiAlert,
      ),
    );
  }

  Future<void> deleteAll() async {
    await repository.deleteAll();
    await load();
  }
}

final notificationsInboxControllerProvider =
    StateNotifierProvider.autoDispose<NotificationsInboxController, AsyncValue<NotificationInboxPage>>(
  (ref) => NotificationsInboxController(ref.watch(notificationsInboxRepositoryProvider)),
);
