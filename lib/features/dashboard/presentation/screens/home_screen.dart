import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/analytics/presentation/reports_providers.dart';
import 'package:finmate/features/assistant/presentation/widgets/assistant_prompt_bar.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:finmate/features/transactions/presentation/widgets/create_transaction_bottom_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authControllerProvider).value;
    final txState = ref.watch(transactionControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header (User Welcome & Notification)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xin chào,',
                        style: AppTypography.caption(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.displayName ?? 'Bạn của FinMate',
                        style: AppTypography.h3(context).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.circleUser, size: 24),
                        onPressed: () => context.push('/profile'),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 2. Balance Card (Neo-Fintech Minimalist)
              _buildBalanceCard(context, ref, isDark),

              const SizedBox(height: 16),

              const AssistantPromptBar(),

              const SizedBox(height: 16),

              // 4. Quick Action Buttons
              _buildQuickActions(context),

              const SizedBox(height: 24),

              // 5. Recent Transactions Header & List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'GIAO DỊCH GẦN ĐÂY',
                    style: AppTypography.caption(context).copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/transactions'),
                    child: const Text('Xem tất cả'),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              txState.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, __) => const Text('Không thể tải giao dịch'),
                data: (transactions) {
                  final recents = transactions.take(4).toList();
                  if (recents.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        borderRadius: AppSpacing.roundedMedium,
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Chưa có giao dịch nào.\nHãy bấm "Ghi chép" để thêm giao dịch đầu tiên!',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption(context),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: recents.map((tx) => _buildTransactionItem(context, tx, isDark)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context, 0),
    );
  }

  Widget _buildBalanceCard(BuildContext context, WidgetRef ref, bool isDark) {
    final accounts = ref.watch(accountsControllerProvider);
    final summary = ref.watch(monthlySummaryProvider);

    // Số dư = tổng số dư các tài khoản; thu/chi tháng từ báo cáo của backend (không số giả)
    final balanceText = accounts.when(
      data: (list) => formatVnd(list.fold(BigInt.zero, (sum, a) => sum + a.balanceCents)),
      loading: () => '...',
      error: (_, __) => '—',
    );
    final hasNoAccount = accounts.valueOrNull?.isEmpty ?? false;
    final hasError = accounts.hasError || summary.hasError;
    final income = summary.valueOrNull == null ? '—' : '+${formatVnd(summary.value!.totalIncomeCents)}';
    final expense = summary.valueOrNull == null ? '—' : '-${formatVnd(summary.value!.totalSpentCents)}';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedLarge,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TỔNG TÀI SẢN KHẢ DỤNG',
            style: AppTypography.caption(context).copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            balanceText,
            style: AppTypography.tabular(
              AppTypography.moneyLarge.copyWith(
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ),
          if (hasNoAccount) ...[
            const SizedBox(height: 4),
            Text(
              'Bạn chưa có tài khoản. Bấm "Ghi chép" để tạo ví đầu tiên.',
              style: AppTypography.caption(context),
            ),
          ],
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _flowItem(context, 'Thu nhập', income, LucideIcons.arrowDownLeft, AppColors.income)),
              Expanded(child: _flowItem(context, 'Chi tiêu', expense, LucideIcons.arrowUpRight, AppColors.expense)),
            ],
          ),
          if (hasError)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  ref.invalidate(monthlySummaryProvider);
                  ref.read(accountsControllerProvider.notifier).load();
                },
                child: const Text('Thử lại'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _flowItem(BuildContext context, String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.caption(context)),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.tabular(
                  AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionItem(
          context,
          icon: LucideIcons.plus,
          label: 'Ghi chép',
          onTap: () => CreateTransactionBottomSheet.show(context),
          highlight: true,
        ),
        _buildActionItem(
          context,
          icon: LucideIcons.target,
          label: 'Kế hoạch',
          onTap: () => context.push('/planning'),
        ),
        _buildActionItem(
          context,
          icon: LucideIcons.chartPie,
          label: 'Báo cáo',
          onTap: () => context.push('/analytics'),
        ),
        _buildActionItem(
          context,
          icon: LucideIcons.arrowLeftRight,
          label: 'Lịch sử',
          onTap: () => context.push('/transactions'),
        ),
      ],
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: highlight ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 22,
              color: highlight ? Colors.white : AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, TransactionEntity tx, bool isDark) {
    if (tx.isInternalTransfer) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: AppSpacing.roundedMedium,
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.arrowLeftRight, size: 18, color: Colors.blueGrey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description.isNotEmpty ? tx.description : 'Chuyển tiền nội bộ',
                    style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Nội bộ - Không tính chi tiêu',
                    style: TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Text(
              tx.formattedAmount,
              style: AppTypography.tabular(
                AppTypography.body(context).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    final isExpense = tx.type == TransactionType.expense;
    final color = isExpense ? AppColors.expense : AppColors.income;
    final prefix = isExpense ? '-' : '+';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMedium,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isExpense ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description.isNotEmpty ? tx.description : (tx.categoryName ?? 'Giao dịch'),
                  style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  tx.categoryName ?? 'Chung',
                  style: AppTypography.caption(context).copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '$prefix${tx.formattedAmount}',
            style: AppTypography.tabular(
              AppTypography.body(context).copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, int currentIndex) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (idx) {
        if (idx == 0) context.go('/home');
        if (idx == 1) context.push('/transactions');
        if (idx == 2) context.push('/planning');
        if (idx == 3) context.push('/analytics');
        if (idx == 4) context.push('/profile');
      },
      destinations: const [
        NavigationDestination(icon: Icon(LucideIcons.house, size: 20), label: 'Trang chủ'),
        NavigationDestination(icon: Icon(LucideIcons.receipt, size: 20), label: 'Sổ thu chi'),
        NavigationDestination(icon: Icon(LucideIcons.target, size: 20), label: 'Kế hoạch'),
        NavigationDestination(icon: Icon(LucideIcons.chartPie, size: 20), label: 'Phân tích'),
        NavigationDestination(icon: Icon(LucideIcons.user, size: 20), label: 'Cá nhân'),
      ],
    );
  }
}
