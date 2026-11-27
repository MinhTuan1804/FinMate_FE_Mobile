import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/devices/data/push_messaging.dart';
import 'package:finmate/features/notifications_inbox/domain/notification_entity.dart';
import 'package:finmate/features/notifications_inbox/presentation/controllers/notifications_inbox_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_filter_chip.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_notification_card.dart';

(IconData, Color) _iconForType(String type) => switch (type) {
      'BalanceChange' => (LucideIcons.arrowLeftRight, GlassColors.accentSkyBlue),
      'TransactionReview' => (LucideIcons.clipboardCheck, GlassColors.warning),
      'ForecastAlert' => (LucideIcons.chartLine, GlassColors.warning),
      'GoalMilestone' => (LucideIcons.target, GlassColors.success),
      'BudgetThreshold' => (LucideIcons.triangleAlert, GlassColors.warning),
      'AnomalyDetected' => (LucideIcons.sparkles, GlassColors.accentDustyRose),
      'RecurringBillDue' => (LucideIcons.calendarClock, GlassColors.warning),
      'ForecastReady' => (LucideIcons.chartLine, GlassColors.accentSkyBlue),
      _ => (LucideIcons.bell, GlassColors.slateAnchor),
    };

/// Bấm một thông báo trong hộp thư → màn của đúng thứ nó báo (cùng đích với push cùng loại, xem routeForPush). null: chỉ đánh dấu đã đọc.
@visibleForTesting
String? routeForInboxType(String type) => switch (type) {
      'BalanceChange' => '/transactions',
      'GoalMilestone' => '/planning/goals',
      'BudgetThreshold' => '/planning/budgets',
      'AnomalyDetected' => '/analytics/alerts',
      'RecurringBillDue' => '/planning/recurring',
      'ForecastReady' => '/analytics/insights',
      _ => null,
    };

String _dateGroupLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hôm nay';
  if (diff == 1) return 'Hôm qua';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _timeLabel(DateTime date) => '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class NotificationsInboxScreen extends ConsumerWidget {
  const NotificationsInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsInboxControllerProvider);
    final controller = ref.read(notificationsInboxControllerProvider.notifier);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Thông báo', style: GlassTypography.headlineMd()),
          actions: [
            TextButton(
              onPressed: () => controller.markAllRead(),
              child: Text('Đã đọc', style: GlassTypography.bodyMd(color: GlassColors.accentSkyBlue).copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        body: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorMessage(e), textAlign: TextAlign.center, style: GlassTypography.bodyMd()),
                    const SizedBox(height: 12),
                    GlassSecondaryButton(label: 'Thử lại', onPressed: () => controller.load()),
                  ],
                ),
              ),
            ),
            data: (page) => _buildBody(context, ref, controller, page),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, NotificationsInboxController controller, NotificationInboxPage page) {
    final grouped = <String, List<UserNotificationEntity>>{};
    for (final item in page.items) {
      grouped.putIfAbsent(_dateGroupLabel(item.createdAt), () => []).add(item);
    }
    // Dàn phẳng (tiêu đề nhóm | thông báo) để ListView.builder chỉ dựng dòng đang hiện.
    final rows = <Object>[for (final group in grouped.entries) ...[group.key, ...group.value]];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                GlassFilterChip(
                  label: 'Tất cả',
                  count: page.all.total,
                  selected: controller.currentTab == NotificationInboxTab.all,
                  onTap: () => controller.changeTab(NotificationInboxTab.all),
                ),
                const SizedBox(width: 10),
                GlassFilterChip(
                  label: 'Biến động',
                  count: page.movement.total,
                  selected: controller.currentTab == NotificationInboxTab.movement,
                  onTap: () => controller.changeTab(NotificationInboxTab.movement),
                ),
                const SizedBox(width: 10),
                GlassFilterChip(
                  label: 'Cảnh báo AI',
                  count: page.aiAlert.total,
                  selected: controller.currentTab == NotificationInboxTab.aiAlert,
                  onTap: () => controller.changeTab(NotificationInboxTab.aiAlert),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: page.items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: GlassColors.secondarySurface, shape: BoxShape.circle),
                          child: Icon(LucideIcons.bellOff, size: 28, color: GlassColors.textMuted),
                        ),
                        const SizedBox(height: 16),
                        Text('Chưa có thông báo', style: GlassTypography.headlineSm()),
                        const SizedBox(height: 4),
                        Text('Thông báo mới sẽ hiện ở đây.', style: GlassTypography.bodySm()),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    if (row is String) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(row.toUpperCase(), style: GlassTypography.labelCaps()),
                      );
                    }
                    final item = row as UserNotificationEntity;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassNotificationCard(
                        icon: _iconForType(item.type).$1,
                        iconColor: _iconForType(item.type).$2,
                        title: item.title,
                        body: item.body,
                        metaText: _timeLabel(item.createdAt),
                        unread: item.isUnread,
                        onTap: () {
                          controller.markRead(item.id);
                          // Mục đến từ push: mở đúng màn như khi bấm push; mục cũ không có data: theo loại.
                          final data = item.data;
                          if (data != null && data.isNotEmpty) {
                            final (path, extra) = routeForPush(data);
                            context.push(path, extra: extra);
                            if (data['type'] == 'transaction_review') {
                              ref.read(transactionControllerProvider.notifier).setDraftsOnly(true);
                            }
                            return;
                          }
                          final path = routeForInboxType(item.type);
                          if (path != null) context.push(path);
                        },
                        onDismiss: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Xóa thông báo này?'),
                              content: const Text('Bạn có chắc chắn muốn xóa thông báo này không? Không thể khôi phục lại.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                                TextButton(key: const ValueKey('confirm-delete-notification'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
                              ],
                            ),
                          );
                          if (ok == true) await controller.delete(item.id);
                        },
                      ),
                    );
                  },
                  ),
        ),
        if (page.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: GlassGhostButton(
              label: 'Xóa tất cả',
              onPressed: () => _confirmDeleteAll(context, controller),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, NotificationsInboxController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tất cả thông báo?'),
        content: const Text('Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteAll();
  }
}
