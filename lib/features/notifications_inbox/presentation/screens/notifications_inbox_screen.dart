import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/notifications_inbox/domain/notification_entity.dart';
import 'package:finmate/features/notifications_inbox/presentation/controllers/notifications_inbox_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_filter_chip.dart';
import 'package:finmate/shared/widgets/glass/glass_notification_card.dart';

(IconData, Color) _iconForType(String type) => switch (type) {
      'BalanceChange' => (LucideIcons.arrowLeftRight, GlassColors.accentSkyBlue),
      'GoalMilestone' => (LucideIcons.target, GlassColors.success),
      'BudgetThreshold' => (LucideIcons.triangleAlert, GlassColors.warning),
      'AnomalyDetected' => (LucideIcons.sparkles, GlassColors.accentDustyRose),
      'RecurringBillDue' => (LucideIcons.calendarClock, GlassColors.warning),
      'ForecastReady' => (LucideIcons.chartLine, GlassColors.accentSkyBlue),
      _ => (LucideIcons.bell, GlassColors.slateAnchor),
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
            data: (page) => _buildBody(context, controller, page),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationsInboxController controller, NotificationInboxPage page) {
    final grouped = <String, List<UserNotificationEntity>>{};
    for (final item in page.items) {
      grouped.putIfAbsent(_dateGroupLabel(item.createdAt), () => []).add(item);
    }

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
                          child: const Icon(LucideIcons.bellOff, size: 28, color: GlassColors.textMuted),
                        ),
                        const SizedBox(height: 16),
                        Text('Chưa có thông báo', style: GlassTypography.headlineSm()),
                        const SizedBox(height: 4),
                        Text('Thông báo mới sẽ hiện ở đây.', style: GlassTypography.bodySm()),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    for (final group in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(group.key.toUpperCase(), style: GlassTypography.labelCaps()),
                      ),
                      for (final item in group.value) ...[
                        GlassNotificationCard(
                          icon: _iconForType(item.type).$1,
                          iconColor: _iconForType(item.type).$2,
                          title: item.title,
                          body: item.body,
                          metaText: _timeLabel(item.createdAt),
                          unread: item.isUnread,
                          onTap: () => controller.markRead(item.id),
                          onDismiss: () => controller.delete(item.id),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
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
