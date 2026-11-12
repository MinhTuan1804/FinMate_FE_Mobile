import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

enum LoanType { borrow, lend } // Đi vay hoặc Cho vay

class LoanItem {
  final String id;
  final String title;
  final String counterparty; // Người vay hoặc Ngân hàng
  final BigInt principalCents;
  final BigInt paidCents;
  final double interestRateYear; // %/năm
  final DateTime dueDate;
  final LoanType type;

  LoanItem({
    required this.id,
    required this.title,
    required this.counterparty,
    required this.principalCents,
    required this.paidCents,
    required this.interestRateYear,
    required this.dueDate,
    required this.type,
  });
}

/// Màn G9 - G11: Quản lý Khoản vay & Nợ (Loans & Debts Screen)
/// [Ghi chú: Khung UI hoàn chỉnh theo Serene Liquid Glass, kết nối backend khi có contract]
class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  int _selectedTab = 0; // 0: Đi vay (Nợ cần trả), 1: Cho vay (Cần thu hồi)

  final List<LoanItem> _loans = [
    LoanItem(
      id: 'l1',
      title: 'Vay mua xe máy trả góp',
      counterparty: 'FE Credit',
      principalCents: BigInt.from(30000000),
      paidCents: BigInt.from(18000000),
      interestRateYear: 9.5,
      dueDate: DateTime(2027, 4, 15),
      type: LoanType.borrow,
    ),
    LoanItem(
      id: 'l2',
      title: 'Cho bạn mượn sửa nhà',
      counterparty: 'Nguyễn Văn Nam',
      principalCents: BigInt.from(15000000),
      paidCents: BigInt.from(5000000),
      interestRateYear: 0,
      dueDate: DateTime(2026, 12, 31),
      type: LoanType.lend,
    ),
  ];

  void _recordRepayment(LoanItem loan) {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ghi nhận trả nợ - ${loan.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Số nợ còn lại: ${formatVnd(loan.principalCents - loan.paidCents)}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Số tiền thanh toán',
                suffixText: '₫',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              final raw = amountController.text.replaceAll('.', '').replaceAll(',', '').trim();
              final amount = int.tryParse(raw);
              if (amount != null && amount > 0) {
                setState(() {
                  final idx = _loans.indexWhere((l) => l.id == loan.id);
                  if (idx != -1) {
                    _loans[idx] = LoanItem(
                      id: loan.id,
                      title: loan.title,
                      counterparty: loan.counterparty,
                      principalCents: loan.principalCents,
                      paidCents: loan.paidCents + BigInt.from(amount),
                      interestRateYear: loan.interestRateYear,
                      dueDate: loan.dueDate,
                      type: loan.type,
                    );
                  }
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã ghi nhận thanh toán thành công!')),
                );
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentType = _selectedTab == 0 ? LoanType.borrow : LoanType.lend;
    final filtered = _loans.where((l) => l.type == currentType).toList();

    final totalDebt = filtered.fold(
      BigInt.zero,
      (sum, l) => sum + (l.principalCents - l.paidCents),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khoản vay & Nợ'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Segmented Tab Pill
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLightSubtle.withValues(alpha: 0.7),
                  borderRadius: AppSpacing.roundedPill,
                  border: Border.all(color: AppColors.borderLight, width: 1),
                ),
                child: Row(
                  children: [
                    _tabButton('Tôi đang nợ', 0),
                    _tabButton('Người khác nợ tôi', 1),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Hero Balance Card
              ZenvestHeroDeck(
                peekBadgeText: _selectedTab == 0 ? 'DEBT' : 'LOAN',
                child: LiquidGlassCard(
                  variant: LiquidGlassVariant.iridescentHero,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedTab == 0 ? 'TỔNG DƯ NỢ CẦN TRẢ' : 'TỔNG TIỀN CẦN THU HỒI',
                        style: AppTypography.caption(context).copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatVnd(totalDebt),
                        style: AppTypography.displayBalance(context).copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _selectedTab == 0 ? AppColors.danger : AppColors.safe,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Theo dõi tiến độ trả nợ gốc và lãi suất minh bạch theo từng kỳ.',
                        style: AppTypography.caption(context),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text('DANH SÁCH KHOẢN VAY', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),

              if (filtered.isEmpty) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(LucideIcons.handCoins, size: 48, color: AppColors.textMuted(context)),
                        const SizedBox(height: 12),
                        Text(
                          _selectedTab == 0 ? 'Bạn không có khoản nợ nào!' : 'Không có khoản cho vay nào.',
                          style: AppTypography.caption(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ...filtered.map((loan) {
                  final remaining = loan.principalCents - loan.paidCents;
                  final progress = (loan.paidCents.toDouble() / loan.principalCents.toDouble()).clamp(0.0, 1.0);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: LiquidGlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(LucideIcons.landmark, size: 18, color: AppColors.slateAction),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loan.title,
                                      style: AppTypography.body(context).copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      'Đối tác: ${loan.counterparty} • Lãi: ${loan.interestRateYear}%/năm',
                                      style: AppTypography.caption(context).copyWith(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          LiquidGlassProgressBar(
                            value: progress,
                            color: AppColors.secondary,
                            height: 6,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Đã trả: ${formatVnd(loan.paidCents)}',
                                style: AppTypography.caption(context).copyWith(fontSize: 12),
                              ),
                              Text(
                                'Còn lại: ${formatVnd(remaining)}',
                                style: AppTypography.body(context).copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Hạn cuối: ${DateFormat('dd/MM/yyyy').format(loan.dueDate)}',
                                style: AppTypography.caption(context).copyWith(fontSize: 11.5),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(LucideIcons.check, size: 14),
                                label: const Text('Ghi nhận trả'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: () => _recordRepayment(loan),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _selectedTab == index;
    final activeBg = AppColors.primaryAction(context);
    final activeFg = AppColors.onPrimaryAction(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? activeBg : Colors.transparent,
            borderRadius: AppSpacing.roundedPill,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? activeFg : AppColors.textPrimary(context),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
