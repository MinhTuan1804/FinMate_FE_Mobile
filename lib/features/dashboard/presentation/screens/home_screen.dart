import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/config/brand_logo.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/analytics/presentation/reports_providers.dart';
import 'package:finmate/features/assistant/presentation/widgets/assistant_prompt_bar.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/dashboard/presentation/widgets/app_bottom_nav.dart';
import 'package:finmate/features/finance_methods/presentation/widgets/method_home_section.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:finmate/features/transactions/presentation/widgets/create_transaction_bottom_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hideBalance = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    final txState = ref.watch(transactionControllerProvider);

    return Scaffold(
      body: AmbientGlassBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Zenvest Brand Top Bar (Logo + FinMate on left, Bell + Avatar on right)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BrandLogo(size: 26),
                        const SizedBox(width: 8),
                        Text(
                          'FinMate',
                          style: AppTypography.h3(context).copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LiquidGlassIconButton(
                          icon: LucideIcons.bell,
                          size: 40,
                          iconSize: 18,
                          tooltip: 'Thông báo',
                          onPressed: () => context.push('/notifications'),
                        ),
                        const SizedBox(width: 6),
                        LiquidGlassIconButton(
                          icon: LucideIcons.circleUser,
                          size: 40,
                          iconSize: 20,
                          tooltip: 'Cá nhân',
                          onPressed: () => context.push('/profile'),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 2. Zenvest Editorial Greeting Header ("Your Financial Overview" / "Welcome to Zenvest")
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xin chào,',
                        style: AppTypography.caption(context).copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.displayName ?? 'Bạn của FinMate',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.h1(context).copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 3. Zenvest Stacked / Peek Hero Balance Card Deck (Ảnh 3)
                ZenvestHeroDeck(
                  peekBadgeText: 'SAV',
                  child: _buildBalanceCard(context, ref),
                ),

                const SizedBox(height: 16),

                // 4. Zenvest Action Pill Row (Send ↗ / Received ↙ / ... + Solid Dark '+' Circle)
                _buildQuickActions(context),

                const SizedBox(height: 18),

                // 5. Elevated White-Glass Bottom Sheet ("Transactions" Sheet-on-Sky Architecture)
                ZenvestSurfaceSheet(
                  title: 'Giao dịch gần đây',
                  leading: IconButton(
                    icon: Icon(
                      LucideIcons.slidersHorizontal,
                      size: 18,
                      color: AppColors.textPrimary(context),
                    ),
                    tooltip: 'Bộ lọc giao dịch',
                    onPressed: () => context.push('/transactions'),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      LucideIcons.search,
                      size: 18,
                      color: AppColors.textPrimary(context),
                    ),
                    tooltip: 'Xem tất cả',
                    onPressed: () => context.push('/transactions'),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // AI Assistant Glass Prompt Bar
                      const AssistantPromptBar(),
                      const SizedBox(height: 14),

                      // Active Finance Method Summary
                      const FinanceHomeSection(),
                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Hoạt động mới nhất',
                            style: AppTypography.caption(context).copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/transactions'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: const Size(44, 34),
                            ),
                            child: const Text('Xem tất cả'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      txState.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (_, __) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Không thể tải giao dịch',
                            style: AppTypography.body(context).copyWith(
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                        data: (transactions) {
                          final recents = transactions.take(4).toList();
                          if (recents.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
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
                            children: [
                              for (var i = 0; i < recents.length; i++) ...[
                                if (i > 0)
                                  Divider(
                                    height: 1,
                                    color: AppColors.border(context)
                                        .withValues(alpha: 0.55),
                                  ),
                                _buildTransactionItem(context, recents[i]),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildBalanceCard(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsControllerProvider);
    final summary = ref.watch(monthlySummaryProvider);

    final rawBalanceText = accounts.when(
      data: (list) => formatVnd(
        list.fold(BigInt.zero, (sum, a) => sum + a.balanceCents),
      ),
      loading: () => '...',
      error: (_, __) => '—',
    );
    final balanceText = _hideBalance ? '•••••••• ₫' : rawBalanceText;
    final hasNoAccount = accounts.valueOrNull?.isEmpty ?? false;
    final hasError = accounts.hasError || summary.hasError;
    final income = summary.valueOrNull == null
        ? '—'
        : '+${formatVnd(summary.value!.totalIncomeCents)}';
    final expense = summary.valueOrNull == null
        ? '—'
        : '-${formatVnd(summary.value!.totalSpentCents)}';

    return LiquidGlassCard(
      variant: LiquidGlassVariant.iridescentHero,
      enableBlur: true,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Currency Badge Row (Zenvest Circular Flag/Currency Badge + VNĐ)
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.expense.withValues(alpha: 0.88),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.sparkles,
                    size: 13,
                    color: Color(0xFFFDE047),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'VNĐ',
                style: AppTypography.bodyMedium(context).copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Balance Label + Large Amount with Inline Eye Toggle ("$ 40,500.80 👁")
          Text(
            'TỔNG TÀI SẢN KHẢ DỤNG',
            style: AppTypography.caption(context).copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  balanceText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.displayBalance(context).copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: AppSpacing.roundedPill,
                onTap: () => setState(() => _hideBalance = !_hideBalance),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    _hideBalance ? LucideIcons.eyeOff : LucideIcons.eye,
                    size: 18,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
          if (hasNoAccount) ...[
            const SizedBox(height: 6),
            Text(
              'Bạn chưa có tài khoản. Bấm "Ghi chép" để tạo ví đầu tiên.',
              style: AppTypography.caption(context),
            ),
          ],
          const SizedBox(height: 18),

          // Bottom 2-Column Metadata Row (matching "Account Number" / "Valid Date" in Zenvest)
          Row(
            children: [
              Expanded(
                child: _flowColumn(
                  context,
                  label: 'Thu nhập',
                  value: income,
                  valueColor: AppColors.income,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _flowColumn(
                  context,
                  label: 'Chi tiêu',
                  value: expense,
                  valueColor: AppColors.expense,
                ),
              ),
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

  Widget _flowColumn(
    BuildContext context, {
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption(context).copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.tabular(
            AppTypography.bodyMedium(context).copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ZenvestActionPill(
                  label: 'Ghi chép',
                  trailingIcon: LucideIcons.arrowUpRight,
                  onTap: () => CreateTransactionBottomSheet.show(context),
                ),
                const SizedBox(width: 8),
                ZenvestActionPill(
                  label: 'Chuyển tiền',
                  trailingIcon: LucideIcons.arrowLeftRight,
                  onTap: () => context.push('/transactions/transfer'),
                ),
                const SizedBox(width: 8),
                ZenvestActionPill(
                  label: 'Quét hóa đơn',
                  trailingIcon: LucideIcons.scanLine,
                  onTap: () => context.push('/transactions/scan-receipt'),
                ),
                const SizedBox(width: 8),
                ZenvestActionPill(
                  label: 'Kế hoạch',
                  trailingIcon: LucideIcons.target,
                  onTap: () => context.push('/planning'),
                ),
                const SizedBox(width: 8),
                ZenvestActionPill(
                  label: 'Báo cáo',
                  trailingIcon: LucideIcons.chartPie,
                  onTap: () => context.push('/analytics'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        LiquidGlassIconButton(
          icon: LucideIcons.plus,
          style: LiquidGlassButtonStyle.primary,
          size: 40,
          iconSize: 18,
          tooltip: 'Thêm giao dịch mới',
          onPressed: () => CreateTransactionBottomSheet.show(context),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(BuildContext context, TransactionEntity tx) {
    final d = tx.date.toLocal();
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    if (tx.isInternalTransfer) {
      return ZenvestTransactionTile(
        icon: LucideIcons.arrowLeftRight,
        iconColor: AppColors.transfer,
        title: tx.description.isNotEmpty
            ? tx.description
            : 'Chuyển tiền nội bộ',
        categoryLabel: 'Nội bộ - Không tính chi tiêu',
        timeLabel: dateStr,
        amountText: tx.formattedAmount,
        amountColor: AppColors.textPrimary(context),
        typeLabel: 'Chuyển khoản',
        typeColor: AppColors.transfer,
        onTap: () => context.push('/transactions'),
      );
    }

    final isExpense = tx.type == TransactionType.expense;
    final color = isExpense ? AppColors.expense : AppColors.income;
    final prefix = isExpense ? '-' : '+';

    return ZenvestTransactionTile(
      icon: isExpense ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft,
      iconColor: color,
      title: tx.description.isNotEmpty
          ? tx.description
          : (tx.categoryName ?? 'Giao dịch'),
      categoryLabel: tx.categoryName ?? 'Chung',
      timeLabel: dateStr,
      amountText: '$prefix${tx.formattedAmount}',
      amountColor: AppColors.textPrimary(context),
      typeLabel: isExpense ? 'Chi tiêu' : 'Thu nhập',
      typeColor: color,
      onTap: () => context.push('/transactions'),
    );
  }
}
