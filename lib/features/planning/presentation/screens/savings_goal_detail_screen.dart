import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_app_bar.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_bottom_dock.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_circular_progress.dart';
import 'package:finmate/shared/widgets/glass/glass_loading_spinner.dart';

BigInt _remainingOf(SavingsGoalEntity goal) =>
    goal.targetAmountCents > goal.currentAmountCents ? goal.targetAmountCents - goal.currentAmountCents : BigInt.zero;

/// Hộp thoại nhập số tiền nạp vào mục tiêu; trả về null nếu hủy. Dùng chung cho G2 và G4.
/// [remainingCents]: phần còn lại của mục tiêu — server từ chối góp nhiều hơn, nên chặn luôn ở đây.
Future<BigInt?> showGoalContributeDialog(BuildContext context, String goalTitle, {BigInt? remainingCents}) {
  return showDialog<BigInt>(context: context, builder: (_) => _ContributeDialog(goalTitle: goalTitle, remainingCents: remainingCents));
}

class _ContributeDialog extends StatefulWidget {
  final String goalTitle;
  final BigInt? remainingCents;
  const _ContributeDialog({required this.goalTitle, this.remainingCents});

  @override
  State<_ContributeDialog> createState() => _ContributeDialogState();
}

class _ContributeDialogState extends State<_ContributeDialog> {
  final _amount = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final value = parseAmountInput(_amount.text);
    final remaining = widget.remainingCents;
    if (value == null) {
      setState(() => _error = 'Vui lòng nhập số tiền hợp lệ');
    } else if (remaining != null && value > remaining) {
      setState(() => _error = 'Tối đa ${formatVnd(remaining)} (phần còn lại của mục tiêu)');
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

/// Màn G4: Chi tiết mục tiêu tiết kiệm.
class SavingsGoalDetailScreen extends ConsumerStatefulWidget {
  final SavingsGoalEntity goal;

  const SavingsGoalDetailScreen({super.key, required this.goal});

  @override
  ConsumerState<SavingsGoalDetailScreen> createState() => _SavingsGoalDetailScreenState();
}

class _SavingsGoalDetailScreenState extends ConsumerState<SavingsGoalDetailScreen> {
  late Future<GoalProgressEntity> _progress = _loadProgress();

  Future<GoalProgressEntity> _loadProgress() => ref.read(planningControllerProvider.notifier).getGoalProgress(widget.goal.id);

  void _reload() {
    setState(() {
      _progress = _loadProgress();
    });
  }

  Future<void> _contribute(SavingsGoalEntity goal) async {
    final amount = await showGoalContributeDialog(context, goal.title, remainingCents: _remainingOf(goal));
    if (amount == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(planningControllerProvider.notifier).contributeToGoal(goal.id, amount);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
      return;
    }
    if (!mounted) return;
    _reload();
    messenger.showSnackBar(SnackBar(content: Text('Đã nạp ${formatVnd(amount)} vào mục tiêu thành công!')));
  }

  Future<void> _edit(SavingsGoalEntity goal) async {
    await context.push('/planning/goals/form', extra: goal);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    // Lấy bản mới nhất trong state (sau khi nạp/sửa); rơi về bản truyền vào nếu chưa có
    final goals = ref.watch(planningControllerProvider).valueOrNull?.savingsGoals ?? const <SavingsGoalEntity>[];
    final goal = goals.where((g) => g.id == widget.goal.id).firstOrNull ?? widget.goal;
    final canContribute = !goal.isCompleted && !goal.isCancelled;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: glassAppBar(
          context,
          title: goal.title,
          actions: [
            IconButton(
              key: const ValueKey('edit-goal-detail'),
              tooltip: 'Sửa mục tiêu',
              icon: Icon(LucideIcons.pencil, size: 20, color: GlassColors.slateAnchor),
              onPressed: () => _edit(goal),
            ),
          ],
        ),
        bottomNavigationBar: GlassBottomDock(
          actions: [
            GlassPrimaryButton(
              key: const ValueKey('contribute-goal'),
              label: 'Nạp tiền vào mục tiêu',
              icon: LucideIcons.circlePlus,
              onPressed: canContribute ? () => _contribute(goal) : null,
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: FutureBuilder<GoalProgressEntity>(
            future: _progress,
            builder: (context, snap) {
              final progress = snap.data;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _HeroCard(goal: goal, progress: progress),
                  const SizedBox(height: 16),
                  if (snap.connectionState != ConnectionState.done)
                    const GlassCard(child: GlassLoadingSpinner())
                  else if (snap.hasError)
                    _HistoryError(message: errorMessage(snap.error!), onRetry: _reload)
                  else if (progress != null) ...[
                    _PaceNote(progress: progress),
                    _HistoryCard(contributions: progress.recentContributions),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final SavingsGoalEntity goal;
  final GoalProgressEntity? progress;

  const _HeroCard({required this.goal, required this.progress});

  @override
  Widget build(BuildContext context) {
    final percent = goal.progressPercentage.clamp(0, 100).toDouble();
    final remaining = goal.targetAmountCents > goal.currentAmountCents ? goal.targetAmountCents - goal.currentAmountCents : BigInt.zero;
    final days = progress?.daysRemaining;
    final label = goal.isCancelled ? 'Đã hủy' : goal.statusLabel();
    final badgeColor = goal.isCancelled
        ? GlassColors.textMuted
        : goal.isCompleted
        ? GlassColors.success
        : goal.isOverdue()
        ? GlassColors.danger
        : GlassColors.slateAnchor;

    return GlassCard(
      level: 2,
      borderRadius: GlassRadius.roundedCardLarge,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GlassBadge(text: label, color: badgeColor),
          const SizedBox(height: 16),
          Semantics(
            label: 'Đã đạt ${percent.toStringAsFixed(0)} phần trăm',
            excludeSemantics: true,
            child: GlassCircularProgress(
              percent: percent,
              size: 168,
              strokeWidth: 12,
              progressColor: goal.isCompleted ? GlassColors.success : GlassColors.slateAnchor,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ĐÃ ĐẠT', style: GlassTypography.labelCaps()),
                  Text('${percent.toStringAsFixed(0)}%', style: GlassTypography.displayHero()),
                  if (days != null && !goal.isCompleted && !goal.isCancelled)
                    GlassBadge(text: days > 0 ? 'Còn $days ngày' : 'Đã đến hạn', color: GlassColors.slateAnchor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Amount(label: 'Hiện có', value: goal.formattedCurrent)),
              Expanded(child: _Amount(label: 'Mục tiêu', value: goal.formattedTarget)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: GlassColors.activeFill, borderRadius: GlassRadius.roundedInput),
            child: Row(
              children: [
                Icon(goal.isCompleted ? LucideIcons.circleCheck : LucideIcons.flag, size: 18, color: GlassColors.activeFg),
                const SizedBox(width: 8),
                Expanded(
                  // Một dòng, tự thu nhỏ chữ khi hẹp thay vì xuống hàng.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      goal.isCompleted ? 'Đã hoàn thành mục tiêu' : 'Chỉ còn thiếu ${formatVnd(remaining)} để hoàn tất',
                      maxLines: 1,
                      style: GlassTypography.bodyMd(color: GlassColors.activeFg).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (goal.targetDate != null) ...[
            const SizedBox(height: 10),
            Text('Hạn chót: ${DateFormat('dd/MM/yyyy').format(goal.targetDate!)}', style: GlassTypography.bodySm()),
          ],
        ],
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  final String label;
  final String value;
  const _Amount({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: GlassTypography.bodySm()),
        const SizedBox(height: 2),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: GlassTypography.labelNumeric())),
      ],
    );
  }
}

/// Gợi ý nhịp nạp từ BE: số tiền cần nạp mỗi ngày và đang đúng/chậm tiến độ.
class _PaceNote extends StatelessWidget {
  final GoalProgressEntity progress;
  const _PaceNote({required this.progress});

  @override
  Widget build(BuildContext context) {
    final perDay = progress.requiredPerDayCents;
    if (perDay == null || progress.status != 'active') return const SizedBox.shrink();
    final color = progress.isOnTrack ? GlassColors.success : GlassColors.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(LucideIcons.lightbulb, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Cần nạp ~${formatVnd(perDay)}/ngày · ${progress.isOnTrack ? 'Đang bám đúng nhịp' : 'Đang chậm so với kế hoạch'}',
                  maxLines: 1,
                  style: GlassTypography.bodyMd(color: GlassColors.textPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _HistoryError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center, style: GlassTypography.bodyMd(color: GlassColors.danger)),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final List<GoalContributionEntity> contributions;
  const _HistoryCard({required this.contributions});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.history, size: 20, color: GlassColors.slateAnchor),
              const SizedBox(width: 8),
              Expanded(child: Text('Lịch sử đóng góp', style: GlassTypography.headlineSm())),
            ],
          ),
          const SizedBox(height: 12),
          if (contributions.isEmpty)
            Text('Chưa có lần nạp nào.', style: GlassTypography.bodyMd())
          else
            for (final c in contributions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat('dd/MM/yyyy').format(c.contributedAt), style: GlassTypography.bodyMd(color: GlassColors.textPrimary)),
                          if (c.note != null && c.note!.isNotEmpty) Text(c.note!, style: GlassTypography.bodySm()),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('+${c.formattedAmount}', style: GlassTypography.labelNumeric(color: AppColors.incomeOn(context))),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
