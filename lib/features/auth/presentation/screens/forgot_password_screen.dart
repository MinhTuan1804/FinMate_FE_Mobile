import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

/// Màn A3: Quên mật khẩu
/// Giao diện Serene Liquid Glass: nhập email để nhận mã OTP hoặc liên kết đặt lại mật khẩu
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Giả lập hoặc gọi API gửi mã đặt lại mật khẩu
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSent = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể gửi yêu cầu đặt lại mật khẩu. Vui lòng thử lại sau.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quên mật khẩu'),
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
                  // Icon đầu trang nổi bật trên nền kính
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.keyRound,
                          size: 30,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Khôi phục mật khẩu',
                    textAlign: TextAlign.center,
                    style: AppTypography.h1(context).copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nhập email đã đăng ký với FinMate. Chúng tôi sẽ gửi hướng dẫn và mã xác thực để bạn tạo mật khẩu mới.',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption(context).copyWith(
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),

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

                  if (_isSent) ...[
                    LiquidGlassCard(
                      variant: LiquidGlassVariant.standard,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.safe.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.mailCheck, color: AppColors.safe, size: 26),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Đã gửi liên kết khôi phục!',
                            style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Vui lòng kiểm tra hộp thư đến của ${_emailController.text.trim()} và làm theo hướng dẫn.',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption(context),
                          ),
                          const SizedBox(height: 20),
                          LiquidGlassPillButton(
                            label: 'Nhập mã đặt lại mật khẩu',
                            icon: LucideIcons.arrowRight,
                            isFullWidth: true,
                            onPressed: () {
                              context.push(
                                '/reset-password',
                                extra: _emailController.text.trim(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ZenvestSurfaceSheet(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Địa chỉ Email', style: AppTypography.bodyMedium(context)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'name@example.com',
                              prefixIcon: Icon(LucideIcons.mail, size: 18),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Vui lòng nhập địa chỉ email.';
                              }
                              if (!val.contains('@') || !val.contains('.')) {
                                return 'Địa chỉ email không hợp lệ.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          LiquidGlassPillButton(
                            label: _isLoading ? 'Đang gửi...' : 'Gửi yêu cầu',
                            isFullWidth: true,
                            onPressed: _isLoading ? null : _handleSubmit,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(LucideIcons.arrowLeft, size: 16),
                      label: const Text('Quay lại đăng nhập'),
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
