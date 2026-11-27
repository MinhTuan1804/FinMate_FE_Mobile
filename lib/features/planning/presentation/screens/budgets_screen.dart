import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/features/planning/domain/entities/budget_entity.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_app_bar.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_bottom_dock.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_progress_bar.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

const _invalidAmount = 'Vui lòng nhập số tiền hợp lệ';

/// G5 — Danh sách ngân sách (theo Figma): thẻ tổng tháng + ngân sách từng danh mục, chuyển hạn mức, xoá.
/// Khối "FinMate Cố Vấn Thông Minh" và dòng gợi ý AI của Figma chưa có dữ liệu ở BE nên không hiển thị.
class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? GlassColors.danger : null),
    );
  }

  Future<T?> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      if (mounted) _snack(errorMessage(e), error: true);
      return null;
    }
  }

  Future<void> _delete(BudgetEntity budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá ngân sách'),
        content: Text('Xoá ngân sách cho "${budget.category}"? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Xoá', style: TextStyle(color: GlassColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await _run(() => ref.read(planningControllerProvider.notifier).deleteBudget(budget.id).then((_) => true));
    if (ok == true) _snack('Đã xoá ngân sách');
  }

  Future<void> _transfer(PlanningState planning) async {
    final result = await showDialog<_TransferInput>(
      context: context,
      builder: (_) => _TransferDialog(budgets: planning.categoryBudgets),
    );
    if (result == null || !mounted) return;

    final ok = await _run(() => ref
        .read(planningControllerProvider.notifier)
        .transferBudgetLimit(fromBudgetId: result.fromBudgetId, toBudgetId: result.toBudgetId, amountCents: result.amount)
        .then((_) => true));
    if (ok == true) _snack('Đã chuyển hạn mức');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(planningControllerProvider);
    final slugById = <String, String?>{for (final c in ref.watch(categoriesProvider).valueOrNull ?? const <Category>[]) c.id: c.slug};

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: glassAppBar(context, title: 'Ngân sách chi tiêu'),
        body: SafeArea(
          child: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.circleAlert, size: 36, color: GlassColors.danger),
                    const SizedBox(height: 8),
                    Text(errorMessage(err), textAlign: TextAlign.center, style: GlassTypography.bodyMd()),
                    const SizedBox(height: 12),
                    GlassSecondaryButton(
                      label: 'Thử lại',
                      onPressed: () => ref.read(planningControllerProvider.notifier).loadPlanningData(),
                    ),
                  ],
                ),
              ),
            ),
            data: (planning) => Column(
              children: [
                Expanded(child: _body(context, planning, slugById)),
                GlassBottomDock(
                  actions: [
                    GlassPrimaryButton(
                      key: const ValueKey('budget-create'),
                      label: 'Tạo ngân sách mới',
                      icon: LucideIcons.plus,
                      onPressed: () => context.push('/planning/budgets/form'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, PlanningState planning, Map<String, String?> slugById) {
    final overall = planning.overallBudget;
    final budgets = planning.categoryBudgets;
    final now = DateTime.now();
    final month = overall?.month ?? now.month;
    final year = overall?.year ?? now.year;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            Icon(LucideIcons.calendarDays, size: 18, color: GlassColors.slateAnchor),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Tháng $month, $year', style: GlassTypography.headlineSm(), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            GlassBadge(text: 'Còn ${planning.daysRemainingInMonth} ngày', color: GlassColors.warning),
          ],
        ),
        const SizedBox(height: 16),
        if (overall == null) _invite(context) else _hero(context, planning, overall, now),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Semantics(header: true, child: Text('Theo dõi theo danh mục', style: GlassTypography.headlineSm())),
            ),
            if (budgets.length >= 2)
              AsyncActionBuilder(
                onPressed: () => _transfer(planning),
                builder: (_, onTap, running) => TextButton.icon(
                  key: const ValueKey('budget-transfer'),
                  onPressed: onTap,
                  icon: running ? const ButtonLoadingIndicator(size: 16) : const Icon(LucideIcons.arrowLeftRight, size: 16),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Chuyển', maxLines: 1)),
                  style: TextButton.styleFrom(foregroundColor: GlassColors.slateAnchor, minimumSize: const Size(48, 48)),
                ),
              ),
          ],
        ),
        Text('${budgets.length} danh mục', style: GlassTypography.bodySm()),
        const SizedBox(height: 12),
        if (budgets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Chưa có ngân sách theo danh mục.', textAlign: TextAlign.center, style: GlassTypography.bodyMd()),
          )
        else
          for (final b in budgets) ...[
            _categoryCard(context, b, slugById[b.categoryId]),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _invite(BuildContext context) {
    return GlassCard(
      level: 2,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bạn chưa đặt ngân sách tháng này', style: GlassTypography.headlineSm()),
          const SizedBox(height: 6),
          Text(
            'Đặt hạn mức chi tiêu cả tháng để FinMate gợi ý mức chi an toàn mỗi ngày.',
            style: GlassTypography.bodyMd(),
          ),
          const SizedBox(height: 16),
          GlassPrimaryButton(
            key: const ValueKey('budget-create-total'),
            label: 'Tạo ngân sách tháng',
            onPressed: () => context.push('/planning/budgets/form'),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context, PlanningState planning, BudgetEntity overall, DateTime now) {
    final s = _status(overall);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    return Semantics(
      button: true,
      label: 'Sửa ngân sách tổng',
      child: InkWell(
        key: const ValueKey('budget-total-card'),
        borderRadius: BorderRadius.circular(28),
        onTap: () => context.push('/planning/budgets/form', extra: overall),
        child: GlassCard(
          level: 2,
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TỔNG NGÂN SÁCH HẠN MỨC', style: GlassTypography.labelCaps(color: GlassColors.textSecondary)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(overall.formattedLimit, style: GlassTypography.displayHero()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassBadge(text: '${overall.spendingPercentage.toStringAsFixed(0)}% đã dùng', color: s.color),
                ],
              ),
              Divider(height: 28, color: GlassColors.glassBorder),
              Row(
                children: [
                  Expanded(child: _metric('Đã chi tiêu', overall.formattedSpent, GlassColors.textPrimary, CrossAxisAlignment.start)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: overall.isOverspent
                        ? _metric('Đã vượt', formatVnd(overall.spentAmountCents - overall.limitAmountCents), GlassColors.danger, CrossAxisAlignment.end)
                        : _metric('Hạn mức còn lại', overall.formattedRemaining, GlassColors.slateAnchor, CrossAxisAlignment.end),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GlassProgressBar(percent: overall.spendingPercentage, state: s.state, height: 12),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (overall.isOverspent || overall.statusLevel != BudgetStatusLevel.safe) ...[
                    Icon(LucideIcons.triangleAlert, size: 14, color: s.color),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      overall.isOverspent
                          ? 'Bạn đã chi vượt ngân sách tháng'
                          : overall.statusLevel == BudgetStatusLevel.safe
                              ? 'Chi tiêu đang trong tầm kiểm soát'
                              : 'Sắp chạm hạn mức tháng',
                      style: GlassTypography.bodySm(color: s.color).copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text('Hôm nay: ngày ${now.day}/$daysInMonth', style: GlassTypography.bodySm())),
                ],
              ),
              if (!overall.isOverspent) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: GlassColors.fieldFill, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Expanded(child: Text('Chi an toàn hôm nay', style: GlassTypography.bodySm())),
                      Text('${formatVnd(effectiveDailySafeLimit(ref, planning))} / ngày', style: GlassTypography.labelNumeric().copyWith(fontSize: 13)),
                    ],
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey('budget-total-delete'),
                  onPressed: () => _delete(overall),
                  icon: Icon(LucideIcons.trash2, size: 16, color: GlassColors.danger),
                  label: Text('Xoá ngân sách tổng', style: TextStyle(color: GlassColors.danger)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value, Color color, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: GlassTypography.bodySm(color: GlassColors.textSecondary)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: GlassTypography.labelNumeric(color: color)),
        ),
      ],
    );
  }

  Widget _categoryCard(BuildContext context, BudgetEntity b, String? slug) {
    final s = _status(b);
    return Semantics(
      button: true,
      label: 'Sửa ngân sách ${b.category}',
      child: InkWell(
        key: ValueKey('budget-card-${b.id}'),
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push('/planning/budgets/form', extra: b),
        child: GlassCard(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: s.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
                      child: Icon(categoryIcon(slug), size: 18, color: s.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.category,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          Text('Hạn mức: ${b.formattedLimit}', style: GlassTypography.bodySm()),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 2,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            GlassBadge(text: '${b.spendingPercentage.toStringAsFixed(0)}% ${s.label}', color: s.color),
                            const SizedBox(height: 4),
                            Text(b.formattedSpent, style: GlassTypography.labelNumeric(color: b.isOverspent ? s.color : null)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GlassProgressBar(percent: b.spendingPercentage, state: s.state, height: 8),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: b.isOverspent ? 'Vượt: ' : 'Còn lại: ',
                        style: GlassTypography.bodySm(color: GlassColors.textSecondary),
                        children: [
                          TextSpan(
                            text: b.isOverspent ? formatVnd(b.spentAmountCents - b.limitAmountCents) : b.formattedRemaining,
                            style: GlassTypography.bodySm(color: b.isOverspent ? s.color : GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('delete-budget-${b.id}'),
                    tooltip: 'Xoá ngân sách ${b.category}',
                    icon: Icon(LucideIcons.trash2, size: 18, color: GlassColors.danger),
                    onPressed: () => _delete(b),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static ({Color color, String label, GlassProgressState state}) _status(BudgetEntity b) {
    if (b.isOverspent) return (color: GlassColors.danger, label: 'Vượt hạn mức', state: GlassProgressState.danger);
    return switch (b.statusLevel) {
      BudgetStatusLevel.safe => (color: GlassColors.success, label: 'An toàn', state: GlassProgressState.success),
      BudgetStatusLevel.warning => (color: GlassColors.warning, label: 'Cận hạn', state: GlassProgressState.warning),
      BudgetStatusLevel.danger => (color: GlassColors.danger, label: 'Sát mức', state: GlassProgressState.danger),
    };
  }
}

class _TransferInput {
  final String fromBudgetId;
  final String toBudgetId;
  final BigInt amount;
  const _TransferInput(this.fromBudgetId, this.toBudgetId, this.amount);
}

/// Chuyển một phần hạn mức từ ngân sách danh mục này sang danh mục khác (cùng tháng)
class _TransferDialog extends StatefulWidget {
  final List<BudgetEntity> budgets;
  const _TransferDialog({required this.budgets});

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  final _amount = TextEditingController();
  String? _fromId;
  String? _toId;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = parseAmountInput(_amount.text);
    if (_fromId == null || _toId == null) {
      setState(() => _error = 'Vui lòng chọn đủ 2 danh mục');
    } else if (_fromId == _toId) {
      setState(() => _error = 'Danh mục nguồn và đích phải khác nhau');
    } else if (amount == null) {
      setState(() => _error = _invalidAmount);
    } else {
      Navigator.pop(context, _TransferInput(_fromId!, _toId!, amount));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chuyển hạn mức'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('transfer-from'),
              initialValue: _fromId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Từ danh mục'),
              items: widget.budgets.map((b) => DropdownMenuItem(value: b.id, child: Text(b.category))).toList(),
              onChanged: (v) => setState(() => _fromId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('transfer-to'),
              initialValue: _toId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Đến danh mục'),
              items: widget.budgets.map((b) => DropdownMenuItem(value: b.id, child: Text(b.category))).toList(),
              onChanged: (v) => setState(() => _toId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('transfer-amount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: InputDecoration(labelText: 'Số tiền chuyển (VNĐ)', errorText: _error),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(onPressed: _submit, child: const Text('Chuyển')),
      ],
    );
  }
}
