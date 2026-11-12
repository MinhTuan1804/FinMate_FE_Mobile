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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _agreedToTerms = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      setState(() => _errorMessage = 'Vui lòng đồng ý với Điều khoản dịch vụ & Chính sách bảo mật.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      await ref.read(authControllerProvider.notifier).register(email, password, name);
      if (mounted) {
        // Chuyển sang màn hình xác thực OTP (BR-02)
        context.push('/verify-otp', extra: email);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = errorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final passwordsMatch =
        _confirmPasswordController.text.isNotEmpty && _confirmPasswordController.text == _passwordController.text;

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
                  Text('Bước 1/4', style: GlassTypography.labelCaps(color: GlassColors.slateAnchor)),
                  const SizedBox(height: 8),
                  Text('Chào mừng bạn đến với FinMate', style: GlassTypography.headlineLg()),
                  const SizedBox(height: 6),
                  Text(
                    'Bắt đầu hành trình quản lý tài chính thông minh, bảo mật và hoàn toàn tự động.',
                    style: GlassTypography.bodyMd(),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertCircle, color: GlassColors.danger, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_errorMessage!, style: GlassTypography.bodySm(color: GlassColors.danger))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  GlassTextField(
                    label: 'Họ và tên',
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    hintText: 'Nguyễn Văn A',
                    prefixIcon: LucideIcons.user,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Vui lòng nhập họ và tên';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  GlassTextField(
                    label: 'Địa chỉ email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    hintText: 'name@example.com',
                    prefixIcon: LucideIcons.mail,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Vui lòng nhập email';
                      if (!value.contains('@') || !value.contains('.')) return 'Email không đúng định dạng';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  GlassTextField(
                    label: 'Mật khẩu',
                    controller: _passwordController,
                    isPassword: true,
                    textInputAction: TextInputAction.next,
                    hintText: 'Tối thiểu 8 ký tự',
                    prefixIcon: LucideIcons.lock,
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
                      if (value.length < 8) return 'Mật khẩu phải có ít nhất 8 ký tự';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  GlassTextField(
                    label: 'Nhập lại mật khẩu',
                    controller: _confirmPasswordController,
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    hintText: 'Nhập lại mật khẩu vừa tạo',
                    prefixIcon: LucideIcons.lock,
                    onChanged: (_) => setState(() {}),
                    suffixIcon: passwordsMatch
                        ? const Icon(LucideIcons.checkCircle2, color: GlassColors.success, size: 20)
                        : null,
                    validator: (value) {
                      if (value != _passwordController.text) return 'Mật khẩu xác nhận không khớp';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreedToTerms,
                        onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                        activeColor: GlassColors.ink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Tôi đồng ý với Điều khoản dịch vụ & Chính sách bảo mật',
                            style: GlassTypography.bodySm(color: GlassColors.textPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.shieldCheck, color: GlassColors.success, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'FinMate cam kết Zero-Credential: Không bao giờ yêu cầu hay lưu trữ mật khẩu ngân hàng.',
                            style: GlassTypography.bodySm().copyWith(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  GlassPrimaryButton(
                    label: 'Tiếp tục (Nhận mã OTP)',
                    onPressed: _handleRegister,
                    loading: _isLoading,
                  ),

                  const SizedBox(height: 20),
                  _socialDivider(),
                  const SizedBox(height: 16),
                  GlassSecondaryButton(
                    label: 'Đăng ký nhanh với Google',
                    onPressed: () {
                      // Luồng Google Sign-In (lấy idToken) nằm ngoài phạm vi màn hình này.
                    },
                  ),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Đã có tài khoản? ', style: GlassTypography.bodySm()),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Text(
                          'Đăng nhập ngay',
                          style: GlassTypography.bodySm(color: GlassColors.ink).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
          child: Text('Hoặc đăng ký nhanh với', style: GlassTypography.bodySm()),
        ),
        const Expanded(child: Divider(color: GlassColors.secondarySurface, thickness: 1)),
      ],
    );
  }
}
