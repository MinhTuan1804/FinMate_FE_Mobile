import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

/// Màn H2: Chỉnh sửa hồ sơ (theo Figma). Hồ sơ chỉ có tên hiển thị và thu nhập hàng tháng để sửa; email chỉ đọc.
/// Ảnh đại diện, số điện thoại, đổi email và ngày nhận thu nhập trong Figma chưa có ở BE nên không hiển thị.
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
    final income = user?.monthlyIncomeCents;
    _incomeController = TextEditingController(text: income == null ? '' : NumberFormat('#,###', 'vi_VN').format(income));
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final income = parseAmountInput(_incomeController.text)!.toInt();
      await ref.read(authControllerProvider.notifier).updateProfile(
            displayName: _nameController.text.trim(),
            monthlyIncomeCents: income,
          );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));
      context.pop();
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final shownName = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : (user?.displayName ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ'),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: LiquidGlassIconButton(icon: LucideIcons.arrowLeft, size: 40, tooltip: 'Quay lại', onPressed: () => context.pop()),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AsyncActionBuilder(
              onPressed: _isLoading ? null : _handleSave,
              builder: (_, onTap, running) => FilledButton(
                key: const ValueKey('save-top'),
                onPressed: onTap,
                style: FilledButton.styleFrom(shape: const StadiumBorder(), visualDensity: VisualDensity.compact),
                child: running ? const ButtonLoadingIndicator() : const Text('Lưu'),
              ),
            ),
          ),
        ],
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                    child: Text(
                      shownName.isNotEmpty ? shownName[0].toUpperCase() : 'U',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primaryAction(context)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  shownName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h2(context).copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                LiquidGlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.idCard, size: 16, color: AppColors.textSecondary(context)),
                          const SizedBox(width: 8),
                          Text('THÔNG TIN CƠ BẢN', style: AppTypography.sectionLabel(context)),
                        ],
                      ),
                      const Divider(height: 24),
                      Text('Họ và tên', style: AppTypography.bodyMedium(context)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(hintText: 'Nhập tên của bạn', prefixIcon: Icon(LucideIcons.user, size: 18)),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Vui lòng nhập họ và tên.' : null,
                      ),
                      const SizedBox(height: 16),
                      Text('Email nhận thông báo giao dịch', style: AppTypography.bodyMedium(context)),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: user?.email ?? '',
                        readOnly: true,
                        decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.mail, size: 18), filled: true),
                      ),
                      const SizedBox(height: 6),
                      Text('Email dùng để đăng nhập nên không thể đổi.', style: AppTypography.caption(context).copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                LiquidGlassCard(
                  variant: LiquidGlassVariant.iridescentHero,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.25), shape: BoxShape.circle),
                            child: Icon(LucideIcons.sparkles, size: 18, color: AppColors.slateOn(context)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Thu nhập hàng tháng cho AI',
                                  style: AppTypography.h2(context).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Dùng để tính hạn mức chi an toàn mỗi ngày và tỷ lệ phân bổ các hũ chi tiêu.',
                                  style: AppTypography.caption(context).copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                        decoration: BoxDecoration(color: AppColors.inset(context, 0.85), borderRadius: AppSpacing.roundedLarge),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(LucideIcons.wallet, size: 14, color: AppColors.textSecondary(context)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Thu nhập ròng cố định / tháng',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption(context).copyWith(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            TextFormField(
                              key: const ValueKey('income-field'),
                              controller: _incomeController,
                              keyboardType: TextInputType.number,
                              style: AppTypography.tabular(AppTypography.displayBalance(context).copyWith(fontSize: 26, fontWeight: FontWeight.w800, fontVariations: [FontVariation('wght', FontWeight.w800.value.toDouble())])),
                              decoration: InputDecoration(
                                hintText: '15.000.000',
                                suffix: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.2), borderRadius: AppSpacing.roundedPill),
                                  child: Text('VND (₫)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slateOn(context))),
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Vui lòng nhập mức thu nhập hàng tháng.';
                                if (parseAmountInput(val) == null) return 'Số tiền không hợp lệ.';
                                return null;
                              },
                            ),
                          ],
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
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isLoading ? null : () => context.pop(),
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder()),
                  child: const Text('Hủy bỏ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
