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
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_text_field.dart';

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

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: GlassColors.ink),
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Chào mừng trở lại', style: GlassTypography.headlineLg()),
                  const SizedBox(height: 8),
                  Text('Đăng nhập để tiếp tục quản lý chi tiêu cá nhân', style: GlassTypography.bodyMd()),
                  const SizedBox(height: 28),

                  if (_notice != null) ...[
                    GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.info, color: GlassColors.slateAnchor, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_notice!, style: GlassTypography.bodySm(color: GlassColors.textPrimary))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (_error != null) ...[
                    GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertCircle, color: GlassColors.danger, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_error!, style: GlassTypography.bodySm(color: GlassColors.danger))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  GlassTextField(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    hintText: 'name@example.com',
                    prefixIcon: LucideIcons.mail,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Vui lòng nhập email.';
                      if (!value.contains('@') || !value.contains('.')) return 'Email không hợp lệ.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  GlassTextField(
                    label: 'Mật khẩu',
                    controller: _passwordController,
                    isPassword: true,
                    hintText: 'Nhập mật khẩu của bạn',
                    prefixIcon: LucideIcons.lock,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu.';
                      if (value.length < 8) return 'Mật khẩu tối thiểu 8 ký tự.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: Text(
                        'Quên mật khẩu?',
                        style: GlassTypography.bodyMd(color: GlassColors.slateAnchor).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  GlassPrimaryButton(label: 'Đăng nhập', onPressed: _submit, loading: isLoading),

                  const SizedBox(height: 20),
                  _socialDivider(),
                  const SizedBox(height: 16),
                  GlassSecondaryButton(
                    label: 'Đăng nhập với Google',
                    onPressed: () {
                      // Luồng Google Sign-In (lấy idToken) nằm ngoài phạm vi màn hình này.
                    },
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Chưa có tài khoản? ', style: GlassTypography.bodySm()),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: Text(
                          'Đăng ký ngay',
                          style: GlassTypography.bodySm(color: GlassColors.ink).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: GlassColors.secondarySurface, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Hoặc đăng nhập với', style: GlassTypography.bodySm()),
        ),
        const Expanded(child: Divider(color: GlassColors.secondarySurface, thickness: 1)),
      ],
    );
  }
}
