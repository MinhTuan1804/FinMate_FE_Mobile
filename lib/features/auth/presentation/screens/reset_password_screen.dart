import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_text_field.dart';
import 'package:finmate/shared/widgets/glass/password_strength_meter.dart';

/// a4 — Bước 3/3 của luồng khôi phục mật khẩu: đặt mật khẩu mới.
/// Email + mã đến từ [ForgotPasswordOtpScreen]; sai mã sẽ được server báo lỗi ở đây.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  final String code;

  const ResetPasswordScreen({super.key, required this.email, required this.code});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).resetPassword(
            email: widget.email,
            code: widget.code,
            newPassword: _passwordController.text,
          );
      if (mounted) {
        context.go('/login', extra: {
          'email': widget.email,
          'notice': 'Mật khẩu đã được cập nhật. Vui lòng đăng nhập lại.',
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: GlassColors.ink),
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Bước 3/3', style: GlassTypography.labelCaps(color: GlassColors.slateAnchor)),
                  const SizedBox(height: 8),
                  Text('Đặt lại mật khẩu', style: GlassTypography.headlineLg()),
                  const SizedBox(height: 8),
                  Text('Tạo một mật khẩu mới, đủ mạnh để bảo vệ tài khoản của bạn.', style: GlassTypography.bodyMd()),
                  const SizedBox(height: 28),
                  GlassTextField(
                    label: 'Mật khẩu mới',
                    controller: _passwordController,
                    isPassword: true,
                    prefixIcon: LucideIcons.lock,
                    hintText: 'Tối thiểu 8 ký tự',
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu mới.';
                      if (value.length < 8) return 'Mật khẩu tối thiểu 8 ký tự.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  PasswordStrengthMeter(password: _passwordController.text),
                  const SizedBox(height: 20),
                  GlassTextField(
                    label: 'Xác nhận mật khẩu mới',
                    controller: _confirmController,
                    isPassword: true,
                    prefixIcon: LucideIcons.lock,
                    hintText: 'Nhập lại mật khẩu mới',
                    validator: (value) {
                      if (value != _passwordController.text) return 'Mật khẩu xác nhận không khớp.';
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: GlassTypography.bodySm(color: GlassColors.danger)),
                  ],
                  const SizedBox(height: 28),
                  GlassPrimaryButton(label: 'Cập nhật mật khẩu', onPressed: _submit, loading: _isLoading),
                  const SizedBox(height: 12),
                  GlassGhostButton(label: 'Hủy bỏ', onPressed: () => context.go('/login')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
