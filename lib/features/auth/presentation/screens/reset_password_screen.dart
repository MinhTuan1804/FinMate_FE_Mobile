import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

/// Màn A4: Đặt lại mật khẩu mới
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String? initialEmail;

  const ResetPasswordScreen({super.key, this.initialEmail});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đổi mật khẩu thành công! Vui lòng đăng nhập với mật khẩu mới.'),
          backgroundColor: AppColors.safe,
        ),
      );
      context.go('/login', extra: {'email': _emailController.text.trim()});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Mã xác thực không hợp lệ hoặc đã hết hạn. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt lại mật khẩu'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: AmbientGlassBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Tạo mật khẩu mới',
                    style: AppTypography.h1(context).copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Nhập mã OTP 6 số đã được gửi tới email của bạn cùng mật khẩu mới an toàn.',
                    style: AppTypography.caption(context).copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    LiquidGlassCard(
                      variant: LiquidGlassVariant.subtle,
                      padding: const EdgeInsets.all(14),
                      borderColor: AppColors.danger.withValues(alpha: 0.4),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertCircle, color: AppColors.danger, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.caption(context).copyWith(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  ZenvestSurfaceSheet(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Mã xác thực OTP (6 chữ số)', style: AppTypography.bodyMedium(context)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            letterSpacing: 8,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: const InputDecoration(
                            counterText: '',
                            hintText: '••••••',
                            prefixIcon: Icon(LucideIcons.shieldCheck, size: 20),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().length != 6) {
                              return 'Vui lòng nhập đủ 6 chữ số OTP.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        Text('Mật khẩu mới', style: AppTypography.bodyMedium(context)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Tối thiểu 8 ký tự',
                            prefixIcon: const Icon(LucideIcons.lock, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Vui lòng nhập mật khẩu mới.';
                            }
                            if (val.length < 8) {
                              return 'Mật khẩu phải từ 8 ký tự trở lên.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        Text('Xác nhận mật khẩu mới', style: AppTypography.bodyMedium(context)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            hintText: 'Nhập lại mật khẩu mới',
                            prefixIcon: const Icon(LucideIcons.shieldCheck, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm ? LucideIcons.eyeOff : LucideIcons.eye,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (val) {
                            if (val != _passwordController.text) {
                              return 'Mật khẩu xác nhận không khớp.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),

                        LiquidGlassPillButton(
                          label: _isLoading ? 'Đang lưu...' : 'Lưu mật khẩu mới',
                          isFullWidth: true,
                          onPressed: _isLoading ? null : _handleSubmit,
                        ),
                      ],
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
