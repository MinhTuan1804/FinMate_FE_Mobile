import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

enum NotificationFilter { all, alerts, transactions, system }

class AppNotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final NotificationFilter category;
  final bool isRead;
  final IconData icon;
  final Color iconColor;
  final String? deepLink;

  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.category,
    this.isRead = false,
    required this.icon,
    required this.iconColor,
    this.deepLink,
  });

  AppNotificationItem copyWith({bool? isRead}) {
    return AppNotificationItem(
      id: id,
      title: title,
      message: message,
      createdAt: createdAt,
      category: category,
      isRead: isRead ?? this.isRead,
      icon: icon,
      iconColor: iconColor,
      deepLink: deepLink,
    );
  }
}

/// Màn B2: Thông báo (Notifications Screen)
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationFilter _selectedFilter = NotificationFilter.all;

  late List<AppNotificationItem> _notifications = [
    AppNotificationItem(
      id: '1',
      title: 'Cảnh báo ngân sách Ăn uống',
      message: 'Bạn đã chi tiêu đạt 85% hạn mức ngân sách tháng này cho danh mục Ăn uống.',
      createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
      category: NotificationFilter.alerts,
      isRead: false,
      icon: LucideIcons.triangleAlert,
      iconColor: AppColors.warning,
      deepLink: '/planning',
    ),
    AppNotificationItem(
      id: '2',
      title: 'Nhận diện giao dịch mới',
      message: 'FinMate phát hiện chi tiêu 45.000 ₫ tại The Coffee House từ biến động số dư.',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      category: NotificationFilter.transactions,
      isRead: false,
      icon: LucideIcons.receipt,
      iconColor: AppColors.info,
      deepLink: '/transactions',
    ),
    AppNotificationItem(
      id: '3',
      title: 'Mục tiêu tiết kiệm đạt 70%',
      message: 'Chúc mừng! Quỹ Du lịch Đà Lạt của bạn vừa đạt mốc 7.000.000 ₫.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      category: NotificationFilter.alerts,
      isRead: true,
      icon: LucideIcons.trophy,
      iconColor: AppColors.safe,
      deepLink: '/planning',
    ),
    AppNotificationItem(
      id: '4',
      title: 'Bảo mật tài khoản',
      message: 'Phiên đăng nhập mới từ thiết bị Android tại Hà Nội. Nếu không phải bạn, hãy đổi mật khẩu ngay.',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      category: NotificationFilter.system,
      isRead: true,
      icon: LucideIcons.shieldCheck,
      iconColor: AppColors.secondary,
      deepLink: '/profile/change-password',
    ),
  ];

  void _markAllAsRead() {
    setState(() {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã đánh dấu tất cả thông báo là đã đọc'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _markItemRead(String id) {
    setState(() {
      _notifications = _notifications.map((n) {
        if (n.id == id) return n.copyWith(isRead: true);
        return n;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _notifications.where((n) {
      if (_selectedFilter == NotificationFilter.all) return true;
      return n.category == _selectedFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.checkCheck),
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: _notifications.any((n) => !n.isRead) ? _markAllAsRead : null,
          ),
        ],
      ),
      body: AmbientGlassBackground(
        child: Column(
          children: [
            // Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Row(
                children: [
                  _filterChip('Tất cả', NotificationFilter.all),
                  const SizedBox(width: 8),
                  _filterChip('Cảnh báo chi tiêu', NotificationFilter.alerts),
                  const SizedBox(width: 8),
                  _filterChip('Giao dịch', NotificationFilter.transactions),
                  const SizedBox(width: 8),
                  _filterChip('Hệ thống', NotificationFilter.system),
                ],
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.bellOff, size: 48, color: AppColors.textMuted(context)),
                          const SizedBox(height: 12),
                          Text('Không có thông báo nào', style: AppTypography.caption(context)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: LiquidGlassCard(
                            variant: item.isRead
                                ? LiquidGlassVariant.subtle
                                : LiquidGlassVariant.standard,
                            padding: const EdgeInsets.all(16),
                            onTap: () {
                              _markItemRead(item.id);
                              if (item.deepLink != null) {
                                context.push(item.deepLink!);
                              }
                            },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: item.iconColor.withValues(alpha: 0.14),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: item.iconColor.withValues(alpha: 0.35),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(item.icon, size: 20, color: item.iconColor),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: AppTypography.body(context).copyWith(
                                                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                                                fontSize: 14.5,
                                              ),
                                            ),
                                          ),
                                          if (!item.isRead) ...[
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryAction(context),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.message,
                                        style: AppTypography.caption(context).copyWith(
                                          fontSize: 13,
                                          height: 1.35,
                                          color: item.isRead
                                              ? AppColors.textMuted(context)
                                              : AppColors.textPrimary(context),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt),
                                        style: AppTypography.caption(context).copyWith(
                                          fontSize: 11,
                                          color: AppColors.textMuted(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, NotificationFilter filter) {
    final selected = _selectedFilter == filter;
    final activeBg = AppColors.primaryAction(context);
    final activeFg = AppColors.onPrimaryAction(context);

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: activeBg,
      labelStyle: TextStyle(
        color: selected ? activeFg : AppColors.textPrimary(context),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12.5,
      ),
      onSelected: (_) => setState(() => _selectedFilter = filter),
    );
  }
}
