import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';
import 'package:finmate/features/recurring/presentation/controllers/recurring_items_controller.dart';

/// Màn quản lý khoản thu/chi định kỳ: tạo, sửa, xác nhận/từ chối đề xuất, tạm dừng/tiếp tục, hủy.
/// Đơn giản để test nhanh toàn bộ API recurring-items còn thiếu ở FE.
class RecurringItemsScreen extends ConsumerWidget {
  const RecurringItemsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final categories = ref.read(categoriesProvider).valueOrNull ?? const <Category>[];
    final accounts = ref.read(accountsControllerProvider).valueOrNull ?? const [];
    final result = await showDialog<_RecurringInput>(
      context: context,
      builder: (_) => _RecurringDialog(categories: categories, accounts: accounts),
    );
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(recurringItemsControllerProvider.notifier).create(
            direction: result.direction!,
            name: result.name,
            counterpartyName: result.counterpartyName,
            amountCents: result.amount,
            cadence: result.cadence,
            nextDueDate: result.nextDueDate!,
            categoryId: result.categoryId,
            financialAccountId: result.financialAccountId,
          );
      messenger.showSnackBar(const SnackBar(content: Text('Đã tạo khoản định kỳ')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, RecurringItemEntity item) async {
    final categories = ref.read(categoriesProvider).valueOrNull ?? const <Category>[];
    final accounts = ref.read(accountsControllerProvider).valueOrNull ?? const [];
    final result = await showDialog<_RecurringInput>(
      context: context,
      builder: (_) => _RecurringDialog(editing: item, categories: categories, accounts: accounts),
    );
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(recurringItemsControllerProvider.notifier).update(
            id: item.id,
            name: result.name,
            amountCents: result.amount,
            cadence: result.cadence,
            nextDueDate: result.nextDueDate,
            categoryId: result.categoryId,
            financialAccountId: result.financialAccountId,
          );
      messenger.showSnackBar(const SnackBar(content: Text('Đã lưu khoản định kỳ')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _runAction(BuildContext context, WidgetRef ref, Future<void> Function() action, String successMessage) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, RecurringItemEntity item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy khoản định kỳ'),
        content: Text('Hủy "${item.name}"? Hệ thống sẽ không tự đề xuất lại cho cùng người nhận này.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Hủy khoản', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runAction(context, ref, () => ref.read(recurringItemsControllerProvider.notifier).cancel(item.id), 'Đã hủy khoản định kỳ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(recurringItemsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khoản thu/chi định kỳ'),
        actions: [
          IconButton(
            key: const ValueKey('add-recurring'),
            tooltip: 'Thêm khoản định kỳ',
            icon: const Icon(LucideIcons.plus),
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text(errorMessage(e), style: AppTypography.body(context))),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text('Chưa có khoản định kỳ nào.', style: AppTypography.body(context)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _buildCard(context, ref, items[i], isDark),
          );
        },
      ),
    );
  }

  Color _statusColor(RecurringStatus status) => switch (status) {
        RecurringStatus.suggested => AppColors.warning,
        RecurringStatus.active => AppColors.safe,
        RecurringStatus.paused => AppColors.textMutedLight,
        RecurringStatus.rejected => AppColors.danger,
        RecurringStatus.cancelled => AppColors.danger,
      };

  Widget _buildCard(BuildContext context, WidgetRef ref, RecurringItemEntity item, bool isDark) {
    final color = _statusColor(item.status);
    return Container(
      key: ValueKey('recurring-${item.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMedium,
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.direction == RecurringDirection.inflow ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
                color: item.direction == RecurringDirection.inflow ? AppColors.income : AppColors.expense,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
                    Text('${item.cadence.label} · Đến hạn ${DateFormat('dd/MM/yyyy').format(item.nextDueDate)}', style: AppTypography.caption(context)),
                  ],
                ),
              ),
              Text(item.formattedAmount, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(item.status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: _actionsFor(context, ref, item),
          ),
        ],
      ),
    );
  }

  List<Widget> _actionsFor(BuildContext context, WidgetRef ref, RecurringItemEntity item) {
    switch (item.status) {
      case RecurringStatus.suggested:
        return [
          TextButton.icon(
            key: ValueKey('confirm-${item.id}'),
            onPressed: () => _runAction(context, ref, () => ref.read(recurringItemsControllerProvider.notifier).confirm(item.id), 'Đã xác nhận'),
            icon: const Icon(LucideIcons.check, size: 16),
            label: const Text('Xác nhận'),
          ),
          TextButton.icon(
            key: ValueKey('reject-${item.id}'),
            onPressed: () => _runAction(context, ref, () => ref.read(recurringItemsControllerProvider.notifier).reject(item.id), 'Đã từ chối'),
            icon: Icon(LucideIcons.x, size: 16, color: AppColors.danger),
            label: Text('Từ chối', style: TextStyle(color: AppColors.danger)),
          ),
        ];
      case RecurringStatus.active:
        return [
          TextButton(
            key: ValueKey('pause-${item.id}'),
            onPressed: () => _runAction(context, ref, () => ref.read(recurringItemsControllerProvider.notifier).pause(item.id), 'Đã tạm dừng'),
            child: const Text('Tạm dừng'),
          ),
          IconButton(
            key: ValueKey('edit-${item.id}'),
            tooltip: 'Sửa',
            icon: const Icon(LucideIcons.pencil, size: 18),
            onPressed: () => _edit(context, ref, item),
          ),
          IconButton(
            key: ValueKey('cancel-${item.id}'),
            tooltip: 'Hủy',
            icon: Icon(LucideIcons.trash2, size: 18, color: AppColors.danger),
            onPressed: () => _cancel(context, ref, item),
          ),
        ];
      case RecurringStatus.paused:
        return [
          TextButton.icon(
            key: ValueKey('resume-${item.id}'),
            onPressed: () => _runAction(context, ref, () => ref.read(recurringItemsControllerProvider.notifier).resume(item.id), 'Đã tiếp tục'),
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('Tiếp tục'),
          ),
          IconButton(
            key: ValueKey('edit-${item.id}'),
            tooltip: 'Sửa',
            icon: const Icon(LucideIcons.pencil, size: 18),
            onPressed: () => _edit(context, ref, item),
          ),
          IconButton(
            key: ValueKey('cancel-${item.id}'),
            tooltip: 'Hủy',
            icon: Icon(LucideIcons.trash2, size: 18, color: AppColors.danger),
            onPressed: () => _cancel(context, ref, item),
          ),
        ];
      case RecurringStatus.rejected:
      case RecurringStatus.cancelled:
        return const [];
    }
  }
}

class _RecurringInput {
  final RecurringDirection? direction;
  final String name;
  final String? counterpartyName;
  final BigInt amount;
  final RecurringCadence cadence;
  final DateTime? nextDueDate;
  final String? categoryId;
  final String? financialAccountId;

  const _RecurringInput({
    this.direction,
    required this.name,
    this.counterpartyName,
    required this.amount,
    required this.cadence,
    this.nextDueDate,
    this.categoryId,
    this.financialAccountId,
  });
}

/// Tạo/sửa khoản định kỳ; chiều tiền (direction) chỉ chọn được lúc tạo, không sửa được sau (theo API)
class _RecurringDialog extends StatefulWidget {
  final RecurringItemEntity? editing;
  final List<Category> categories;
  final List<FinancialAccount> accounts;

  const _RecurringDialog({this.editing, this.categories = const [], this.accounts = const []});

  @override
  State<_RecurringDialog> createState() => _RecurringDialogState();
}

class _RecurringDialogState extends State<_RecurringDialog> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _counterparty = TextEditingController(text: widget.editing?.counterpartyKey ?? '');
  late final _amount = TextEditingController(text: widget.editing?.amountCents.toString() ?? '');
  late RecurringDirection _direction = widget.editing?.direction ?? RecurringDirection.outflow;
  late RecurringCadence _cadence = widget.editing?.cadence ?? RecurringCadence.monthly;
  late DateTime? _nextDueDate = widget.editing?.nextDueDate;
  late String? _categoryId = widget.editing?.categoryId;
  late String? _financialAccountId = widget.editing?.financialAccountId;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _counterparty.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _nextDueDate = picked);
  }

  void _submit() {
    final name = _name.text.trim();
    final amount = parseAmountInput(_amount.text);
    if (name.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên');
    } else if (amount == null) {
      setState(() => _error = 'Vui lòng nhập số tiền hợp lệ');
    } else if (_nextDueDate == null) {
      setState(() => _error = 'Vui lòng chọn ngày đến hạn tiếp theo');
    } else {
      Navigator.pop(
        context,
        _RecurringInput(
          direction: widget.editing == null ? _direction : null,
          name: name,
          counterpartyName: _counterparty.text.trim(),
          amount: amount,
          cadence: _cadence,
          nextDueDate: _nextDueDate,
          categoryId: _categoryId,
          financialAccountId: _financialAccountId,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editing != null;
    return AlertDialog(
      title: Text(isEditing ? 'Sửa khoản định kỳ' : 'Thêm khoản định kỳ'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isEditing) ...[
              DropdownButtonFormField<RecurringDirection>(
                initialValue: _direction,
                decoration: const InputDecoration(labelText: 'Chiều tiền'),
                items: RecurringDirection.values.map((d) => DropdownMenuItem(value: d, child: Text(d.label))).toList(),
                onChanged: (v) => setState(() => _direction = v ?? _direction),
              ),
              const SizedBox(height: 12),
            ],
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Tên (ví dụ: Tiền nhà, Lương tháng)')),
            const SizedBox(height: 12),
            TextField(controller: _counterparty, decoration: const InputDecoration(labelText: 'Người nhận/trả (tùy chọn, ví dụ: Netflix)')),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số tiền (VNĐ)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RecurringCadence>(
              initialValue: _cadence,
              decoration: const InputDecoration(labelText: 'Chu kỳ'),
              items: RecurringCadence.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
              onChanged: (v) => setState(() => _cadence = v ?? _cadence),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(LucideIcons.calendar, size: 16),
              label: Text(_nextDueDate == null ? 'Chọn ngày đến hạn tiếp theo' : DateFormat('dd/MM/yyyy').format(_nextDueDate!)),
            ),
            if (widget.categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Danh mục (tùy chọn)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('(không chọn)')),
                  ...widget.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
            ],
            if (widget.accounts.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _financialAccountId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tài khoản/ví (tùy chọn)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('(không chọn)')),
                  ...widget.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                ],
                onChanged: (v) => setState(() => _financialAccountId = v),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(onPressed: _submit, child: Text(isEditing ? 'Lưu' : 'Tạo')),
      ],
    );
  }
}
