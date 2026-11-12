import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

/// Màn H20: Đổi mật khẩu tài khoản (Change Password Screen)
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
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
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
      // Giả lập cập nhật mật khẩu cho đến khi endpoint backend hoàn tất
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đổi mật khẩu thành công!'),
          backgroundColor: AppColors.safe,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Mật khẩu hiện tại không chính xác hoặc không hợp lệ.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đổi mật khẩu'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      Text('Mật khẩu hiện tại', style: AppTypography.bodyMedium(context)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _oldPasswordController,
                        obscureText: _obscureOld,
                        decoration: InputDecoration(
                          hintText: 'Nhập mật khẩu hiện tại',
                          prefixIcon: const Icon(LucideIcons.lock, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureOld ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
                            onPressed: () => setState(() => _obscureOld = !_obscureOld),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Vui lòng nhập mật khẩu hiện tại.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      Text('Mật khẩu mới', style: AppTypography.bodyMedium(context)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        decoration: InputDecoration(
                          hintText: 'Tối thiểu 8 ký tự',
                          prefixIcon: const Icon(LucideIcons.keyRound, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureNew ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
                            onPressed: () => setState(() => _obscureNew = !_obscureNew),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.length < 8) {
                            return 'Mật khẩu mới phải từ 8 ký tự trở lên.';
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
                            icon: Icon(_obscureConfirm ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: (val) {
                          if (val != _newPasswordController.text) {
                            return 'Mật khẩu xác nhận không trùng khớp.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      LiquidGlassPillButton(
                        label: _isLoading ? 'Đang cập nhật...' : 'Cập nhật mật khẩu',
                        icon: LucideIcons.check,
                        isFullWidth: true,
                        onPressed: _isLoading ? () {} : _handleSubmit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
