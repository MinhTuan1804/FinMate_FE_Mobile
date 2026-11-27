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
import 'package:finmate/features/planning/domain/entities/budget_entity.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';
import 'package:finmate/features/recurring/presentation/controllers/recurring_items_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_app_bar.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_progress_bar.dart';
import 'package:finmate/shared/widgets/glass/main_bottom_nav.dart';

/// G1 — Kế hoạch tài chính (hub): hạn mức chi an toàn theo ngày + 4 trụ cột (mục tiêu, ngân sách, chi phí định kỳ, khoản vay),
/// mỗi trụ cột mở màn riêng (G2/G5/G7 và khoản vay). Khối "FinMate AI đề xuất" trong Figma chưa có dữ liệu BE nên không hiển thị.
class PlanningHubScreen extends ConsumerWidget {
  const PlanningHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(planningControllerProvider);
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: glassAppBar(context, title: 'Kế hoạch tài chính'),
        bottomNavigationBar: const MainBottomNav(currentIndex: 2),
        body: SafeArea(
          child: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorMessage(e), textAlign: TextAlign.center, style: GlassTypography.bodyMd()),
                    const SizedBox(height: 12),
                    GlassSecondaryButton(
                      label: 'Thử lại',
                      onPressed: () => ref.read(planningControllerProvider.notifier).loadPlanningData(),
                    ),
                  ],
                ),
              ),
            ),
            data: (planning) => RefreshIndicator(
              onRefresh: () => ref.read(planningControllerProvider.notifier).loadPlanningData(silent: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _DailyLimitCard(planning: planning),
                  const SizedBox(height: 24),
                  _PillarsSection(planning: planning),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

GlassProgressState _stateOf(BudgetEntity b) => switch (b.statusLevel) {
      BudgetStatusLevel.danger => GlassProgressState.danger,
      BudgetStatusLevel.warning => GlassProgressState.warning,
      BudgetStatusLevel.safe => GlassProgressState.success,
    };

Color _colorOf(BudgetEntity b) => switch (b.statusLevel) {
      BudgetStatusLevel.danger => GlassColors.danger,
      BudgetStatusLevel.warning => GlassColors.warning,
      BudgetStatusLevel.safe => GlassColors.success,
    };

class _DailyLimitCard extends ConsumerWidget {
  final PlanningState planning;

  const _DailyLimitCard({required this.planning});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overall = planning.overallBudget;
    if (overall == null) {
      return GlassCard(
        level: 2,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HẠN MỨC THEO NGÀY', style: GlassTypography.labelCaps()),
            const SizedBox(height: 8),
            Text('Bạn chưa đặt ngân sách tháng này. Đặt hạn mức tổng để biết mỗi ngày nên chi bao nhiêu.', style: GlassTypography.bodyMd()),
            const SizedBox(height: 14),
            GlassPrimaryButton(
              key: const ValueKey('hub-create-total-budget'),
              label: 'Đặt ngân sách tháng',
              icon: LucideIcons.plus,
              onPressed: () => context.push('/planning/budgets/form'),
            ),
          ],
        ),
      );
    }
    final color = _colorOf(overall);
    final badge = switch (overall.statusLevel) {
      BudgetStatusLevel.danger => overall.isOverspent ? 'Đã vượt ngân sách' : 'Sát ngưỡng',
      BudgetStatusLevel.warning => 'Cận ngưỡng',
      BudgetStatusLevel.safe => 'Trong vùng an toàn',
    };
    final percent = overall.spendingPercentage.clamp(0, 100).toDouble();
    return GlassCard(
      level: 2,
      borderRadius: GlassRadius.roundedCardLarge,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text('HẠN MỨC THEO NGÀY', style: GlassTypography.labelCaps())),
              const SizedBox(width: 8),
              Flexible(child: GlassBadge(text: badge, color: color)),
            ],
          ),
          const SizedBox(height: 14),
          Text('Chi an toàn hôm nay', style: GlassTypography.bodyMd()),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: formatVnd(effectiveDailySafeLimit(ref, planning)), style: GlassTypography.displayHero()),
                TextSpan(text: '  còn lại khả dụng', style: GlassTypography.bodyMd()),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: 'Đã dùng ${overall.spendingPercentage.round()}% ngân sách tháng',
            excludeSemantics: true,
            child: GlassProgressBar(percent: percent, state: _stateOf(overall), height: 8),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'Đã chi tháng: ', style: GlassTypography.bodySm()),
                    TextSpan(text: overall.formattedSpent, style: GlassTypography.labelNumeric().copyWith(fontSize: 12)),
                  ]),
                ),
              ),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Ngân sách: ', style: GlassTypography.bodySm()),
                  TextSpan(text: overall.formattedLimit, style: GlassTypography.labelNumeric().copyWith(fontSize: 12)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: GlassColors.glassBorder),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Chu kỳ: Hôm nay, ${DateFormat('dd/MM').format(DateTime.now())}',
                  style: GlassTypography.bodySm(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                key: const ValueKey('hub-open-budgets-from-daily'),
                onPressed: () => context.push('/planning/budgets'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Chi tiết chi tiêu', style: GlassTypography.bodySm(color: GlassColors.activeFg).copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Icon(LucideIcons.arrowRight, size: 14, color: GlassColors.activeFg),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillarsSection extends ConsumerWidget {
  final PlanningState planning;

  const _PillarsSection({required this.planning});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurring = ref.watch(recurringItemsControllerProvider).valueOrNull ?? const <RecurringItemEntity>[];
    final activeRecurring = recurring.where((r) => r.status == RecurringStatus.active).toList()
      ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

    final goals = planning.savingsGoals.where((g) => !g.isCancelled).toList();
    final running = goals.where((g) => !g.isCompleted).length;
    final saved = goals.fold<BigInt>(BigInt.zero, (s, g) => s + g.currentAmountCents);
    final target = goals.fold<BigInt>(BigInt.zero, (s, g) => s + g.targetAmountCents);
    final goalPercent = target > BigInt.zero ? (saved.toDouble() / target.toDouble() * 100).clamp(0, 100).toDouble() : 0.0;

    final total = planning.overallBudget;
    final categories = planning.categoryBudgets;
    final now = DateTime.now();

    final pillars = <Widget>[
      _PillarCard(
        key: const ValueKey('hub-pillar-goals'),
        icon: LucideIcons.piggyBank,
        title: 'Mục tiêu tích lũy',
        subtitle: goals.isEmpty ? 'Chưa có mục tiêu nào' : '$running mục tiêu đang chạy',
        badge: goals.isEmpty ? null : '${goalPercent.round()}%',
        progress: goals.isEmpty ? null : (goalPercent, GlassProgressState.normal),
        footLabel: 'Đã góp',
        footValue: formatVnd(saved),
        onTap: () => context.push('/planning/goals'),
      ),
      _PillarCard(
        key: const ValueKey('hub-pillar-budgets'),
        icon: LucideIcons.chartPie,
        title: 'Ngân sách chi tiêu',
        subtitle: total == null && categories.isEmpty ? 'Chưa đặt ngân sách tháng này' : null,
        warning: total != null && total.statusLevel != BudgetStatusLevel.safe
            ? (total.isOverspent ? 'Đã vượt ngân sách' : 'Sắp chạm ngưỡng')
            : null,
        warningColor: total == null ? null : _colorOf(total),
        badge: total == null ? null : '${total.spendingPercentage.round()}%',
        badgeColor: total == null ? null : _colorOf(total),
        progress: total == null ? null : (total.spendingPercentage.clamp(0, 100).toDouble(), _stateOf(total)),
        footLabel: 'Tháng ${now.month}',
        footValue: total == null ? null : '${total.formattedSpent} / ${total.formattedLimit}',
        onTap: () => context.push('/planning/budgets'),
      ),
      _PillarCard(
        key: const ValueKey('hub-pillar-recurring'),
        icon: LucideIcons.calendarClock,
        title: 'Chi phí định kỳ',
        subtitle: activeRecurring.isEmpty ? 'Chưa có khoản định kỳ nào' : 'Kỳ tới: ${DateFormat('dd/MM').format(activeRecurring.first.nextDueDate)}',
        badge: activeRecurring.isEmpty ? null : '${activeRecurring.length} khoản',
        footLabel: activeRecurring.isEmpty ? null : 'Sắp đến hạn',
        footTitle: activeRecurring.isEmpty ? null : activeRecurring.first.name,
        footValue: activeRecurring.isEmpty ? null : formatVnd(activeRecurring.first.amountCents),
        onTap: () => context.push('/planning/recurring'),
      ),
      _PillarCard(
        key: const ValueKey('hub-pillar-loans'),
        icon: LucideIcons.car,
        title: 'Khoản vay & Nợ',
        subtitle: 'Theo dõi khoản vay, khoản cho vay và lịch trả',
        onTap: () => context.push('/planning/loans'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Row(
            children: [
              Expanded(child: Semantics(header: true, child: Text('Trụ cột kế hoạch', style: GlassTypography.headlineMd()))),
              const SizedBox(width: 8),
              Text('4 TRỤ CỘT', style: GlassTypography.labelCaps()),
            ],
          ),
        ),
        for (final p in pillars) Padding(padding: const EdgeInsets.only(bottom: 12), child: p),
      ],
    );
  }
}

/// Thẻ một trụ cột: icon, tiêu đề, dòng phụ/cảnh báo, huy hiệu, thanh tiến độ (nếu có số liệu) và dòng chân thẻ.
/// Các phần không có dữ liệu thật thì bỏ, không điền số giả.
class _PillarCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? warning;
  final Color? warningColor;
  final String? badge;
  final Color? badgeColor;
  final (double, GlassProgressState)? progress;
  final String? footLabel;
  final String? footTitle;
  final String? footValue;
  final VoidCallback onTap;

  const _PillarCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.warning,
    this.warningColor,
    this.badge,
    this.badgeColor,
    this.progress,
    this.footLabel,
    this.footTitle,
    this.footValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        borderRadius: GlassRadius.roundedCard,
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: GlassColors.activeFill, borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, size: 20, color: GlassColors.activeFg),
                  ),
                  const Spacer(),
                  if (badge != null) GlassBadge(text: badge!, color: badgeColor ?? GlassColors.slateAnchor),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.chevronRight, size: 18, color: GlassColors.textMuted),
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: GlassTypography.headlineMd().copyWith(fontSize: 18)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: GlassTypography.bodySm(color: GlassColors.textSecondary)),
              ],
              if (warning != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(LucideIcons.triangleAlert, size: 13, color: warningColor ?? GlassColors.warning),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(warning!, style: GlassTypography.bodySm(color: warningColor ?? GlassColors.warning).copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
              if (progress != null) ...[
                const SizedBox(height: 12),
                GlassProgressBar(percent: progress!.$1, state: progress!.$2, height: 8),
              ],
              if (footLabel != null || footValue != null) ...[
                SizedBox(height: progress != null ? 10 : 12),
                if (progress == null) Divider(height: 1, color: GlassColors.glassBorder),
                if (progress == null) const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (footLabel != null) Text(footLabel!, style: GlassTypography.bodySm()),
                          if (footTitle != null)
                            Text(footTitle!, style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (footValue != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          footValue!,
                          textAlign: TextAlign.right,
                          style: GlassTypography.labelNumeric().copyWith(fontSize: 14, fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', FontWeight.w700.value.toDouble())]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
