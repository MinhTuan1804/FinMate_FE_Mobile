import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';

/// Màn H7 & H8: Quản lý Tài khoản & Nguồn tiền (Financial Accounts Management)
class FinancialAccountsScreen extends ConsumerWidget {
  const FinancialAccountsScreen({super.key});

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final balanceController = TextEditingController();
    AccountType selectedType = AccountType.bank;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Thêm tài khoản mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Tên tài khoản (Ví dụ: Techcombank, Tiền mặt...)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AccountType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Loại tài khoản'),
                  items: const [
                    DropdownMenuItem(value: AccountType.bank, child: Text('Tài khoản ngân hàng')),
                    DropdownMenuItem(value: AccountType.eWallet, child: Text('Ví điện tử (MoMo, ZaloPay...)')),
                    DropdownMenuItem(value: AccountType.cash, child: Text('Tiền mặt')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Số dư ban đầu', suffixText: '₫'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                final raw = balanceController.text.replaceAll('.', '').replaceAll(',', '').trim();
                final balance = int.tryParse(raw);
                if (nameController.text.trim().isNotEmpty) {
                  await ref.read(accountsControllerProvider.notifier).create(
                    name: nameController.text.trim(),
                    type: selectedType,
                    initialBalanceCents: balance != null ? BigInt.from(balance) : BigInt.zero,
                  );
                  if (context.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Tạo tài khoản'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(AccountType type) {
    return switch (type) {
      AccountType.bank => LucideIcons.landmark,
      AccountType.eWallet => LucideIcons.smartphone,
      AccountType.cash => LucideIcons.banknote,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản & Nguồn tiền'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAccountDialog(context, ref),
        backgroundColor: AppColors.primaryAction(context),
        foregroundColor: AppColors.onPrimaryAction(context),
        icon: const Icon(LucideIcons.plus, size: 18),
        label: const Text('Thêm tài khoản'),
      ),
      body: AmbientGlassBackground(
        child: RefreshIndicator(
          onRefresh: () => ref.read(accountsControllerProvider.notifier).load(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                accountsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => LiquidGlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text('Không thể tải danh sách tài khoản'),
                        TextButton(
                          onPressed: () => ref.read(accountsControllerProvider.notifier).load(),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                  data: (accounts) {
                    final total = accounts.fold(BigInt.zero, (sum, a) => sum + a.balanceCents);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Hero Total Assets
                        ZenvestHeroDeck(
                          peekBadgeText: 'TOTAL',
                          child: LiquidGlassCard(
                            variant: LiquidGlassVariant.iridescentHero,
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TỔNG SỐ DƯ TẤT CẢ NGUỒN TIỀN',
                                  style: AppTypography.caption(context).copyWith(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  formatVnd(total),
                                  style: AppTypography.displayBalance(context).copyWith(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Đang theo dõi ${accounts.length} tài khoản & ví thanh toán.',
                                  style: AppTypography.caption(context),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text('DANH SÁCH VÍ & TÀI KHOẢN', style: AppTypography.sectionLabel(context)),
                        const SizedBox(height: 12),

                        for (final acc in accounts) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: LiquidGlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withValues(alpha: 0.14),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        _iconForType(acc.type),
                                        size: 22,
                                        color: AppColors.primaryAction(context),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          acc.name,
                                          style: AppTypography.body(context).copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          acc.type.label,
                                          style: AppTypography.caption(context).copyWith(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatVnd(acc.balanceCents),
                                    style: AppTypography.tabular(
                                      AppTypography.body(context).copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
