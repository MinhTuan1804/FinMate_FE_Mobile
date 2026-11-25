import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

/// Ba tiêu chí độ an toàn hiển thị bên dưới ô mật khẩu mới (tính ngay trên máy từ chữ đang gõ).
({bool length, bool upperAndDigit, bool special}) passwordChecks(String p) => (
      length: p.length >= 8,
      upperAndDigit: RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[0-9]').hasMatch(p),
      special: RegExp(r'[^A-Za-z0-9]').hasMatch(p),
    );

/// Màn H20: Đổi mật khẩu (theo Figma). BE thu hồi mọi phiên khi đổi mật khẩu nên sau khi xong app đăng xuất và mời đăng nhập lại.
/// Thanh độ an toàn chỉ là gợi ý cho người dùng; điều kiện bắt buộc vẫn là tối thiểu 8 ký tự như cũ.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final router = GoRouter.of(context);
    try {
      await ref.read(authControllerProvider.notifier).changePassword(
            currentPassword: _oldPasswordController.text,
            newPassword: _newPasswordController.text,
          );
      // BE thu hồi mọi phiên khi đổi mật khẩu: đăng xuất cục bộ rồi mời đăng nhập lại bằng mật khẩu mới
      router.go('/login', extra: {'notice': 'Đã đổi mật khẩu. Hãy đăng nhập lại bằng mật khẩu mới.'});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = errorMessage(e);
      });
    }
  }

  Widget _suffix(bool obscured, VoidCallback onToggle) => IconButton(
        tooltip: obscured ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
        icon: Icon(obscured ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
        onPressed: onToggle,
      );

  @override
  Widget build(BuildContext context) {
    final checks = passwordChecks(_newPasswordController.text);
    final score = [checks.length, checks.upperAndDigit, checks.special].where((v) => v).length;
    final hasInput = _newPasswordController.text.isNotEmpty;
    final strengthColor = switch (score) {
      <= 1 => AppColors.danger,
      2 => AppColors.warning,
      _ => AppColors.safe,
    };
    final strengthLabel = switch (score) {
      0 || 1 => 'Yếu',
      2 => 'Khá mạnh',
      _ => 'Mạnh',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đổi mật khẩu'),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: LiquidGlassIconButton(icon: LucideIcons.arrowLeft, size: 40, tooltip: 'Quay lại', onPressed: () => context.pop()),
        ),
        actions: [TextButton(onPressed: _isLoading ? null : () => context.pop(), child: const Text('Hủy'))],
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LiquidGlassCard(
                  variant: LiquidGlassVariant.iridescentHero,
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: AppColors.inset(context, 0.8), shape: BoxShape.circle),
                        child: Icon(LucideIcons.shieldCheck, size: 22, color: AppColors.slateOn(context)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text('Tăng cường bảo vệ', style: AppTypography.h2(context).copyWith(fontSize: 18, fontWeight: FontWeight.w700))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  LiquidGlassCard(
                    variant: LiquidGlassVariant.subtle,
                    padding: const EdgeInsets.all(14),
                    borderColor: AppColors.danger.withValues(alpha: 0.4),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.circleAlert, color: AppColors.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTypography.caption(context).copyWith(color: AppColors.danger, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                LiquidGlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Mật khẩu hiện tại', style: AppTypography.bodyMedium(context))),
                          TextButton(
                            key: const ValueKey('forgot-password'),
                            onPressed: () => context.push('/forgot-password'),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: const Text('Quên mật khẩu?'),
                          ),
                        ],
                      ),
                      TextFormField(
                        key: const ValueKey('old-password'),
                        controller: _oldPasswordController,
                        obscureText: _obscureOld,
                        decoration: InputDecoration(
                          hintText: 'Nhập mật khẩu hiện tại',
                          prefixIcon: const Icon(LucideIcons.lock, size: 18),
                          suffixIcon: _suffix(_obscureOld, () => setState(() => _obscureOld = !_obscureOld)),
                        ),
                        validator: (val) => (val == null || val.isEmpty) ? 'Vui lòng nhập mật khẩu hiện tại.' : null,
                      ),
                      const SizedBox(height: 16),
                      Text('Mật khẩu mới', style: AppTypography.bodyMedium(context)),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const ValueKey('new-password'),
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        decoration: InputDecoration(
                          hintText: 'Tối thiểu 8 ký tự',
                          prefixIcon: const Icon(LucideIcons.keyRound, size: 18),
                          suffixIcon: _suffix(_obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
                        ),
                        validator: (val) => (val == null || val.length < 8) ? 'Mật khẩu mới phải từ 8 ký tự trở lên.' : null,
                      ),
                      const SizedBox(height: 16),
                      Text('Xác nhận mật khẩu mới', style: AppTypography.bodyMedium(context)),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const ValueKey('confirm-password'),
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          hintText: 'Nhập lại mật khẩu mới',
                          prefixIcon: const Icon(LucideIcons.shieldCheck, size: 18),
                          suffixIcon: _suffix(_obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
                        ),
                        validator: (val) => val != _newPasswordController.text ? 'Mật khẩu xác nhận không trùng khớp.' : null,
                      ),
                      if (hasInput) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: Text('Độ an toàn mật khẩu', style: AppTypography.caption(context).copyWith(fontSize: 12))),
                            Text(strengthLabel, key: const ValueKey('strength-label'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: strengthColor)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            for (var i = 0; i < 3; i++)
                              Expanded(
                                child: Container(
                                  height: 6,
                                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                                  decoration: BoxDecoration(
                                    color: i < score ? strengthColor : AppColors.inset(context, 0.5),
                                    borderRadius: AppSpacing.roundedPill,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _rule(context, 'Tối thiểu 8 ký tự', checks.length),
                        _rule(context, 'Có ít nhất 1 chữ hoa và 1 chữ số', checks.upperAndDigit),
                        _rule(context, 'Có ít nhất 1 ký tự đặc biệt (@, #, \$, !...)', checks.special),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                LiquidGlassCard(
                  variant: LiquidGlassVariant.subtle,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.info, size: 18, color: AppColors.slateOn(context)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sau khi đổi mật khẩu, bạn sẽ được đăng xuất khỏi tất cả thiết bị và cần đăng nhập lại bằng mật khẩu mới.',
                          style: AppTypography.caption(context).copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                LiquidGlassPillButton(
                  key: const ValueKey('change-password-submit'),
                  label: _isLoading ? 'Đang cập nhật...' : 'Cập nhật mật khẩu',
                  icon: LucideIcons.refreshCw,
                  isFullWidth: true,
                  onPressed: _isLoading ? () {} : _handleSubmit,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isLoading ? null : () => context.pop(),
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder()),
                  child: const Text('Hủy bỏ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rule(BuildContext context, String text, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(ok ? LucideIcons.circleCheck : LucideIcons.circleMinus, size: 16, color: ok ? AppColors.safe : AppColors.textMuted(context)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTypography.caption(context).copyWith(fontSize: 13, color: ok ? AppColors.textPrimary(context) : AppColors.textMuted(context)))),
        ],
      ),
    );
  }
}
