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
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';
import 'package:finmate/features/recurring/presentation/controllers/recurring_items_controller.dart';
import 'package:finmate/features/recurring/presentation/screens/recurring_items_screen.dart';

/// Quy đổi một khoản chi định kỳ về đồng/tháng (số nguyên, làm tròn xuống). Tuần = 52/12 tháng.
BigInt monthlyEquivalent(RecurringItemEntity item) => switch (item.cadence) {
      RecurringCadence.weekly => item.amountCents * BigInt.from(52) ~/ BigInt.from(12),
      RecurringCadence.monthly => item.amountCents,
      RecurringCadence.yearly => item.amountCents ~/ BigInt.from(12),
    };

/// Màn G7: Giao dịch định kỳ & hóa đơn tự động, dữ liệu thật từ `/api/v1/recurring-items`.
class RecurringTransactionsScreen extends ConsumerWidget {
  const RecurringTransactionsScreen({super.key});

  Future<void> _run(BuildContext context, Future<void> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  Future<void> _showForm(BuildContext context, WidgetRef ref, {RecurringItemEntity? editing}) async {
    final categories = ref.read(categoriesProvider).valueOrNull ?? const <Category>[];
    final accounts = ref.read(accountsControllerProvider).valueOrNull ?? const [];
    final result = await showDialog<RecurringFormInput>(
      context: context,
      builder: (_) => RecurringFormDialog(editing: editing, categories: categories, accounts: accounts),
    );
    if (result == null || !context.mounted) return;
    final controller = ref.read(recurringItemsControllerProvider.notifier);
    if (editing == null) {
      await _run(
        context,
        () => controller.create(
          direction: result.direction!,
          name: result.name,
          counterpartyName: result.counterpartyName,
          amountCents: result.amount,
          cadence: result.cadence,
          nextDueDate: result.nextDueDate!,
          categoryId: result.categoryId,
          financialAccountId: result.financialAccountId,
        ),
        'Đã tạo khoản định kỳ.',
      );
    } else {
      await _run(
        context,
        () => controller.update(
          id: editing.id,
          name: result.name,
          amountCents: result.amount,
          cadence: result.cadence,
          nextDueDate: result.nextDueDate,
          categoryId: result.categoryId,
          financialAccountId: result.financialAccountId,
        ),
        'Đã lưu khoản định kỳ.',
      );
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, RecurringItemEntity item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Hủy khoản định kỳ'),
        content: Text('Hủy "${item.name}"? Hệ thống sẽ không tự đề xuất lại cho cùng người nhận này.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Không')),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Hủy khoản', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(context, () => ref.read(recurringItemsControllerProvider.notifier).cancel(item.id), 'Đã hủy khoản định kỳ.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recurringItemsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiêu định kỳ'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Quay lại',
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref),
        backgroundColor: AppColors.primaryAction(context),
        foregroundColor: AppColors.onPrimaryAction(context),
        icon: const Icon(LucideIcons.plus, size: 18),
        label: const Text('Thêm định kỳ'),
      ),
      body: AmbientGlassBackground(
        child: RefreshIndicator(
          onRefresh: () => ref.read(recurringItemsControllerProvider.notifier).load(),
          child: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Message(
              text: errorMessage(e),
              actionLabel: 'Thử lại',
              onAction: () => ref.read(recurringItemsControllerProvider.notifier).load(),
            ),
            data: (all) {
              final items = all
                  .where((i) => i.status != RecurringStatus.rejected && i.status != RecurringStatus.cancelled)
                  .toList();
              if (items.isEmpty) {
                return const _Message(
                  text: 'Chưa có khoản định kỳ nào. Bấm "Thêm định kỳ" để tạo tiền nhà, thuê bao hay lương hằng tháng.',
                );
              }
              final active = items.where((i) => i.status == RecurringStatus.active && i.direction == RecurringDirection.outflow);
              final totalMonthly = active.fold(BigInt.zero, (sum, i) => sum + monthlyEquivalent(i));
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
                children: [
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
                            style: AppTypography.displayBalance(context).copyWith(fontSize: 28, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Gồm ${active.length} khoản chi đang hoạt động, quy đổi về theo tháng.',
                            style: AppTypography.caption(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('DANH SÁCH DỊCH VỤ & HÓA ĐƠN', style: AppTypography.sectionLabel(context)),
                  const SizedBox(height: 12),
                  for (final item in items) _card(context, ref, item),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, RecurringItemEntity item) {
    final controller = ref.read(recurringItemsControllerProvider.notifier);
    final inflow = item.direction == RecurringDirection.inflow;
    final color = inflow ? AppColors.income : AppColors.expense;
    final suggested = item.status == RecurringStatus.suggested;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Center(
                    child: Icon(inflow ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight, size: 22, color: color),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.cadence.label} • Hạn: ${DateFormat('dd/MM/yyyy').format(item.nextDueDate)}',
                        style: AppTypography.caption(context).copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.formattedAmount,
                        style: AppTypography.tabular(
                          AppTypography.caption(context).copyWith(fontWeight: FontWeight.w800, color: color, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!suggested)
                  Switch(
                    value: item.status == RecurringStatus.active,
                    onChanged: (on) => _run(
                      context,
                      () => on ? controller.resume(item.id) : controller.pause(item.id),
                      on ? 'Đã tiếp tục.' : 'Đã tạm dừng.',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (suggested) ...[
              Text(item.status.label, style: AppTypography.caption(context).copyWith(color: AppColors.warning)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _run(context, () => controller.reject(item.id), 'Đã từ chối.'),
                    child: const Text('Từ chối', style: TextStyle(color: AppColors.danger)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: () => _run(context, () => controller.confirm(item.id), 'Đã xác nhận.'),
                    child: const Text('Xác nhận'),
                  ),
                ],
              ),
            ] else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Sửa',
                    icon: const Icon(LucideIcons.pencil, size: 18),
                    onPressed: () => _showForm(context, ref, editing: item),
                  ),
                  IconButton(
                    tooltip: 'Hủy khoản định kỳ',
                    icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.danger),
                    onPressed: () => _cancel(context, ref, item),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    // Cuộn được để kéo-làm-mới hoạt động cả khi rỗng/lỗi.
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Text(text, textAlign: TextAlign.center, style: AppTypography.body(context)),
        if (actionLabel != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(child: OutlinedButton(onPressed: onAction, child: Text(actionLabel!))),
        ],
      ],
    );
  }
}
