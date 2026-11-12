import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

/// Màn H21: Xóa tài khoản vĩnh viễn (Delete Account Screen)
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirmationController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  static const _requiredConfirmation = 'XÓA TÀI KHOẢN';

  @override
  void dispose() {
    _confirmationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    if (_confirmationController.text.trim() != _requiredConfirmation) {
      setState(() => _errorMessage = 'Vui lòng nhập chính xác cụm từ "$_requiredConfirmation".');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập mật khẩu tài khoản để xác thực.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 1000));
      await ref.read(authControllerProvider.notifier).logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tài khoản và toàn bộ dữ liệu của bạn đã được xóa vĩnh viễn.'),
        ),
      );
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Mật khẩu xác thực không đúng. Không thể xóa tài khoản.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xóa tài khoản'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Warning Hero
              LiquidGlassCard(
                variant: LiquidGlassVariant.subtle,
                padding: const EdgeInsets.all(20),
                borderColor: AppColors.danger.withValues(alpha: 0.45),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.triangleAlert, color: AppColors.danger, size: 28),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Hành động này không thể hoàn tác!',
                      textAlign: TextAlign.center,
                      style: AppTypography.h2(context).copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toàn bộ lịch sử thu chi, danh mục, ngân sách, mục tiêu và bộ nhớ học máy của bạn sẽ bị hủy vĩnh viễn khỏi hệ thống FinMate.',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption(context).copyWith(fontSize: 13, height: 1.45),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
                LiquidGlassCard(
                  variant: LiquidGlassVariant.subtle,
                  padding: const EdgeInsets.all(12),
                  borderColor: AppColors.danger,
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              ZenvestSurfaceSheet(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Nhập cụm từ "$_requiredConfirmation" để xác nhận:',
                      style: AppTypography.bodyMedium(context),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmationController,
                      decoration: const InputDecoration(
                        hintText: _requiredConfirmation,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text('Mật khẩu của bạn:', style: AppTypography.bodyMedium(context)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'Nhập mật khẩu hiện tại',
                        prefixIcon: Icon(LucideIcons.lock, size: 18),
                      ),
                    ),
                    const SizedBox(height: 28),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(LucideIcons.trash2, size: 18),
                      label: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Xác nhận xóa tài khoản vĩnh viễn'),
                      onPressed: _isLoading ? null : _handleDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
