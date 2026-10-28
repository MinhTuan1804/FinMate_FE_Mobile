import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/auth/domain/entities/consent.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/auth/presentation/screens/training_consent_screen.dart';

/// Màn Cá nhân: thông tin tài khoản và đăng xuất
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

  /// Công tắc phân loại bằng AI: đồng ý đã nằm trong Điều khoản nên không có màn hỏi riêng. Tắt/bật gọi server ngay; lỗi thì công tắc giữ nguyên.
  Future<void> _toggleAiConsent(BuildContext context, WidgetRef ref, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final auth = ref.read(authControllerProvider.notifier);
      await (on ? auth.acceptConsent(ConsentKind.ai) : auth.withdrawConsent(ConsentKind.ai));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  /// Bật: màn đồng ý tự ghi đồng ý. Tắt: hỏi xác nhận (nói rõ dữ liệu đã đóng góp bị xóa) rồi gọi server; lỗi thì công tắc giữ nguyên.
  Future<void> _toggleTrainingConsent(BuildContext context, WidgetRef ref, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    if (on) {
      await ensureTrainingConsent(context, ref);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tắt đóng góp dữ liệu?'),
        content: const Text('Từ giờ FinMate không thu thêm dữ liệu của bạn, và dữ liệu bạn đã đóng góp sẽ bị xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rút lại và xóa')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authControllerProvider.notifier).withdrawConsent(ConsentKind.training);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authControllerProvider).value;
    final name = user?.displayName ?? '';
    final aiConsent = user?.aiConsentGranted ?? false;
    final trainingConsent = user?.trainingConsentGranted ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Cá nhân')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: AppSpacing.roundedLarge,
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'F',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(user?.email ?? '', style: AppTypography.caption(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightSubtle,
                borderRadius: AppSpacing.roundedMedium,
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.shieldCheck, color: AppColors.safe, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bảo mật Zero-Credential tuyệt đối',
                          style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dữ liệu mã hóa trên thiết bị, không lưu trữ thông tin đăng nhập ngân hàng.',
                          style: AppTypography.caption(context).copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Quyền riêng tư', style: AppTypography.h3(context)),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const ValueKey('ai-consent-switch'),
              value: aiConsent,
              onChanged: user == null ? null : (on) => _toggleAiConsent(context, ref, on),
              activeThumbColor: AppColors.primary,
              tileColor: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightSubtle,
              shape: RoundedRectangleBorder(
                borderRadius: AppSpacing.roundedMedium,
                side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              secondary: const Icon(LucideIcons.sparkles, color: AppColors.primary, size: 24),
              title: Text(
                'Phân loại chi tiêu bằng AI',
                style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              subtitle: Text(
                aiConsent
                    ? 'Đang bật: chỉ tên món hoặc cụm sản phẩm (không kèm giá hay thông tin của bạn) trong hóa đơn, chat và giọng nói được gửi cho Google Gemini (hoặc OpenRouter khi Gemini quá tải) để xếp nhóm. Thuốc và đồ y tế không bao giờ được gửi.'
                    : 'Đang tắt: FinMate chỉ phân loại bằng quy tắc có sẵn và không gửi gì cho AI. Bật lại bất cứ lúc nào.',
                style: AppTypography.caption(context).copyWith(fontSize: 11),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              key: const ValueKey('training-consent-switch'),
              value: trainingConsent,
              onChanged: user == null ? null : (on) => _toggleTrainingConsent(context, ref, on),
              activeThumbColor: AppColors.primary,
              tileColor: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightSubtle,
              shape: RoundedRectangleBorder(
                borderRadius: AppSpacing.roundedMedium,
                side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              secondary: const Icon(LucideIcons.database, color: AppColors.primary, size: 24),
              title: Text(
                'Đóng góp dữ liệu để cải thiện phân loại',
                style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              subtitle: Text(
                trainingConsent
                    ? 'Đang bật: chỉ chữ hóa đơn đã ẩn thông tin cá nhân và danh mục bạn chọn, không ảnh. Tắt để xóa dữ liệu đã đóng góp.'
                    : 'Đang tắt. Bật để giúp FinMate phân loại hóa đơn chính xác hơn; bạn sẽ được xem chi tiết trước khi đồng ý.',
                style: AppTypography.caption(context).copyWith(fontSize: 11),
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () => _logout(context, ref),
              icon: const Icon(LucideIcons.logOut, size: 18, color: AppColors.danger),
              label: const Text('Đăng xuất tài khoản', style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
