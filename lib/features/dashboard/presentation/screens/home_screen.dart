import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/analytics/presentation/reports_providers.dart';
import 'package:finmate/features/assistant/presentation/widgets/assistant_prompt_bar.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/finance_methods/presentation/controllers/finance_methods_controller.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:finmate/features/transactions/presentation/widgets/create_transaction_bottom_sheet.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_bottom_nav.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_circular_progress.dart';
import 'package:finmate/shared/widgets/glass/glass_transaction_row.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final txState = ref.watch(transactionControllerProvider);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Xin chào,', style: GlassTypography.bodyMd()),
                        const SizedBox(height: 2),
                        Text(user?.displayName ?? 'Bạn của FinMate', style: GlassTypography.headlineLg()),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.bell, size: 22, color: GlassColors.textPrimary),
                          onPressed: () => context.push('/notifications'),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.circleUser, size: 24, color: GlassColors.textPrimary),
                          onPressed: () => context.push('/profile'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _AccountChipRow(),
                const SizedBox(height: 16),
                _buildBalanceCard(context, ref),
                const SizedBox(height: 16),
                const AssistantPromptBar(),
                const SizedBox(height: 16),
                _buildSafeToSpendCard(context, ref),
                const SizedBox(height: 16),
                _buildQuickActions(context),
                const SizedBox(height: 16),
                _buildMethodShortcut(context),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('GIAO DỊCH GẦN ĐÂY', style: GlassTypography.labelCaps()),
                    TextButton(
                      onPressed: () => context.push('/transactions'),
                      child: Text('Xem tất cả', style: GlassTypography.bodyMd(color: GlassColors.accentSkyBlue)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                txState.when(
                  loading: () => const Center(
                    child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => Text('Không thể tải giao dịch', style: GlassTypography.bodyMd()),
                  data: (transactions) {
                    final recents = transactions.take(4).toList();
                    if (recents.isEmpty) {
                      return GlassCard(
                        child: Center(
                          child: Text(
                            'Chưa có giao dịch nào.\nHãy bấm "Ghi chép" để thêm giao dịch đầu tiên!',
                            textAlign: TextAlign.center,
                            style: GlassTypography.bodyMd(),
                          ),
                        ),
                      );
                    }
                    return GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Column(
                        children: [for (final tx in recents) _buildTransactionRow(tx)],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: GlassBottomNav(currentIndex: 0, onDestinationSelected: (idx) => _onNavSelected(context, idx)),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsControllerProvider);
    final summary = ref.watch(monthlySummaryProvider);

    final balanceText = accounts.when(
      data: (list) => formatVnd(list.fold(BigInt.zero, (sum, a) => sum + a.balanceCents)),
      loading: () => '...',
      error: (_, __) => '—',
    );
    final hasNoAccount = accounts.valueOrNull?.isEmpty ?? false;
    final hasError = accounts.hasError || summary.hasError;
    final income = summary.valueOrNull == null ? '—' : '+${formatVnd(summary.value!.totalIncomeCents)}';
    final expense = summary.valueOrNull == null ? '—' : '-${formatVnd(summary.value!.totalSpentCents)}';

    return GlassCard(
      level: 2,
      borderRadius: GlassRadius.roundedCardLarge,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TỔNG TÀI SẢN KHẢ DỤNG', style: GlassTypography.labelCaps()),
          const SizedBox(height: 8),
          Text(balanceText, style: GlassTypography.displayHero()),
          if (hasNoAccount) ...[
            const SizedBox(height: 4),
            Text('Bạn chưa có tài khoản. Bấm "Ghi chép" để tạo ví đầu tiên.', style: GlassTypography.bodySm()),
          ],
          const SizedBox(height: 18),
          Divider(height: 1, color: GlassColors.glassBorder),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _flowItem('Thu nhập', income, LucideIcons.arrowDownLeft, GlassColors.success)),
              Expanded(child: _flowItem('Chi tiêu', expense, LucideIcons.arrowUpRight, GlassColors.danger)),
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
                child: Text('Thử lại', style: GlassTypography.bodyMd(color: GlassColors.accentSkyBlue)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _flowItem(String label, String value, IconData icon, Color color) {
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
              Text(label, style: GlassTypography.bodySm()),
              Text(value, overflow: TextOverflow.ellipsis, style: GlassTypography.labelNumeric(color: color)),
            ],
          ),
        ),
      ],
    );
  }

  /// "Chi an toàn hôm nay": đọc spendableProvider (đã có, không cần dữ liệu mới), tự tính số
  /// ngày còn lại trong tháng (entity không có field ngày) để ra định mức/ngày.
  Widget _buildSafeToSpendCard(BuildContext context, WidgetRef ref) {
    final async = ref.watch(spendableProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) {
        if (s.spendableCents == null) return const SizedBox.shrink();
        final now = DateTime.now();
        final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
        final daysRemaining = lastDayOfMonth - now.day + 1;
        final perDay = daysRemaining > 0 ? s.spendableCents! ~/ BigInt.from(daysRemaining) : BigInt.zero;
        final percentUsed = s.incomeCents == null || s.incomeCents == BigInt.zero
            ? 0.0
            : (s.spentCents.toDouble() / s.incomeCents!.toDouble() * 100);

        return GlassCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chi an toàn hôm nay', style: GlassTypography.labelCaps()),
                    const SizedBox(height: 6),
                    Text(formatVnd(perDay), style: GlassTypography.headlineLg()),
                    const SizedBox(height: 2),
                    Text('Đã chi: ${formatVnd(s.spentCents)}', style: GlassTypography.bodySm()),
                  ],
                ),
              ),
              GlassCircularProgress(
                percent: percentUsed,
                center: Text('${percentUsed.round()}%', style: GlassTypography.labelNumeric()),
              ),
            ],
          ),
        );
      },
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
        _buildActionItem(context, icon: LucideIcons.target, label: 'Kế hoạch', onTap: () => context.push('/planning')),
        _buildActionItem(context, icon: LucideIcons.chartPie, label: 'Báo cáo', onTap: () => context.push('/analytics')),
        _buildActionItem(context, icon: LucideIcons.arrowLeftRight, label: 'Lịch sử', onTap: () => context.push('/transactions')),
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
              color: highlight ? GlassColors.ink : GlassColors.secondarySurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 22, color: highlight ? Colors.white : GlassColors.slateAnchor),
          ),
          const SizedBox(height: 8),
          Text(label, style: GlassTypography.bodySm(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // Luồng 2 (B1 hub): lối tắt "Xem phương pháp" -> B5 Cách quản lý của tôi. Trước đây Trang chủ
  // không có đường nào tới B5 ngoài việc đi vòng qua Hồ sơ -> "Cách quản lý tài chính" (B4).
  Widget _buildMethodShortcut(BuildContext context) {
    return InkWell(
      borderRadius: GlassRadius.roundedCard,
      onTap: () => context.push('/finance-methods/my-methods'),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: GlassColors.secondarySurface, shape: BoxShape.circle),
              child: const Icon(LucideIcons.wallet, size: 20, color: GlassColors.slateAnchor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cách quản lý của bạn', style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                  Text('Xem phương pháp và các hũ đang dùng', style: GlassTypography.bodySm()),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 18, color: GlassColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionRow(TransactionEntity tx) {
    if (tx.isInternalTransfer) {
      return GlassTransactionRow(
        icon: LucideIcons.arrowLeftRight,
        iconColor: GlassColors.slateAnchor,
        title: tx.description.isNotEmpty ? tx.description : 'Chuyển tiền nội bộ',
        subtitle: 'Nội bộ - Không tính chi tiêu',
        amountText: tx.formattedAmount,
        isExpense: false,
      );
    }
    final isExpense = tx.type == TransactionType.expense;
    return GlassTransactionRow(
      icon: isExpense ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
      iconColor: isExpense ? GlassColors.danger : GlassColors.success,
      title: tx.description.isNotEmpty ? tx.description : (tx.categoryName ?? 'Giao dịch'),
      subtitle: tx.categoryName ?? 'Chung',
      amountText: '${isExpense ? '-' : '+'}${tx.formattedAmount}',
      isExpense: isExpense,
    );
  }

  // idx == -1: nút "Quét QR" nổi giữa thanh nav (không phải 1 trong 4 tab thường).
  void _onNavSelected(BuildContext context, int idx) {
    switch (idx) {
      case 0:
        context.go('/home');
      case 1:
        context.push('/transactions');
      case -1:
        context.push('/qr-transfers/scan');
      case 2:
        context.push('/planning');
      case 3:
        context.push('/analytics');
    }
  }
}

/// Dãy chip tài khoản — chỉ trang trí (hiển thị tên + số dư mỗi tài khoản), không đổi dữ liệu
/// Balance Card (vẫn luôn tổng tất cả tài khoản).
class _AccountChipRow extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AccountChipRow> createState() => _AccountChipRowState();
}

class _AccountChipRowState extends ConsumerState<_AccountChipRow> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsControllerProvider);
    final list = accounts.valueOrNull ?? const <FinancialAccount>[];
    if (list.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final account = list[i];
          final isSelected = i == _selected;
          return GestureDetector(
            onTap: () => setState(() => _selected = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? GlassColors.ink : GlassColors.glassFill,
                borderRadius: GlassRadius.roundedPill,
                border: Border.all(color: isSelected ? GlassColors.ink : GlassColors.glassBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    account.name,
                    style: GlassTypography.bodySm(color: isSelected ? Colors.white : GlassColors.textSecondary)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatVnd(account.balanceCents),
                    style: GlassTypography.labelNumeric(color: isSelected ? Colors.white : GlassColors.textPrimary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
