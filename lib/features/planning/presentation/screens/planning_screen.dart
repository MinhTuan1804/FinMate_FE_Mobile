import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/features/planning/domain/entities/budget_entity.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';

class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? AppColors.danger : null),
    );
  }

  /// Chạy một thao tác ghi; lỗi hiện SnackBar thân thiện
  Future<T?> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      if (mounted) _snack(errorMessage(e), error: true);
      return null;
    }
  }

  Future<void> _addOrEditBudget(PlanningState planning, {BudgetEntity? editing, bool total = false}) async {
    final categories = ref.read(categoriesProvider).valueOrNull ?? const <Category>[];
    final used = planning.categoryBudgets.map((b) => b.categoryId).toSet();
    final result = await showDialog<_BudgetInput>(
      context: context,
      builder: (_) => _BudgetDialog(
        editing: editing,
        total: total,
        categories: categories.where((c) => !used.contains(c.id)).toList(),
      ),
    );
    if (result == null || !mounted) return;

    final ok = await _run(() => ref
        .read(planningControllerProvider.notifier)
        .createOrUpdateBudget(categoryId: result.categoryId, limitAmountCents: result.limit)
        .then((_) => true));
    if (ok == true) _snack('Đã lưu ngân sách');
  }

  Future<void> _deleteBudget(BudgetEntity budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá ngân sách'),
        content: Text('Xoá ngân sách cho "${budget.category}"? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Xoá', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await _run(() => ref.read(planningControllerProvider.notifier).deleteBudget(budget.id).then((_) => true));
    if (ok == true) _snack('Đã xoá ngân sách');
  }

  Future<void> _transferBudgetLimit(PlanningState planning) async {
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

  Future<GoalFeasibilityEntity?> _previewFeasibility(BigInt target, DateTime deadline) =>
      ref.read(planningControllerProvider.notifier).previewFeasibility(targetCents: target, deadline: deadline);

  Future<void> _addGoal() async {
    final result = await showDialog<_GoalInput>(
      context: context,
      builder: (_) => _GoalDialog(onPreviewFeasibility: _previewFeasibility),
    );
    if (result == null || !mounted) return;

    final ok = await _run(() => ref
        .read(planningControllerProvider.notifier)
        .createSavingsGoal(title: result.name, targetAmountCents: result.target, targetDate: result.deadline)
        .then((_) => true));
    if (ok == true) _snack('Đã tạo mục tiêu tiết kiệm');
  }

  Future<void> _editGoal(SavingsGoalEntity goal) async {
    final result = await showDialog<_GoalInput>(
      context: context,
      builder: (_) => _GoalDialog(editing: goal, onPreviewFeasibility: _previewFeasibility),
    );
    if (result == null || !mounted) return;

    final ok = await _run(() => ref
        .read(planningControllerProvider.notifier)
        .updateGoal(id: goal.id, name: result.name, targetCents: result.target, deadline: result.deadline)
        .then((_) => true));
    if (ok == true) _snack('Đã lưu mục tiêu');
  }

  Future<void> _cancelGoal(SavingsGoalEntity goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy mục tiêu'),
        content: Text('Hủy mục tiêu "${goal.title}"? Số tiền đã nạp vẫn được giữ lại.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hủy mục tiêu', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await _run(() => ref.read(planningControllerProvider.notifier).cancelGoal(goal.id).then((_) => true));
    if (ok == true) _snack('Đã hủy mục tiêu');
  }

  Future<void> _showGoalDetail(SavingsGoalEntity goal) async {
    final progress = await _run(() => ref.read(planningControllerProvider.notifier).getGoalProgress(goal.id));
    if (progress == null || !mounted) return;

    await showDialog<void>(context: context, builder: (_) => _GoalProgressDialog(progress: progress));
  }

  Future<void> _contribute(SavingsGoalEntity goal) async {
    final amount = await showDialog<BigInt>(context: context, builder: (_) => _AmountDialog(goalTitle: goal.title));
    if (amount == null || !mounted) return;

    final result = await _run(() => ref.read(planningControllerProvider.notifier).contributeToGoal(goal.id, amount));
    if (result == null) return;

    _snack('Đã nạp ${formatVnd(amount)} vào mục tiêu!');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(planningControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kế hoạch tài chính'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(LucideIcons.wallet, size: 18), text: 'Hạn mức ngân sách'),
            Tab(icon: Icon(LucideIcons.piggyBank, size: 18), text: 'Mục tiêu tiết kiệm'),
          ],
        ),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.alertCircle, size: 36, color: AppColors.danger),
                const SizedBox(height: 8),
                Text(errorMessage(err), textAlign: TextAlign.center),
                TextButton(
                  onPressed: () => ref.read(planningControllerProvider.notifier).loadPlanningData(),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (planning) => TabBarView(
          controller: _tabController,
          children: [
            _buildBudgetTab(context, planning, isDark),
            _buildSavingsTab(context, planning, isDark),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(bool isDark, {double radius = 12, Color? borderColor, double borderWidth = 1}) {
    return BoxDecoration(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? (isDark ? AppColors.borderDark : AppColors.borderLight), width: borderWidth),
    );
  }

  Widget _buildBudgetTab(BuildContext context, PlanningState planning, bool isDark) {
    final overall = planning.overallBudget;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (overall == null) _buildNoBudgetInvite(context, planning, isDark) else _buildDailyLimitCard(context, planning, overall, isDark),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NGÂN SÁCH THEO DANH MỤC',
                style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
              Row(
                children: [
                  if (planning.categoryBudgets.length >= 2)
                    TextButton.icon(
                      onPressed: () => _transferBudgetLimit(planning),
                      icon: const Icon(LucideIcons.arrowLeftRight, size: 16),
                      label: const Text('Chuyển'),
                    ),
                  TextButton.icon(
                    onPressed: () => _addOrEditBudget(planning),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Thêm'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (planning.categoryBudgets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Chưa có ngân sách theo danh mục.',
                textAlign: TextAlign.center,
                style: AppTypography.caption(context),
              ),
            )
          else
            ...planning.categoryBudgets.map((b) => _buildBudgetCard(context, planning, b, isDark)),
        ],
      ),
    );
  }

  Widget _buildNoBudgetInvite(BuildContext context, PlanningState planning, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark, radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bạn chưa đặt ngân sách tháng này', style: AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Đặt hạn mức chi tiêu cả tháng để FinMate gợi ý mức chi an toàn mỗi ngày.',
            style: AppTypography.caption(context),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _addOrEditBudget(planning, total: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
            ),
            child: const Text('Tạo ngân sách tháng'),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyLimitCard(BuildContext context, PlanningState planning, BudgetEntity overall, bool isDark) {
    final overspent = overall.isOverspent;

    return GestureDetector(
      onTap: () => _addOrEditBudget(planning, editing: overall, total: true),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(
          isDark,
          radius: 16,
          borderColor: overspent ? AppColors.danger : null,
          borderWidth: overspent ? 1.5 : 1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'HẠN MỨC CHI TIÊU HÔM NAY',
                  style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Còn ${planning.daysRemainingInMonth} ngày',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (overspent) ...[
              Text(
                'ĐÃ CHI VƯỢT NGÂN SÁCH!',
                style: AppTypography.tabular(AppTypography.h2(context).copyWith(color: AppColors.danger, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 4),
              Text(
                'Bạn đã tiêu quá hạn mức tháng. Hãy dừng chi tiêu không thiết yếu!',
                style: AppTypography.caption(context).copyWith(color: AppColors.danger),
              ),
            ] else ...[
              Text(
                '${formatVnd(planning.dailySafeLimit)} / ngày',
                style: AppTypography.tabular(
                  AppTypography.moneyLarge.copyWith(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ngân sách tháng: ${overall.formattedLimit} · Đã chi ${overall.formattedSpent}',
                style: AppTypography.caption(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetCard(BuildContext context, PlanningState planning, BudgetEntity budget, bool isDark) {
    final progress = (budget.spendingPercentage / 100.0).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => _addOrEditBudget(planning, editing: budget),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(budget.category, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: budget.statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${budget.spendingPercentage.toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: budget.statusColor),
                  ),
                ),
                IconButton(
                  key: ValueKey('delete-budget-${budget.id}'),
                  icon: const Icon(LucideIcons.trash2, size: 18),
                  color: AppColors.danger,
                  onPressed: () => _deleteBudget(budget),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(budget.statusColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Đã chi: ${budget.formattedSpent}', style: AppTypography.tabular(AppTypography.caption(context).copyWith(fontWeight: FontWeight.w500))),
                Text('Hạn mức: ${budget.formattedLimit}', style: AppTypography.tabular(AppTypography.caption(context))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsTab(BuildContext context, PlanningState planning, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MỤC TIÊU TIẾT KIỆM HIỆN CÓ',
                style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
              ElevatedButton.icon(
                onPressed: _addGoal,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Mục tiêu mới'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (planning.savingsGoals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Bạn chưa có mục tiêu tiết kiệm nào.', textAlign: TextAlign.center, style: AppTypography.caption(context)),
            )
          else
            ...planning.savingsGoals.map((g) => _buildSavingsGoalCard(context, g, isDark)),
        ],
      ),
    );
  }

  Widget _buildSavingsGoalCard(BuildContext context, SavingsGoalEntity goal, bool isDark) {
    final progress = (goal.progressPercentage / 100.0).clamp(0.0, 1.0);
    final color = goal.statusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark, radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(goal.title, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(goal.statusLabel(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
              ),
            ],
          ),
          if (goal.targetDate != null) ...[
            const SizedBox(height: 4),
            Text('Hạn chót: ${DateFormat('dd/MM/yyyy').format(goal.targetDate!)}', style: AppTypography.caption(context)),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.safe),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Đã tích lũy', style: AppTypography.caption(context)),
                  const SizedBox(height: 2),
                  Text(
                    goal.formattedCurrent,
                    style: AppTypography.tabular(AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.w700, color: AppColors.safe)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Mục tiêu', style: AppTypography.caption(context)),
                  const SizedBox(height: 2),
                  Text(
                    goal.formattedTarget,
                    style: AppTypography.tabular(AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: goal.isCompleted ? null : () => _contribute(goal),
            icon: const Icon(LucideIcons.arrowUpRight, size: 16),
            label: const Text('Nạp tiền vào mục tiêu'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: ValueKey('goal-detail-${goal.id}'),
                onPressed: () => _showGoalDetail(goal),
                child: const Text('Xem tiến độ'),
              ),
              IconButton(
                key: ValueKey('edit-goal-${goal.id}'),
                tooltip: 'Sửa',
                icon: const Icon(LucideIcons.pencil, size: 18),
                onPressed: () => _editGoal(goal),
              ),
              if (goal.status == 'active')
                IconButton(
                  key: ValueKey('cancel-goal-${goal.id}'),
                  tooltip: 'Hủy mục tiêu',
                  icon: const Icon(LucideIcons.x, size: 18),
                  color: AppColors.danger,
                  onPressed: () => _cancelGoal(goal),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chi tiết tiến độ một mục tiêu: số ngày còn lại, cần nạp/ngày, lịch sử nạp gần đây, tính khả thi
class _GoalProgressDialog extends StatelessWidget {
  final GoalProgressEntity progress;
  const _GoalProgressDialog({required this.progress});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(progress.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đã tích lũy: ${progress.formattedSaved} / ${progress.formattedTarget} (${progress.percentComplete}%)'),
            const SizedBox(height: 4),
            Text('Còn thiếu: ${progress.formattedRemaining}'),
            if (progress.daysRemaining != null) ...[
              const SizedBox(height: 4),
              Text('Còn ${progress.daysRemaining} ngày'
                  '${progress.requiredPerDayCents != null ? ' — cần nạp ~${formatVnd(progress.requiredPerDayCents!)}/ngày' : ''}'),
            ],
            const SizedBox(height: 4),
            Text(
              progress.isOnTrack ? 'Đang bám đúng nhịp' : 'Đang chậm so với kế hoạch',
              style: TextStyle(color: progress.isOnTrack ? AppColors.safe : AppColors.warning, fontWeight: FontWeight.w600),
            ),
            if (progress.feasibility != null) ...[
              const Divider(height: 20),
              Text(
                'Cần ~${progress.feasibility!.formattedRequiredPerMonth}/tháng'
                '${progress.feasibility!.isFeasible == false ? ' — vượt khả năng tài chính hiện tại' : ''}',
                style: TextStyle(color: progress.feasibility!.isFeasible == false ? AppColors.danger : AppColors.safe, fontSize: 13),
              ),
            ],
            if (progress.recentContributions.isNotEmpty) ...[
              const Divider(height: 20),
              Text('Lịch sử nạp gần đây', style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ...progress.recentContributions.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('${DateFormat('dd/MM/yyyy').format(c.contributedAt)}: ${c.formattedAmount}${c.note != null ? ' (${c.note})' : ''}'),
                  )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
      ],
    );
  }
}

const _invalidAmount = 'Vui lòng nhập số tiền hợp lệ';

class _BudgetInput {
  final String? categoryId;
  final BigInt limit;
  const _BudgetInput(this.categoryId, this.limit);
}

/// Tạo/sửa ngân sách: total = ngân sách tổng (không chọn danh mục); editing = sửa hạn mức
class _BudgetDialog extends StatefulWidget {
  final BudgetEntity? editing;
  final bool total;
  final List<Category> categories;

  const _BudgetDialog({this.editing, this.total = false, this.categories = const []});

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late final TextEditingController _limit = TextEditingController(text: widget.editing?.limitAmountCents.toString() ?? '');
  String? _categoryId;
  String? _error;

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  void _submit() {
    final limit = parseAmountInput(_limit.text);
    final needsCategory = widget.editing == null && !widget.total;
    if (limit == null) {
      setState(() => _error = _invalidAmount);
    } else if (needsCategory && _categoryId == null) {
      setState(() => _error = 'Vui lòng chọn danh mục');
    } else {
      Navigator.pop(context, _BudgetInput(widget.editing?.categoryId ?? _categoryId, limit));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.total
        ? (widget.editing == null ? 'Tạo ngân sách tháng' : 'Sửa ngân sách tháng')
        : (widget.editing == null ? 'Thêm ngân sách danh mục' : 'Sửa ${widget.editing!.category}');

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.editing == null && !widget.total) ...[
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Danh mục'),
                items: widget.categories
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Row(children: [Icon(categoryIcon(c.slug), size: 18), const SizedBox(width: 8), Text(c.name)]),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _limit,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: InputDecoration(labelText: 'Hạn mức chi tiêu (VNĐ)', errorText: _error),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(onPressed: _submit, child: const Text('Lưu')),
      ],
    );
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

class _GoalInput {
  final String name;
  final BigInt target;
  final DateTime? deadline;
  const _GoalInput(this.name, this.target, this.deadline);
}

class _GoalDialog extends StatefulWidget {
  final SavingsGoalEntity? editing;
  final Future<GoalFeasibilityEntity?> Function(BigInt target, DateTime deadline)? onPreviewFeasibility;

  const _GoalDialog({this.editing, this.onPreviewFeasibility});

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final _name = TextEditingController(text: widget.editing?.title ?? '');
  late final _target = TextEditingController(text: widget.editing == null ? '' : formatAmountDigits(widget.editing!.targetAmountCents));
  late DateTime? _deadline = widget.editing?.targetDate;
  String? _error;
  GoalFeasibilityEntity? _feasibility;
  bool _feasibilityChecked = false;
  bool _checkingFeasibility = false;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _checkFeasibility() async {
    final target = parseAmountInput(_target.text);
    if (target == null || _deadline == null || widget.onPreviewFeasibility == null) {
      setState(() => _error = target == null ? _invalidAmount : 'Vui lòng chọn hạn chót để xem khả thi');
      return;
    }
    setState(() {
      _checkingFeasibility = true;
      _error = null;
    });
    final result = await widget.onPreviewFeasibility!(target, _deadline!);
    if (!mounted) return;
    setState(() {
      _feasibility = result;
      _feasibilityChecked = true;
      _checkingFeasibility = false;
    });
  }

  void _submit() {
    final name = _name.text.trim();
    final target = parseAmountInput(_target.text);
    if (name.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên mục tiêu');
    } else if (target == null) {
      setState(() => _error = _invalidAmount);
    } else {
      Navigator.pop(context, _GoalInput(name, target, _deadline));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.editing == null ? 'Tạo mục tiêu tiết kiệm' : 'Sửa mục tiêu'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Tên mục tiêu (ví dụ: Quỹ du lịch)')),
            const SizedBox(height: 12),
            TextField(
              controller: _target,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(labelText: 'Mục tiêu tích lũy (VNĐ)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(LucideIcons.calendar, size: 16),
              label: Text(_deadline == null ? 'Chọn hạn chót (tùy chọn)' : DateFormat('dd/MM/yyyy').format(_deadline!)),
            ),
            if (widget.onPreviewFeasibility != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _checkingFeasibility ? null : _checkFeasibility,
                icon: const Icon(LucideIcons.calculator, size: 16),
                label: const Text('Xem trước tính khả thi'),
              ),
              if (_feasibilityChecked)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _feasibility == null
                      ? const Text('Đã đủ tiền, không cần góp thêm.', style: TextStyle(color: AppColors.safe, fontSize: 13))
                      : Text(
                          'Cần ~${_feasibility!.formattedRequiredPerMonth}/tháng'
                          '${_feasibility!.isFeasible == false ? ' — vượt khả năng tài chính hiện tại' : ''}',
                          style: TextStyle(color: _feasibility!.isFeasible == false ? AppColors.danger : AppColors.safe, fontSize: 13),
                        ),
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
        ElevatedButton(onPressed: _submit, child: Text(widget.editing == null ? 'Tạo mục tiêu' : 'Lưu')),
      ],
    );
  }
}

class _AmountDialog extends StatefulWidget {
  final String goalTitle;
  const _AmountDialog({required this.goalTitle});

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _amount = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final value = parseAmountInput(_amount.text);
    if (value == null) {
      setState(() => _error = _invalidAmount);
    } else {
      Navigator.pop(context, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nạp tiền vào "${widget.goalTitle}"'),
      content: TextField(
        controller: _amount,
        keyboardType: TextInputType.number,
        inputFormatters: [ThousandsSeparatorInputFormatter()],
        autofocus: true,
        decoration: InputDecoration(labelText: 'Số tiền (VNĐ)', errorText: _error),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(onPressed: _submit, child: const Text('Nạp tiền')),
      ],
    );
  }
}
