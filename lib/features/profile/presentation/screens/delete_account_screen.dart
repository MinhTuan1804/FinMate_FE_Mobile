import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/subscriptions/presentation/controllers/subscriptions_controller.dart';

/// Cụm từ xác nhận hợp lệ: có hoặc không dấu, không phân biệt hoa thường.
bool isDeleteConfirmation(String text) {
  final t = text.trim().toUpperCase();
  return t == 'XÓA TÀI KHOẢN' || t == 'XOA TAI KHOAN';
}

/// Màn H21: Xóa tài khoản vĩnh viễn (theo Figma). Danh sách "dữ liệu sẽ bị hủy" lấy từ dữ liệu thật của bạn (tổng số dư, số ví đang theo dõi,
/// gói đăng ký trả phí). Nút xóa chỉ bật khi đã nhập đúng cụm từ, có mật khẩu và đã tick xác nhận. Mục "Đặt lại dữ liệu" trong Figma chưa có tính năng nên không hiển thị.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirmationController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _acknowledged = false;
  bool _isLoading = false;
  bool _obscure = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _confirmationController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canDelete => !_isLoading && _acknowledged && isDeleteConfirmation(_confirmationController.text) && _passwordController.text.isNotEmpty;

  Future<void> _handleDelete() async {
    if (!_canDelete) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount(password: _passwordController.text);
      messenger.showSnackBar(
        const SnackBar(content: Text('Tài khoản đã bị khóa. Toàn bộ dữ liệu sẽ bị xóa vĩnh viễn sau 30 ngày.')),
      );
      router.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsControllerProvider).valueOrNull ?? const [];
    final plan = ref.watch(mySubscriptionProvider).valueOrNull;
    final total = accounts.fold(BigInt.zero, (sum, a) => sum + a.balanceCents);
    final monitored = accounts.where((a) => a.isMonitored).length;
    final items = <({IconData icon, String text})>[
      (
        icon: LucideIcons.wallet,
        text: accounts.isEmpty ? 'Hủy toàn bộ dữ liệu số dư và sổ chi tiêu đã lập' : 'Hủy toàn bộ ${formatVnd(total)} dữ liệu số dư và sổ chi tiêu đã lập',
      ),
      if (plan != null && !plan.isFree) (icon: LucideIcons.award, text: 'Xóa vĩnh viễn quyền truy cập gói ${plan.planName}'),
      if (monitored > 0) (icon: LucideIcons.unplug, text: 'Ngừng theo dõi $monitored tài khoản ngân hàng và ví điện tử'),
      (icon: LucideIcons.brain, text: 'Xóa toàn bộ nhật ký trò chuyện và ghi nhớ AI'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xóa tài khoản'),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: LiquidGlassIconButton(icon: LucideIcons.arrowLeft, size: 40, tooltip: 'Quay lại', onPressed: () => context.pop()),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.16), borderRadius: AppSpacing.roundedPill),
                child: const Text('VÙNG NGUY HIỂM', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.danger, letterSpacing: 0.4)),
              ),
            ),
          ),
        ],
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LiquidGlassCard(
                variant: LiquidGlassVariant.subtle,
                padding: const EdgeInsets.all(18),
                borderColor: AppColors.danger.withValues(alpha: 0.45),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.16), shape: BoxShape.circle),
                          child: const Icon(LucideIcons.triangleAlert, color: AppColors.danger, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bạn có chắc chắn muốn xóa tài khoản?',
                            style: AppTypography.h2(context).copyWith(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tài khoản bị khóa ngay và bạn bị đăng xuất khỏi mọi thiết bị. Sau 30 ngày, toàn bộ lịch sử thu chi, danh mục, ngân sách, mục tiêu và bộ nhớ học máy sẽ bị xóa vĩnh viễn khỏi hệ thống FinMate.',
                      style: AppTypography.caption(context).copyWith(fontSize: 13, height: 1.45),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.14), borderRadius: AppSpacing.roundedPill),
                      child: const Text('Không hoàn tác', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.danger)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LiquidGlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Dữ liệu sẽ bị hủy vĩnh viễn', style: AppTypography.h2(context).copyWith(fontSize: 16, fontWeight: FontWeight.w700))),
                        Text('${items.length} MỤC', style: AppTypography.sectionLabel(context)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.inset(context, 0.6), borderRadius: AppSpacing.roundedMedium),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.14), shape: BoxShape.circle),
                                child: Icon(item.icon, size: 18, color: AppColors.danger),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(item.text, style: AppTypography.body(context).copyWith(fontSize: 13.5, fontWeight: FontWeight.w600))),
                              const Icon(LucideIcons.x, size: 16, color: AppColors.danger),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                LiquidGlassCard(
                  variant: LiquidGlassVariant.subtle,
                  padding: const EdgeInsets.all(12),
                  borderColor: AppColors.danger,
                  child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 16),
              ],
              LiquidGlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Xác nhận hành động xóa', style: AppTypography.h2(context).copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Để đảm bảo an toàn, hãy gõ chính xác dòng chữ "XÓA TÀI KHOẢN" và nhập mật khẩu đăng nhập của bạn.', style: AppTypography.caption(context).copyWith(fontSize: 12.5)),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('delete-phrase'),
                      controller: _confirmationController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(hintText: 'Gõ "XÓA TÀI KHOẢN"'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('delete-password'),
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: 'Nhập mật khẩu hiện tại',
                        prefixIcon: const Icon(LucideIcons.lock, size: 18),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                          icon: Icon(_obscure ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      key: const ValueKey('delete-ack'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _acknowledged,
                      onChanged: (v) => setState(() => _acknowledged = v ?? false),
                      title: Text('Tôi hiểu rằng các dữ liệu tài chính của tôi sẽ biến mất vĩnh viễn.', style: AppTypography.caption(context).copyWith(fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('delete-submit'),
                onPressed: _canDelete ? _handleDelete : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.danger.withValues(alpha: 0.35),
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                icon: _isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(LucideIcons.trash2, size: 18),
                label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Xóa vĩnh viễn tài khoản của tôi', maxLines: 1)),
              ),
              const SizedBox(height: 10),
              LiquidGlassPillButton(
                key: const ValueKey('delete-cancel'),
                label: 'Giữ lại tài khoản (Hủy)',
                icon: LucideIcons.shield,
                isFullWidth: true,
                onPressed: _isLoading ? null : () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
