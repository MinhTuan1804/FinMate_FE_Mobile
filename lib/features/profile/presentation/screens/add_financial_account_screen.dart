import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';

/// Màn H8: Thêm tài khoản nguồn tiền (theo Figma). Gửi lên API đúng các trường BE nhận: tên, loại, nguồn (ngân hàng/ví) và số dư ban đầu.
/// Số tài khoản, tên chủ tài khoản, "đặt làm mặc định" và "đồng bộ tự động" trong Figma chưa có ở BE nên không hiển thị;
/// thẻ tín dụng chưa là một loại tài khoản của BE nên không có tab.
class AddFinancialAccountScreen extends ConsumerStatefulWidget {
  const AddFinancialAccountScreen({super.key});

  @override
  ConsumerState<AddFinancialAccountScreen> createState() => _AddFinancialAccountScreenState();
}

class _AddFinancialAccountScreenState extends ConsumerState<AddFinancialAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  AccountType _type = AccountType.bank;
  String? _providerId;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  IconData _icon(AccountType t) => switch (t) {
        AccountType.bank => LucideIcons.landmark,
        AccountType.eWallet => LucideIcons.wallet,
        AccountType.cash => LucideIcons.banknote,
      };

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final balanceText = _balanceController.text.trim();
      await ref.read(accountsControllerProvider.notifier).create(
            name: _nameController.text.trim(),
            type: _type,
            providerConfigId: _providerId,
            initialBalanceCents: balanceText.isEmpty ? BigInt.zero : parseAmountInput(balanceText, allowZero: true),
          );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Đã thêm tài khoản.')));
      context.pop();
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(accountProvidersProvider);
    final options = (providers.valueOrNull ?? const <AccountProviderInfo>[]).where((p) => p.type == _type).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm tài khoản nguồn'),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: LiquidGlassIconButton(icon: LucideIcons.arrowLeft, size: 40, tooltip: 'Quay lại', onPressed: () => context.pop()),
        ),
        actions: [TextButton(onPressed: _busy ? null : () => context.pop(), child: const Text('Hủy'))],
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('LOẠI NGUỒN TIỀN', style: AppTypography.sectionLabel(context)),
                ),
                Row(
                  children: [
                    for (final t in AccountType.values)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _typeTile(context, t),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                LiquidGlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_type != AccountType.cash) ...[
                        Text(_type == AccountType.bank ? 'Ngân hàng liên kết' : 'Ví điện tử', style: AppTypography.bodyMedium(context)),
                        const SizedBox(height: 8),
                        providers.when(
                          loading: () => const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
                          error: (e, _) => Row(
                            children: [
                              Expanded(child: Text(errorMessage(e), style: AppTypography.caption(context))),
                              TextButton(onPressed: () => ref.invalidate(accountProvidersProvider), child: const Text('Thử lại')),
                            ],
                          ),
                          data: (_) => DropdownButtonFormField<String?>(
                            key: ValueKey('provider-${_type.name}'),
                            initialValue: _providerId,
                            isExpanded: true,
                            decoration: InputDecoration(prefixIcon: Icon(_icon(_type), size: 18)),
                            hint: const Text('Không chọn (tự đặt tên)'),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Không chọn (tự đặt tên)')),
                              for (final p in options) DropdownMenuItem<String?>(value: p.id, child: Text(p.displayName, overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) => setState(() {
                              _providerId = v;
                              final name = options.where((p) => p.id == v).map((p) => p.displayName).firstOrNull;
                              if (name != null && _nameController.text.trim().isEmpty) _nameController.text = name;
                            }),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text('Đặt tên gợi nhớ *', style: AppTypography.bodyMedium(context)),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const ValueKey('account-name'),
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(hintText: 'Ví dụ: Tài khoản chi tiêu chính', prefixIcon: Icon(LucideIcons.tag, size: 18)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên gợi nhớ.' : null,
                      ),
                      const SizedBox(height: 16),
                      Text('Số dư ban đầu', style: AppTypography.bodyMedium(context)),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const ValueKey('account-balance'),
                        controller: _balanceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '0', prefixIcon: Icon(LucideIcons.banknote, size: 18), suffixText: '₫'),
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.isEmpty) return null;
                          return parseAmountInput(t, allowZero: true) == null ? 'Số tiền không hợp lệ.' : null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LiquidGlassCard(
                  variant: LiquidGlassVariant.subtle,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.shieldCheck, size: 20, color: AppColors.textSecondary(context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cam kết bảo mật', style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              'FinMate không bao giờ yêu cầu hay lưu mật khẩu ngân hàng. Bạn chỉ nhập tên gợi nhớ và số dư ban đầu.',
                              style: AppTypography.caption(context).copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                LiquidGlassPillButton(
                  key: const ValueKey('account-submit'),
                  label: _busy ? 'Đang thêm...' : 'Thêm tài khoản',
                  icon: LucideIcons.circlePlus,
                  isFullWidth: true,
                  onPressed: _busy ? () {} : _submit,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : () => context.pop(),
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

  Widget _typeTile(BuildContext context, AccountType t) {
    final selected = _type == t;
    return Semantics(
      button: true,
      selected: selected,
      label: t.label,
      child: InkWell(
        key: ValueKey('type-${t.name}'),
        borderRadius: AppSpacing.roundedMedium,
        onTap: () => setState(() {
          _type = t;
          _providerId = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryAction(context) : AppColors.inset(context),
            borderRadius: AppSpacing.roundedMedium,
          ),
          child: Column(
            children: [
              Icon(_icon(t), size: 18, color: selected ? AppColors.onPrimaryAction(context) : AppColors.textSecondary(context)),
              const SizedBox(height: 4),
              Text(
                t.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: selected ? AppColors.onPrimaryAction(context) : AppColors.textSecondary(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
