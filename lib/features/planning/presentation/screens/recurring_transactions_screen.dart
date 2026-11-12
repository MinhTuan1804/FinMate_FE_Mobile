import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

class RecurringItem {
  final String id;
  final String name;
  final BigInt amountCents;
  final String cycle; // Hàng tháng, Hàng tuần, Hàng năm
  final DateTime nextDueDate;
  final IconData icon;
  final Color color;
  bool isActive;

  RecurringItem({
    required this.id,
    required this.name,
    required this.amountCents,
    required this.cycle,
    required this.nextDueDate,
    required this.icon,
    required this.color,
    this.isActive = true,
  });
}

/// Màn G7 & G8: Giao dịch định kỳ & Hóa đơn tự động (Recurring Items Screen)
class RecurringTransactionsScreen extends ConsumerStatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  ConsumerState<RecurringTransactionsScreen> createState() => _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState extends ConsumerState<RecurringTransactionsScreen> {
  final List<RecurringItem> _items = [
    RecurringItem(
      id: 'r1',
      name: 'Tiền thuê căn hộ',
      amountCents: BigInt.from(6500000),
      cycle: 'Hàng tháng (ngày 5)',
      nextDueDate: DateTime(2026, 12, 5),
      icon: LucideIcons.house,
      color: AppColors.primary,
    ),
    RecurringItem(
      id: 'r2',
      name: 'Gói Netflix Premium 4K',
      amountCents: BigInt.from(260000),
      cycle: 'Hàng tháng (ngày 15)',
      nextDueDate: DateTime(2026, 11, 15),
      icon: LucideIcons.tv,
      color: AppColors.expense,
    ),
    RecurringItem(
      id: 'r3',
      name: 'Spotify Family',
      amountCents: BigInt.from(99000),
      cycle: 'Hàng tháng (ngày 20)',
      nextDueDate: DateTime(2026, 11, 20),
      icon: LucideIcons.music,
      color: AppColors.safe,
    ),
    RecurringItem(
      id: 'r4',
      name: 'Cước Internet cáp quang FPT',
      amountCents: BigInt.from(275000),
      cycle: 'Hàng tháng (ngày 1)',
      nextDueDate: DateTime(2026, 12, 1),
      icon: LucideIcons.wifi,
      color: AppColors.secondary,
    ),
  ];

  void _addNewItem() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm khoản định kỳ mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Tên dịch vụ / khoản chi'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số tiền (VNĐ)', suffixText: '₫'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              final raw = amountController.text.replaceAll('.', '').replaceAll(',', '').trim();
              final amount = int.tryParse(raw);
              if (nameController.text.isNotEmpty && amount != null && amount > 0) {
                setState(() {
                  _items.add(
                    RecurringItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text.trim(),
                      amountCents: BigInt.from(amount),
                      cycle: 'Hàng tháng',
                      nextDueDate: DateTime.now().add(const Duration(days: 30)),
                      icon: LucideIcons.receipt,
                      color: AppColors.secondary,
                    ),
                  );
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalMonthly = _items
        .where((i) => i.isActive)
        .fold(BigInt.zero, (sum, i) => sum + i.amountCents);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiêu định kỳ'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewItem,
        backgroundColor: AppColors.primaryAction(context),
        foregroundColor: AppColors.onPrimaryAction(context),
        icon: const Icon(LucideIcons.plus, size: 18),
        label: const Text('Thêm định kỳ'),
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Summary Card
              ZenvestHeroDeck(
                peekBadgeText: 'BILL',
                child: LiquidGlassCard(
                  variant: LiquidGlassVariant.iridescentHero,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TỔNG CHI PHÍ CỐ ĐỊNH / THÁNG',
                        style: AppTypography.caption(context).copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatVnd(totalMonthly),
                        style: AppTypography.displayBalance(context).copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Bao gồm ${_items.where((i) => i.isActive).length} dịch vụ đang hoạt động tự động trích tiền.',
                        style: AppTypography.caption(context),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text('DANH SÁCH DỊCH VỤ & HÓA ĐƠN', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),

              for (final item in _items) ...[
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
                            color: item.color.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(item.icon, size: 22, color: item.color),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: AppTypography.body(context).copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.cycle} • Hạn: ${DateFormat('dd/MM').format(item.nextDueDate)}',
                                style: AppTypography.caption(context).copyWith(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatVnd(item.amountCents),
                                style: AppTypography.tabular(
                                  AppTypography.caption(context).copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.expense,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: item.isActive,
                          onChanged: (val) => setState(() => item.isActive = val),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
