import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? initialEmail;

  /// Thông báo hiển thị một lần (ví dụ: vừa xác thực email xong)
  final String? notice;

  const LoginScreen({super.key, this.initialEmail, this.notice});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController = TextEditingController(text: widget.initialEmail);
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _notice = widget.notice;
    // Phiên hết hạn: router đưa người dùng về đây và bật cờ này
    if (ref.read(sessionExpiredProvider)) {
      _notice = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      Future.microtask(() => ref.read(sessionExpiredProvider.notifier).state = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _notice = null;
    });

    await ref.read(authControllerProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (!mounted) return;
    final authState = ref.read(authControllerProvider);
    final error = authState.error;
    final notVerified = error is ApiException && error.code == 'AUTH_EMAIL_NOT_VERIFIED';
    setState(() {
      _isLoading = false;
      _error = authState.hasError && !notVerified ? errorMessage(error!) : null;
    });
    if (notVerified) {
      context.push('/verify-otp', extra: _emailController.text.trim());
      return;
    }

    // Tài khoản đã xác thực sẽ được router tự chuyển đi; chỉ cần xử lý trường hợp chưa xác thực email
    final user = authState.valueOrNull;
    if (user != null && !user.isEmailVerified) {
      context.push('/verify-otp', extra: user.email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Chào mừng trở lại',
                  style: AppTypography.h1(context),
                ),
                const SizedBox(height: 8),
                Text(
                  'Đăng nhập để tiếp tục quản lý chi tiêu cá nhân',
                  style: AppTypography.body(context).copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 32),

                // Thông báo (ví dụ: đã xác thực email / phiên hết hạn)
                if (_notice != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppSpacing.roundedMedium,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.info, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _notice!,
                            style: const TextStyle(color: AppColors.primary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Error Banner if login fails
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: AppSpacing.roundedMedium,
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.alertCircle, color: AppColors.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.danger, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Email Field
                Text('Email', style: AppTypography.bodyMedium(context)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'name@example.com',
                    prefixIcon: Icon(LucideIcons.mail, size: 18),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Vui lòng nhập email.';
                    if (!value.contains('@') || !value.contains('.')) return 'Email không hợp lệ.';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Password Field
                Text('Mật khẩu', style: AppTypography.bodyMedium(context)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Nhập mật khẩu của bạn',
                    prefixIcon: const Icon(LucideIcons.lock, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu.';
                    if (value.length < 8) return 'Mật khẩu tối thiểu 8 ký tự.';
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Đăng nhập',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),

                const SizedBox(height: 24),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Chưa có tài khoản? ',
                      style: AppTypography.caption(context),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: Text(
                        'Đăng ký ngay',
                        style: AppTypography.caption(context).copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
