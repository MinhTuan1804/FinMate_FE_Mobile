import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/auth/domain/entities/consent.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/auth/presentation/screens/training_consent_screen.dart';

/// Màn H11: Quản lý quyền đồng ý. Trạng thái lấy từ hồ sơ người dùng (server tính), bật/tắt gọi server ngay;
/// lỗi thì công tắc giữ nguyên. Điều khoản là bắt buộc nên không rút lại được ở đây.
class ConsentManagementScreen extends ConsumerStatefulWidget {
  const ConsentManagementScreen({super.key});

  @override
  ConsumerState<ConsentManagementScreen> createState() => _ConsentManagementScreenState();
}

class _ConsentManagementScreenState extends ConsumerState<ConsentManagementScreen> {
  /// Đang gọi server cho quyền này: khóa công tắc để không bấm chồng.
  ConsentKind? _busy;

  void _toast(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleAi(bool on) async {
    setState(() => _busy = ConsentKind.ai);
    try {
      final auth = ref.read(authControllerProvider.notifier);
      await (on ? auth.acceptConsent(ConsentKind.ai) : auth.withdrawConsent(ConsentKind.ai));
      _toast(on ? 'Đã bật tính năng AI.' : 'Đã tắt tính năng AI.');
    } on Object catch (e) {
      _toast(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _toggleTraining(bool on) async {
    if (on) {
      // Màn đồng ý tự ghi đồng ý lên server khi người dùng chấp nhận.
      await ensureTrainingConsent(context, ref);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Tắt đóng góp dữ liệu?'),
        content: const Text('Từ giờ FinMate không thu thêm dữ liệu của bạn, và dữ liệu bạn đã đóng góp sẽ bị xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Rút lại và xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = ConsentKind.training);
    try {
      await ref.read(authControllerProvider.notifier).withdrawConsent(ConsentKind.training);
      _toast('Đã rút lại đồng ý đóng góp dữ liệu.');
    } on Object catch (e) {
      _toast(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý quyền & AI'),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: LiquidGlassIconButton(icon: LucideIcons.arrowLeft, size: 40, tooltip: 'Quay lại', onPressed: () => context.pop()),
        ),
      ),
      body: AmbientGlassBackground(
        child: user != null
            ? _content(context, user)
            : auth.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _LoadError(
                    message: auth.hasError ? errorMessage(auth.error!) : 'Không tải được thông tin tài khoản.',
                    onRetry: () => ref.read(authControllerProvider.notifier).checkAuthStatus(),
                  ),
      ),
    );
  }

  Widget _content(BuildContext context, UserProfile user) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        LiquidGlassCard(
          variant: LiquidGlassVariant.subtle,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.safe.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(LucideIcons.shieldCheck, color: AppColors.safe, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MINH BẠCH TUYỆT ĐỐI', style: AppTypography.sectionLabel(context)),
                    const SizedBox(height: 4),
                    Text(
                      'Bạn có toàn quyền kiểm soát, bật hoặc thu hồi sự đồng ý đối với dữ liệu của mình bất cứ lúc nào.',
                      style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text('Bản v${ConsentVersions.terms}', style: AppTypography.caption(context).copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Text('Cài đặt sự đồng ý', style: AppTypography.h2(context).copyWith(fontSize: 18, fontWeight: FontWeight.w700))),
            Text('3 mục cấu hình', style: AppTypography.caption(context).copyWith(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        _row(
          context,
          switchKey: 'consent-terms',
          title: 'Điều khoản dịch vụ & Chính sách',
          description: 'Bắt buộc để sử dụng dịch vụ và đảm bảo tính pháp lý giao dịch tài chính. Chỉ thu hồi được bằng cách Xóa tài khoản.',
          granted: user.termsAccepted,
          onChanged: null,
          badge: 'Bắt buộc',
          onText: 'Đã đồng ý',
          offText: 'Chưa đồng ý',
        ),
        _row(
          context,
          switchKey: 'consent-ai',
          title: 'Tính năng Trợ lý AI FinMate',
          description: 'Cho phép gửi tên món và cụm sản phẩm (đã bỏ số tiền) cho dịch vụ AI để trò chuyện và phân loại hóa đơn.',
          granted: user.aiConsentGranted,
          onChanged: _busy == null ? _toggleAi : null,
        ),
        _row(
          context,
          switchKey: 'consent-training',
          title: 'Đóng góp huấn luyện mô hình (AI Training)',
          description: 'Chữ hóa đơn đã ẩn thông tin cá nhân được dùng để cải thiện độ chính xác của AI. Tắt thì dữ liệu đã đóng góp bị xóa.',
          granted: user.trainingConsentGranted,
          onChanged: _busy == null ? _toggleTraining : null,
          onText: 'Đang đóng góp',
          offText: 'Chưa kích hoạt',
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.info, size: 20, color: AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lưu ý khi thu hồi quyền', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      'Khi tắt trợ lý AI, các tính năng dùng AI như trò chuyện và phân loại hóa đơn sẽ tạm ngừng. Tắt đóng góp dữ liệu sẽ xóa dữ liệu bạn đã đóng góp.',
                      style: AppTypography.caption(context).copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required String switchKey,
    required String title,
    required String description,
    required bool granted,
    required ValueChanged<bool>? onChanged,
    String? badge,
    String onText = 'Đang bật',
    String offText = 'Chưa cấp quyền / Đã thu hồi',
    Widget? footerAction,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(title, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.22), borderRadius: AppSpacing.roundedPill),
                          child: Text(badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.slateOn(context))),
                        ),
                    ],
                  ),
                ),
                Switch(key: ValueKey(switchKey), value: granted, onChanged: onChanged),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: AppTypography.caption(context).copyWith(fontSize: 13, color: AppColors.textSecondary(context)),
            ),
            const Divider(height: 20),
            Row(
              children: [
                Icon(granted ? LucideIcons.shieldCheck : LucideIcons.circleOff, size: 14, color: granted ? AppColors.safe : AppColors.textMuted(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    granted ? onText : offText,
                    style: AppTypography.caption(context).copyWith(
                      fontSize: 12,
                      color: granted ? AppColors.safe : AppColors.textMuted(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (footerAction != null) footerAction,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: AppTypography.body(context)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
