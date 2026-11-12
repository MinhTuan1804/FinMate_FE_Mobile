import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

/// Màn H1: Cá nhân và Cài đặt (Settings & Profile Hub - Wireframe 16)
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
          content: Text(
            'Còn $pending giao dịch chưa được gửi lên máy chủ. Chúng được giữ trên máy này và sẽ gửi khi bạn đăng nhập lại.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Vẫn đăng xuất'),
            ),
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
    final user = ref.watch(authControllerProvider).valueOrNull;
    final name = user?.displayName ?? 'Người dùng FinMate';
    final actionColor = AppColors.primaryAction(context);
    final incomeText = user?.monthlyIncomeCents != null
        ? formatVnd(BigInt.from(user!.monthlyIncomeCents!))
        : 'Chưa thiết lập';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ & Cài đặt'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hero User Deck (Wireframe 16)
              ZenvestHeroDeck(
                peekBadgeText: 'PRO',
                child: LiquidGlassCard(
                  variant: LiquidGlassVariant.iridescentHero,
                  enableBlur: true,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: actionColor.withValues(alpha: 0.14),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'F',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: actionColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: AppTypography.body(context).copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user?.email ?? '',
                                  style: AppTypography.caption(context).copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(LucideIcons.pencil, size: 13),
                            label: const Text('Sửa'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(54, 32),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => context.push('/profile/edit'),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Thu nhập hàng tháng',
                                style: AppTypography.caption(context).copyWith(fontSize: 11.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                incomeText,
                                style: AppTypography.body(context).copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppColors.income,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.safe.withValues(alpha: 0.14),
                              borderRadius: AppSpacing.roundedPill,
                            ),
                            child: const Text(
                              'Đã xác thực',
                              style: TextStyle(
                                color: AppColors.safe,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Group 1: Tài chính & Nguồn tiền
              Text('TÀI CHÍNH & NGUỒN TIỀN', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 10),
              ZenvestSurfaceSheet(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    _menuTile(
                      icon: LucideIcons.wallet,
                      title: 'Tài khoản & Nguồn tiền (H7/H8)',
                      subtitle: 'Quản lý thẻ ngân hàng, ví MoMo, tiền mặt',
                      onTap: () => context.push('/profile/accounts'),
                    ),
                    const Divider(height: 1),
                    _menuTile(
                      icon: LucideIcons.tag,
                      title: 'Danh mục thu chi (H12/H13)',
                      subtitle: 'Tùy biến nhóm chi tiêu, icon và màu sắc',
                      onTap: () => context.push('/profile/categories'),
                    ),
                    const Divider(height: 1),
                    _menuTile(
                      icon: LucideIcons.bellRing,
                      title: 'Ngưỡng cảnh báo chi tiêu (H4/B7)',
                      subtitle: 'Nhận thông báo khi chạm 70%, 90% hạn mức',
                      onTap: () => context.push('/alert-thresholds'),
                    ),
                    const Divider(height: 1),
                    _menuTile(
                      icon: LucideIcons.pieChart,
                      title: 'Phương pháp quản lý hũ (B5/B6)',
                      subtitle: 'Quy tắc 6 chiếc hũ, 50/30/20',
                      onTap: () => context.push('/finance-methods'),
                    ),
                    const Divider(height: 1),
                    _menuTile(
                      icon: LucideIcons.sparkles,
                      title: 'Gói đăng ký FinMate Pro (H14/H15)',
                      subtitle: 'AI không giới hạn, quét hóa đơn thông minh',
                      onTap: () => context.push('/profile/subscription'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Group 2: Tùy chỉnh & Dữ liệu
              Text('TÙY CHỈNH & DỮ LIỆU', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 10),
              ZenvestSurfaceSheet(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    _menuTile(
                      icon: LucideIcons.palette,
                      title: 'Giao diện & Hiển thị (H3)',
                      subtitle: 'Sáng / Tối, giảm độ mờ kính, ẩn số dư',
                      onTap: () => context.push('/profile/appearance'),
                    ),
                    const Divider(height: 1),
                    _menuTile(
                      icon: LucideIcons.cloud,
                      title: 'Sao lưu & Dữ liệu (H5/H6)',
                      subtitle: 'Sao lưu đám mây, xuất file Excel/CSV, nhập dữ liệu',
                      onTap: () => context.push('/profile/backup-export'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Group 3: Bảo mật & Quyền riêng tư
              Text('BẢO MẬT & QUYỀN RIÊNG TƯ', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 10),
              ZenvestSurfaceSheet(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    _menuTile(
                      icon: LucideIcons.shieldCheck,
                      title: 'Quản lý 5 quyền đồng ý (H11)',
                      subtitle: 'Cấp hoặc thu hồi quyền AI, dữ liệu đào tạo',
                      onTap: () => context.push('/profile/consents'),
                    ),
                    const Divider(height: 1),
                    _menuTile(
                      icon: LucideIcons.keyRound,
                      title: 'Đổi mật khẩu tài khoản (H20)',
                      subtitle: 'Bảo vệ tài khoản bằng mật khẩu mạnh',
                      onTap: () => context.push('/profile/change-password'),
                    ),
                    const Divider(height: 1),
                    _menuTile(
                      icon: LucideIcons.fileText,
                      title: 'Điều khoản sử dụng (H9)',
                      subtitle: 'Quy định và quyền lợi người dùng',
                      onTap: () => context.push('/profile/terms'),
                    ),
                    const Divider(height: 1),
                    _menuTile(
                      icon: LucideIcons.lock,
                      title: 'Chính sách bảo mật Zero-Credential (H10)',
                      subtitle: 'Không lưu trữ thông tin đăng nhập ngân hàng',
                      onTap: () => context.push('/profile/privacy'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Group 4: Hỗ trợ & Cộng đồng
              Text('HỖ TRỢ & CỘNG ĐỒNG', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 10),
              ZenvestSurfaceSheet(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    _menuTile(
                      icon: LucideIcons.headset,
                      title: 'Trung tâm hỗ trợ & Ticket (H16-H19)',
                      subtitle: 'Gửi yêu cầu, chat với nhân viên hỗ trợ',
                      onTap: () => context.push('/profile/support'),
                    ),
                    const Divider(height: 1),
                    _menuTile(
                      icon: LucideIcons.users,
                      title: 'Nhóm chi tiêu chung (I1-I7)',
                      subtitle: 'Quỹ gia đình, nhóm bạn du lịch',
                      onTap: () => context.push('/groups'),
                    ),
                    const Divider(height: 1),
                    _menuTile(
                      icon: LucideIcons.globe,
                      title: 'Diễn đàn Cộng đồng tài chính (J1-J6)',
                      subtitle: 'Trao đổi kinh nghiệm tiết kiệm, hỏi đáp',
                      onTap: () => context.push('/community'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Group 5: Đăng xuất & Xóa tài khoản
              OutlinedButton.icon(
                onPressed: () => _logout(context, ref),
                icon: const Icon(LucideIcons.logOut, size: 18, color: AppColors.danger),
                label: const Text(
                  'Đăng xuất tài khoản',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () => context.push('/profile/delete-account'),
                  icon: const Icon(LucideIcons.trash2, size: 15, color: AppColors.danger),
                  label: const Text(
                    'Xóa vĩnh viễn tài khoản (H21)',
                    style: TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surfaceLightSubtle,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 19, color: const Color(0xFF111827)),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
      trailing: const Icon(LucideIcons.chevronRight, size: 16),
      onTap: onTap,
    );
  }
}
