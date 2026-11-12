import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

/// Màn H2: Sửa hồ sơ cá nhân và thu nhập (Edit Profile Screen)
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _incomeController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).valueOrNull;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _incomeController = TextEditingController(
      text: user?.monthlyIncomeCents != null ? user!.monthlyIncomeCents.toString() : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final rawIncome = _incomeController.text.replaceAll('.', '').replaceAll(',', '').trim();
      final income = int.tryParse(rawIncome);
      await ref.read(authControllerProvider.notifier).updateProfile(
        displayName: _nameController.text.trim(),
        monthlyIncomeCents: income,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật hồ sơ thành công!'),
          backgroundColor: AppColors.safe,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể cập nhật: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sửa hồ sơ & Thu nhập'),
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
                // Avatar representation
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                        child: Text(
                          user?.displayName.isNotEmpty == true ? user!.displayName[0].toUpperCase() : 'U',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryAction(context),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primaryAction(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.camera,
                            size: 16,
                            color: AppColors.onPrimaryAction(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                ZenvestSurfaceSheet(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Họ và tên hiển thị', style: AppTypography.bodyMedium(context)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Nhập tên của bạn',
                          prefixIcon: Icon(LucideIcons.user, size: 18),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập họ và tên.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      Text('Thu nhập cố định hàng tháng (VNĐ)', style: AppTypography.bodyMedium(context)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _incomeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '15.000.000',
                          prefixIcon: Icon(LucideIcons.coins, size: 18),
                          suffixText: '₫',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập mức thu nhập hàng tháng.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Thu nhập được dùng để tính toán hạn mức ngân sách an toàn và tỷ lệ phân bổ các hũ chi tiêu.',
                        style: AppTypography.caption(context).copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: 20),

                      Text('Địa chỉ Email (Không thể đổi)', style: AppTypography.bodyMedium(context)),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: user?.email ?? '',
                        readOnly: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(LucideIcons.mail, size: 18),
                          filled: true,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                LiquidGlassPillButton(
                  label: _isLoading ? 'Đang lưu...' : 'Lưu thay đổi',
                  icon: LucideIcons.check,
                  isFullWidth: true,
                  onPressed: _isLoading ? () {} : _handleSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
