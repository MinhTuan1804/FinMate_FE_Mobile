import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import 'package:finmate/features/planning/presentation/screens/savings_goal_detail_screen.dart';
import 'package:finmate/shared/widgets/glass/glass_app_bar.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_bottom_dock.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_circular_progress.dart';
import 'package:finmate/shared/widgets/glass/glass_filter_chip.dart';
import 'package:finmate/shared/widgets/glass/glass_loading_spinner.dart';
import 'package:finmate/shared/widgets/glass/glass_progress_bar.dart';

enum _GoalFilter { all, active, draft, completed, cancelled }

extension on _GoalFilter {
  String get label => switch (this) {
    _GoalFilter.all => 'Tất cả',
    _GoalFilter.active => 'Đang chạy',
    _GoalFilter.draft => 'Bản nháp',
    _GoalFilter.completed => 'Hoàn thành',
    _GoalFilter.cancelled => 'Đã hủy',
  };

  bool matches(SavingsGoalEntity g) => switch (this) {
    _GoalFilter.all => true,
    _GoalFilter.cancelled => g.isCancelled,
    _GoalFilter.draft => g.isDraft,
    _GoalFilter.completed => !g.isCancelled && !g.isDraft && g.isCompleted,
    _GoalFilter.active => !g.isCancelled && !g.isDraft && !g.isCompleted,
  };
}

/// G2 — Danh sách mục tiêu tiết kiệm: thẻ tổng, chip lọc theo trạng thái, thẻ từng mục tiêu.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  _GoalFilter _filter = _GoalFilter.all;

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? GlassColors.danger : null),
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
            child: Text('Hủy mục tiêu', style: TextStyle(color: GlassColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await _run(() => ref.read(planningControllerProvider.notifier).cancelGoal(goal.id).then((_) => true));
    if (ok == true) _snack('Đã hủy mục tiêu');
  }

  /// Kích hoạt bản nháp. BE từ chối khi hạn chót đã qua (SAVING_GOAL_DEADLINE_PASSED): thông điệp của BE nói rõ phải sửa hạn trước.
  Future<void> _activate(SavingsGoalEntity goal) async {
    final ok = await _run(() => ref.read(planningControllerProvider.notifier).activateGoal(goal.id).then((_) => true));
    if (ok == true) _snack('Đã kích hoạt mục tiêu "${goal.title}".');
  }

  Future<void> _contribute(SavingsGoalEntity goal) async {
    final remaining = goal.targetAmountCents > goal.currentAmountCents ? goal.targetAmountCents - goal.currentAmountCents : BigInt.zero;
    final amount = await showGoalContributeDialog(context, goal.title, remainingCents: remaining);
    if (amount == null || !mounted) return;

    final result = await _run(() => ref.read(planningControllerProvider.notifier).contributeToGoal(goal.id, amount));
    if (result == null) return;

    _snack('Đã nạp ${formatVnd(amount)} vào mục tiêu!');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(planningControllerProvider);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: glassAppBar(context, title: 'Mục tiêu tích lũy'),
        bottomNavigationBar: GlassBottomDock(
          actions: [
            GlassPrimaryButton(
              key: const ValueKey('create-goal'),
              label: 'Tạo mục tiêu mới',
              icon: LucideIcons.plus,
              onPressed: () => context.push('/planning/goals/form'),
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: state.when(
            loading: () => const GlassLoadingSpinner(),
            error: (err, _) => _ErrorView(
              message: errorMessage(err),
              onRetry: () => ref.read(planningControllerProvider.notifier).loadPlanningData(),
            ),
            data: (planning) => _buildContent(context, planning.savingsGoals),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<SavingsGoalEntity> goals) {
    if (goals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Bạn chưa có mục tiêu tiết kiệm nào.',
            textAlign: TextAlign.center,
            style: GlassTypography.bodyMd(),
          ),
        ),
      );
    }

    // Chip trạng thái chỉ hiện khi có mục tiêu thuộc nhóm đó
    final filters = [
      for (final f in _GoalFilter.values)
        if (f == _GoalFilter.all || (goals.any(f.matches) && goals.where(f.matches).length < goals.length)) f,
    ];
    final active = filters.contains(_filter) ? _filter : _GoalFilter.all;
    final shown = goals.where(active.matches).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (goals.any((g) => !g.isCancelled && !g.isDraft)) _SummaryCard(goals: goals),
        if (filters.length > 1) ...[
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in filters) ...[
                  GlassFilterChip(
                    label: f.label,
                    count: goals.where(f.matches).length,
                    selected: f == active,
                    onTap: () => setState(() => _filter = f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        for (final g in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _GoalCard(
              goal: g,
              onContribute: () => _contribute(g),
              onCancel: () => _cancelGoal(g),
              onActivate: () => _activate(g),
            ),
          ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circleAlert, size: 36, color: GlassColors.danger),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: GlassTypography.bodyMd()),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

/// Tổng các mục tiêu chưa hủy: đã tích lũy, mục tiêu, % hoàn thành, còn lại, số mục tiêu đang chạy.
class _SummaryCard extends StatelessWidget {
  final List<SavingsGoalEntity> goals;
  const _SummaryCard({required this.goals});

  @override
  Widget build(BuildContext context) {
    // Bản nháp không tính vào kế hoạch nên cũng không tính vào tổng.
    final counted = goals.where((g) => !g.isCancelled && !g.isDraft).toList();
    var saved = BigInt.zero;
    var target = BigInt.zero;
    for (final g in counted) {
      saved += g.currentAmountCents;
      target += g.targetAmountCents;
    }
    final remaining = target > saved ? target - saved : BigInt.zero;
    final percent = target > BigInt.zero ? (saved * BigInt.from(100) ~/ target).toInt().clamp(0, 100) : 0;
    final running = counted.where(_GoalFilter.active.matches).length;

    return GlassCard(
      level: 2,
      borderRadius: GlassRadius.roundedCardLarge,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TỔNG TIỀN ĐÃ TÍCH LŨY', style: GlassTypography.labelCaps()),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(formatVnd(saved), style: GlassTypography.displayHero()),
                    ),
                    const SizedBox(height: 6),
                    Text('Mục tiêu: ${formatVnd(target)}', style: GlassTypography.bodySm()),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                label: 'Hoàn thành $percent phần trăm',
                excludeSemantics: true,
                child: GlassCircularProgress(
                  percent: percent.toDouble(),
                  size: 84,
                  strokeWidth: 8,
                  progressColor: GlassColors.slateAnchor,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$percent%', style: GlassTypography.labelNumeric()),
                      Text('hoàn thành', style: GlassTypography.bodySm()),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: GlassColors.glassBorder),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text('Còn lại ${formatVnd(remaining)}', style: GlassTypography.labelNumeric()),
              Text('$running mục tiêu đang chạy', style: GlassTypography.bodyMd()),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoalEntity goal;
  final VoidCallback onContribute;
  final VoidCallback onCancel;
  final VoidCallback onActivate;

  const _GoalCard({required this.goal, required this.onContribute, required this.onCancel, required this.onActivate});

  @override
  Widget build(BuildContext context) {
    final percent = goal.progressPercentage;
    final label = goal.isCancelled ? 'Đã hủy' : (goal.isDraft ? 'Bản nháp' : goal.statusLabel());
    final color = goal.isCancelled || goal.isDraft
        ? GlassColors.textMuted
        : goal.isCompleted
        ? GlassColors.success
        : goal.isOverdue()
        ? GlassColors.danger
        : GlassColors.slateAnchor;
    final barState = goal.isCancelled
        ? GlassProgressState.normal
        : goal.isCompleted
        ? GlassProgressState.success
        : GlassProgressState.normal;
    final canContribute = !goal.isCompleted && !goal.isCancelled && !goal.isDraft;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/planning/goal', extra: goal),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: GlassColors.activeFill, borderRadius: GlassRadius.roundedInput),
                  child: Icon(LucideIcons.piggyBank, size: 22, color: GlassColors.activeFg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GlassTypography.headlineSm()),
                      if (goal.targetDate != null)
                        Text(
                          'Hạn chót: ${DateFormat('dd/MM/yyyy').format(goal.targetDate!)}',
                          style: GlassTypography.bodySm(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: goal.formattedCurrent, style: GlassTypography.labelNumeric()),
                          TextSpan(text: '  / ${goal.formattedTarget}', style: GlassTypography.bodySm()),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: GlassTypography.labelNumeric(color: goal.isCompleted ? GlassColors.success : GlassColors.slateAnchor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GlassProgressBar(percent: percent, state: barState, height: 8),
            const SizedBox(height: 12),
            GlassBadge(text: label, color: color),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: goal.isDraft
                      // Bản nháp chưa nạp tiền được: nút chính là kích hoạt (BE kiểm hạn chót).
                      ? GlassSecondaryButton(key: ValueKey('activate-goal-${goal.id}'), label: 'Kích hoạt mục tiêu', onPressed: onActivate)
                      : GlassSecondaryButton(
                          label: 'Nạp tiền vào mục tiêu',
                          onPressed: canContribute ? onContribute : null,
                        ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  key: ValueKey('edit-goal-${goal.id}'),
                  tooltip: 'Sửa',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                  icon: Icon(LucideIcons.pencil, size: 18, color: GlassColors.slateAnchor),
                  onPressed: () => context.push('/planning/goals/form', extra: goal),
                ),
                if (goal.status == 'active' || goal.isDraft)
                  IconButton(
                    key: ValueKey('cancel-goal-${goal.id}'),
                    tooltip: 'Hủy mục tiêu',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    icon: Icon(LucideIcons.x, size: 18, color: GlassColors.danger),
                    onPressed: onCancel,
                  ),
                IconButton(
                  key: ValueKey('goal-screen-${goal.id}'),
                  tooltip: 'Chi tiết mục tiêu',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                  icon: Icon(LucideIcons.chevronRight, size: 20, color: GlassColors.slateAnchor),
                  onPressed: () => context.push('/planning/goal', extra: goal),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
