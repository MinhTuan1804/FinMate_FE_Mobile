import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_theme.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/assistant/presentation/widgets/assistant_bubble_tile.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_methods_controller.dart';
import 'package:finmate/features/subscriptions/presentation/controllers/subscriptions_controller.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

/// Một hàng trong nhóm cài đặt (Figma H1): biểu tượng, tiêu đề, mô tả phụ, nội dung bên phải và mũi tên/biểu tượng mở ngoài.
class _Row {
  const _Row({
    this.key,
    required this.icon,
    required this.label,
    required this.route,
    this.subtitle,
    this.trailingText,
    this.external = false,
    this.danger = false,
  });

  final Key? key;
  final IconData icon;
  final String label;
  final String route;
  final String? subtitle;
  final String? trailingText;
  final bool external;
  final bool danger;
}

/// Nhãn nhóm viết hoa + một khung kính chứa các hàng, ngăn cách bằng đường kẻ mảnh.
class _Group extends StatelessWidget {
  const _Group({required this.title, this.rows = const [], this.top = const []});

  final String title;
  final List<_Row> rows;

  /// Hàng tùy biến (ví dụ công tắc chế độ giao diện), hiện trước [rows].
  final List<Widget> top;

  @override
  Widget build(BuildContext context) {
    final divider = Divider(height: 1, color: AppColors.textMuted(context).withValues(alpha: 0.18));
    final all = <Widget>[
      ...top,
      for (final r in rows) _RowTile(row: r),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title.toUpperCase(), style: AppTypography.sectionLabel(context)),
        ),
        LiquidGlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < all.length; i++) ...[
                if (i > 0) divider,
                all[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) {
    final color = row.danger ? AppColors.danger : AppColors.textPrimary(context);
    return InkWell(
      key: row.key,
      onTap: () => context.push(row.route),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(row.icon, size: 20, color: row.danger ? AppColors.danger : AppColors.textSecondary(context)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.label,
                      style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600, fontSize: 15, color: color),
                    ),
                    // Chip và mô tả nằm ở dòng phụ (Wrap tự xuống dòng khi hẹp) để không tranh chỗ với tiêu đề
                    if (row.subtitle != null || row.trailingText != null) ...[
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (row.trailingText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.14),
                                borderRadius: AppSpacing.roundedPill,
                              ),
                              child: Text(
                                row.trailingText!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slateOn(context)),
                              ),
                            ),
                          if (row.subtitle != null)
                            Text(row.subtitle!, style: AppTypography.caption(context).copyWith(fontSize: 12)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                row.external ? LucideIcons.externalLink : LucideIcons.chevronRight,
                size: 18,
                color: AppColors.textMuted(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Màn H1: Cài đặt & Tài khoản (theo Figma). Mọi con số lấy từ dữ liệu thật; phần chưa có dữ liệu ở BE được ẩn.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final pending = await ref.read(databaseProvider).pendingSyncCount();
    if (pending > 0) {
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Còn giao dịch chưa đồng bộ'),
          content: Text('Còn $pending giao dịch chưa được gửi lên máy chủ. Chúng được giữ trên máy này và sẽ gửi khi bạn đăng nhập lại.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vẫn đăng xuất')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final accounts = ref.watch(accountsControllerProvider).valueOrNull ?? const [];
    final thresholds = ref.watch(alertThresholdsControllerProvider).valueOrNull;
    final plan = ref.watch(mySubscriptionProvider).valueOrNull;
    final themeMode = ref.watch(themeModeProvider);
    final consentsOn = [user?.termsAccepted, user?.aiConsentGranted, user?.trainingConsentGranted].where((v) => v == true).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt & Tài khoản'),
        centerTitle: true,
        actions: [
          IconButton(
            key: const ValueKey('open-notifications'),
            tooltip: 'Thông báo',
            icon: const Icon(LucideIcons.bell, size: 20),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: AmbientGlassBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _ProfileCard(
              name: user?.displayName ?? '',
              email: user?.email ?? '',
              incomeCents: user?.monthlyIncomeCents,
              planLabel: (plan != null && plan.enabled && !plan.isFree) ? plan.planName : null,
            ),
            const SizedBox(height: 24),
            _Group(
              title: 'Giao diện & trải nghiệm',
              top: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.palette, size: 20, color: AppColors.textSecondary(context)),
                          const SizedBox(width: 14),
                          Text(
                            'Chế độ giao diện',
                            style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          key: const ValueKey('theme-mode'),
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: ThemeMode.light, label: Text('Sáng')),
                            ButtonSegment(value: ThemeMode.dark, label: Text('Tối')),
                            ButtonSegment(value: ThemeMode.system, label: Text('Hệ thống')),
                          ],
                          selected: {themeMode},
                          onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).state = s.first,
                        ),
                      ),
                    ],
                  ),
                ),
                if (ref.watch(assistantBubbleSupportedProvider).valueOrNull ?? false) const AssistantBubbleTile(),
              ],
              rows: [
                _Row(
                  key: const ValueKey('open-alert-thresholds'),
                  icon: LucideIcons.bellRing,
                  label: 'Ngưỡng cảnh báo chi tiêu',
                  subtitle: thresholds == null ? 'Đặt mức nhắc khi chi sắp vượt' : 'Nhắc ở ${thresholds.t1Pct}% và ${thresholds.t2Pct}%',
                  route: '/finance-methods/alert-thresholds',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _Group(
              title: 'Dữ liệu & kết nối',
              rows: [
                _Row(
                  key: const ValueKey('open-financial-accounts'),
                  icon: LucideIcons.landmark,
                  label: 'Tài khoản và nguồn tiền',
                  subtitle: '${accounts.length} tài khoản đã liên kết',
                  route: '/profile/financial-accounts',
                ),
                const _Row(
                  key: ValueKey('open-backup'),
                  icon: LucideIcons.cloudUpload,
                  label: 'Sao lưu, xuất và nhập dữ liệu',
                  route: '/profile/backup',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _Group(
              title: 'Quyền riêng tư & AI',
              rows: [
                _Row(
                  key: const ValueKey('open-consents'),
                  icon: LucideIcons.shieldCheck,
                  label: 'Quyền đồng ý & Huấn luyện mô hình',
                  subtitle: 'Cá nhân hóa lời khuyên tài chính',
                  trailingText: '$consentsOn/3 đang bật',
                  route: '/profile/consents',
                ),
                const _Row(
                  key: ValueKey('open-ai-memory'),
                  icon: LucideIcons.brain,
                  label: 'Quản lý bộ nhớ FinMate AI',
                  subtitle: 'Xem lại và xóa bối cảnh đã lưu',
                  route: '/assistant/memory',
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _Group(
              title: 'Pháp lý & hỗ trợ',
              rows: [
                _Row(key: ValueKey('open-terms'), icon: LucideIcons.fileText, label: 'Điều khoản dịch vụ', route: '/legal/terms', external: true),
                _Row(key: ValueKey('open-privacy'), icon: LucideIcons.shield, label: 'Chính sách bảo mật', route: '/legal/privacy', external: true),
                _Row(
                  key: ValueKey('open-support'),
                  icon: LucideIcons.headset,
                  label: 'Yêu cầu hỗ trợ (Ticket)',
                  subtitle: 'Gửi và theo dõi yêu cầu của bạn',
                  route: '/support',
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Các mục dưới đây không có trong Figma H1 nhưng vẫn cần lối vào từ màn này.
            _Group(
              title: 'Quản lý tài chính',
              rows: [
                _Row(key: ValueKey('open-recurring'), icon: LucideIcons.refreshCw, label: 'Khoản thu/chi định kỳ', route: '/recurring-items'),
                _Row(key: ValueKey('open-groups'), icon: LucideIcons.users, label: 'Nhóm tài chính', route: '/groups'),
                _Row(key: ValueKey('open-forecast'), icon: LucideIcons.trendingUp, label: 'Dự báo tài chính', route: '/forecast'),
                _Row(key: ValueKey('open-finance-methods'), icon: LucideIcons.wallet, label: 'Cách quản lý tài chính', route: '/finance-methods'),
                _Row(key: ValueKey('open-category-management'), icon: LucideIcons.tag, label: 'Danh mục', route: '/profile/categories'),
                // Gói đăng ký chưa đưa vào sử dụng (cờ features.subscriptions tắt): ẩn lối vào, bật cờ ở backend là hiện lại.
                if (plan?.enabled == true)
                  const _Row(key: ValueKey('open-subscription'), icon: LucideIcons.crown, label: 'Gói đăng ký', route: '/profile/subscription'),
              ],
            ),
            const SizedBox(height: 24),
            const _Group(
              title: 'Ứng dụng & tài khoản',
              rows: [
                _Row(key: ValueKey('open-devices'), icon: LucideIcons.smartphone, label: 'Thiết bị & thông báo push', route: '/devices'),
                _Row(key: ValueKey('open-widget-settings'), icon: Icons.widgets_outlined, label: 'Widget trên màn hình chính', route: '/widget-settings'),
                _Row(key: ValueKey('open-community'), icon: LucideIcons.messagesSquare, label: 'Cộng đồng', route: '/community'),
                _Row(key: ValueKey('open-survey'), icon: LucideIcons.clipboardList, label: 'Khảo sát đầu vào', route: '/survey'),
                _Row(key: ValueKey('open-appearance'), icon: LucideIcons.eye, label: 'Giao diện và hiển thị', route: '/profile/appearance'),
                _Row(key: ValueKey('open-change-password'), icon: LucideIcons.lock, label: 'Đổi mật khẩu', route: '/profile/change-password'),
                _Row(key: ValueKey('open-delete-account'), icon: LucideIcons.trash2, label: 'Xóa tài khoản', route: '/profile/delete-account', danger: true),
              ],
            ),
            const SizedBox(height: 28),
            AsyncActionBuilder(
              onPressed: () => _logout(context, ref),
              builder: (_, onTap, running) => OutlinedButton.icon(
                onPressed: onTap,
                icon: running ? const ButtonLoadingIndicator(size: 16) : const Icon(LucideIcons.logOut, size: 18, color: AppColors.danger),
                label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Đăng xuất tài khoản', style: TextStyle(color: AppColors.danger), maxLines: 1)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.inset(context, 0.7),
                  side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ hồ sơ đầu màn (Figma H1): chữ cái đầu thay ảnh đại diện, tên, huy hiệu gói (chỉ khi có gói trả phí), email, nút Sửa
/// và dòng thu nhập dự kiến. Không hiện số điện thoại vì hồ sơ chưa có trường này.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, required this.email, required this.incomeCents, required this.planLabel});

  final String name;
  final String email;
  final int? incomeCents;
  final String? planLabel;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      variant: LiquidGlassVariant.iridescentHero,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primaryAction(context).withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'F',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primaryAction(context)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.h2(context).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (planLabel != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.2),
                              borderRadius: AppSpacing.roundedPill,
                            ),
                            child: Text(
                              planLabel!.toUpperCase(),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.slateOn(context)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(context)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const ValueKey('open-edit-profile'),
                onPressed: () => context.push('/profile/edit'),
                icon: const Icon(LucideIcons.pencil, size: 14),
                label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Sửa', maxLines: 1)),
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  backgroundColor: AppColors.inset(context, 0.8),
                  foregroundColor: AppColors.textPrimary(context),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(LucideIcons.wallet, size: 16, color: AppColors.textSecondary(context)),
              const SizedBox(width: 8),
              Expanded(child: Text('Thu nhập dự kiến:', style: AppTypography.caption(context))),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.inset(context, 0.85), borderRadius: AppSpacing.roundedPill),
                  child: Text(
                    incomeCents == null ? 'Chưa đặt' : '${formatVnd(BigInt.from(incomeCents!))}/tháng',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.tabular(AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
