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
import 'package:finmate/features/planning/domain/entities/savings_goal_entity.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';

/// Màn G4: Chi tiết mục tiêu tiết kiệm (Savings Goal Detail Screen)
class SavingsGoalDetailScreen extends ConsumerStatefulWidget {
  final SavingsGoalEntity goal;

  const SavingsGoalDetailScreen({super.key, required this.goal});

  @override
  ConsumerState<SavingsGoalDetailScreen> createState() => _SavingsGoalDetailScreenState();
}

class _SavingsGoalDetailScreenState extends ConsumerState<SavingsGoalDetailScreen> {
  late SavingsGoalEntity _goal = widget.goal;

  Future<void> _contribute() async {
    final amountController = TextEditingController();
    final amount = await showDialog<BigInt>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nạp tiền vào "${_goal.title}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nhập số tiền bạn muốn trích nạp thêm:'),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '500.000',
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
              final parsed = int.tryParse(raw);
              if (parsed != null && parsed > 0) {
                Navigator.pop(ctx, BigInt.from(parsed));
              }
            },
            child: const Text('Nạp tiền'),
          ),
        ],
      ),
    );

    if (amount != null && mounted) {
      await ref.read(planningControllerProvider.notifier).contributeToGoal(_goal.id, amount);
      if (!mounted) return;
      setState(() {
        _goal = _goal.copyWith(
          currentAmountCents: _goal.currentAmountCents + amount,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã nạp ${formatVnd(amount)} vào mục tiêu thành công!'),
          backgroundColor: AppColors.safe,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _goal.targetAmountCents;
    final current = _goal.currentAmountCents;
    final progress = target > BigInt.zero ? (current.toDouble() / target.toDouble()).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toInt();
    final remaining = target > current ? target - current : BigInt.zero;

    return Scaffold(
      appBar: AppBar(
        title: Text(_goal.title),
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
              // Hero Progress Card
              ZenvestHeroDeck(
                peekBadgeText: '$percent%',
                child: LiquidGlassCard(
                  variant: LiquidGlassVariant.iridescentHero,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.piggyBank, color: AppColors.secondary, size: 24),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.safe.withValues(alpha: 0.14),
                              borderRadius: AppSpacing.roundedPill,
                            ),
                            child: Text(
                              percent >= 100 ? 'Đã hoàn thành' : 'Đang tích lũy ($percent%)',
                              style: const TextStyle(
                                color: AppColors.safe,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _goal.title,
                        textAlign: TextAlign.center,
                        style: AppTypography.h1(context).copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Đã tích lũy: ${_goal.formattedCurrent} / ${_goal.formattedTarget}',
                        style: AppTypography.caption(context).copyWith(fontSize: 13.5),
                      ),
                      const SizedBox(height: 18),
                      LiquidGlassProgressBar(
                        value: progress,
                        color: percent >= 100 ? AppColors.safe : AppColors.secondary,
                        height: 8,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Còn thiếu', style: AppTypography.caption(context)),
                              Text(
                                formatVnd(remaining),
                                style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          if (_goal.targetDate != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Hạn mục tiêu', style: AppTypography.caption(context)),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(_goal.targetDate!),
                                  style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              LiquidGlassPillButton(
                label: 'Nạp thêm tiền vào mục tiêu',
                icon: LucideIcons.plus,
                isFullWidth: true,
                onPressed: _contribute,
              ),

              const SizedBox(height: 24),

              // Advice card
              ZenvestSurfaceSheet(
                title: 'Kế hoạch hành động',
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.sparkles, size: 20, color: AppColors.secondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tiết kiệm khoảng 125.000 ₫ mỗi ngày sẽ giúp bạn chạm đích đúng hẹn!',
                            style: AppTypography.body(context).copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
