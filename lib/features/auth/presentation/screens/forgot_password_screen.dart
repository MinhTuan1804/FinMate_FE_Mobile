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

/// a3 — Bước 1/3 của luồng khôi phục mật khẩu: nhập email để nhận mã xác thực.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    try {
      await ref.read(authControllerProvider.notifier).forgotPassword(email);
      if (mounted) context.push('/forgot-password-otp', extra: email);
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
            onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
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
                  Text('Bước 1/3', style: GlassTypography.labelCaps(color: GlassColors.slateAnchor)),
                  const SizedBox(height: 8),
                  Text('Quên mật khẩu?', style: GlassTypography.headlineLg()),
                  const SizedBox(height: 8),
                  Text(
                    'Nhập email đã liên kết với tài khoản của bạn, chúng tôi sẽ gửi mã xác thực.',
                    style: GlassTypography.bodyMd(),
                  ),
                  const SizedBox(height: 32),
                  GlassTextField(
                    label: 'Email',
                    controller: _emailController,
                    hintText: 'name@example.com',
                    prefixIcon: LucideIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Vui lòng nhập email.';
                      if (!value.contains('@') || !value.contains('.')) return 'Email không hợp lệ.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Mã OTP có hiệu lực trong 5 phút.', style: GlassTypography.bodySm()),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: GlassTypography.bodySm(color: GlassColors.danger)),
                  ],
                  const SizedBox(height: 28),
                  GlassPrimaryButton(label: 'Gửi mã xác thực', onPressed: _submit, loading: _isLoading),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
                      child: Text('Quay lại đăng nhập', style: GlassTypography.bodyMd(color: GlassColors.slateAnchor)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
