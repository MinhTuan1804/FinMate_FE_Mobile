import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';

/// Màn D3: Chuyển tiền giữa các ví / tài khoản (Transfer Screen)
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  FinancialAccount? _fromAccount;
  FinancialAccount? _toAccount;
  DateTime _transferDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromAccount == null || _toAccount == null) {
      setState(() => _errorMessage = 'Vui lòng chọn ví nguồn và ví đích.');
      return;
    }
    if (_fromAccount!.id == _toAccount!.id) {
      setState(() => _errorMessage = 'Ví nguồn và ví đích không được trùng nhau.');
      return;
    }

    final rawText = _amountController.text.replaceAll('.', '').replaceAll(',', '').trim();
    final amountInt = int.tryParse(rawText);
    if (amountInt == null || amountInt <= 0) {
      setState(() => _errorMessage = 'Số tiền chuyển không hợp lệ.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final amountCents = BigInt.from(amountInt);
      await ref.read(transactionControllerProvider.notifier).transferInternal(
        amountCents: amountCents,
        fromAccountId: _fromAccount!.id,
        toAccountId: _toAccount!.id,
        date: _transferDate,
        description: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : 'Chuyển tiền từ ${_fromAccount!.name} sang ${_toAccount!.name}',
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chuyển ${formatVnd(amountCents)} thành công!'),
          backgroundColor: AppColors.safe,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể thực hiện chuyển tiền: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountsControllerProvider);
    final accounts = accountsState.valueOrNull ?? [];

    if (_fromAccount == null && accounts.isNotEmpty) {
      _fromAccount = accounts.first;
      if (accounts.length > 1) {
        _toAccount = accounts[1];
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chuyển tiền nội bộ'),
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
                  const SizedBox(height: 16),
                ],

                // Amount Input Hero Card
                LiquidGlassCard(
                  variant: LiquidGlassVariant.iridescentHero,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    children: [
                      Text(
                        'SỐ TIỀN CHUYỂN',
                        style: AppTypography.caption(context).copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: IntrinsicWidth(
                              child: TextFormField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: AppTypography.displayBalance(context).copyWith(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '0',
                                  hintStyle: TextStyle(color: Colors.black26),
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty || val == '0') {
                                    return 'Vui lòng nhập số tiền.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '₫',
                            style: AppTypography.h2(context).copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Account Selection Card
                ZenvestSurfaceSheet(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Từ nguồn tiền', style: AppTypography.caption(context)),
                      const SizedBox(height: 6),
                      _accountDropdown(
                        selected: _fromAccount,
                        accounts: accounts,
                        onChanged: (val) => setState(() => _fromAccount = val),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            setState(() {
                              final temp = _fromAccount;
                              _fromAccount = _toAccount;
                              _toAccount = temp;
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primaryAction(context).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.arrowDownUp, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('Đến ví / tài khoản', style: AppTypography.caption(context)),
                      const SizedBox(height: 6),
                      _accountDropdown(
                        selected: _toAccount,
                        accounts: accounts,
                        onChanged: (val) => setState(() => _toAccount = val),
                      ),
                      const Divider(height: 28),
                      Text('Ghi chú chuyển tiền', style: AppTypography.bodyMedium(context)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          hintText: 'Ví dụ: Nạp tiền vào ví MoMo, Chuyển tiết kiệm...',
                          prefixIcon: Icon(LucideIcons.fileText, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                LiquidGlassPillButton(
                  label: _isLoading ? 'Đang xử lý...' : 'Xác nhận chuyển tiền',
                  icon: LucideIcons.arrowRight,
                  isFullWidth: true,
                  onPressed: _isLoading ? () {} : _handleSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _accountDropdown({
    required FinancialAccount? selected,
    required List<FinancialAccount> accounts,
    required ValueChanged<FinancialAccount?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLightSubtle.withValues(alpha: 0.6),
        borderRadius: AppSpacing.roundedLarge,
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<FinancialAccount>(
          value: selected,
          isExpanded: true,
          items: accounts.map((acc) {
            return DropdownMenuItem<FinancialAccount>(
              value: acc,
              child: Row(
                children: [
                  Icon(LucideIcons.wallet, size: 18, color: AppColors.primaryAction(context)),
                  const SizedBox(width: 10),
                  Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    formatVnd(acc.balanceCents),
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
