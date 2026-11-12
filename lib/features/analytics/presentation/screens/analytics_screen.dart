import 'package:fl_chart/fl_chart.dart';
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
import 'package:finmate/features/analytics/domain/report_models.dart';
import 'package:finmate/features/analytics/presentation/reports_providers.dart';
import 'package:finmate/features/dashboard/presentation/widgets/app_bottom_nav.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phân tích chi tiêu & Xu hướng')),
      body: AmbientGlassBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(monthlySummaryProvider);
            ref.invalidate(categoryBreakdownProvider);
            ref.invalidate(forecastProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPeriodSelector(context),
                const SizedBox(height: 14),

                // Quick Tools Row (F2, F3, F4, F5, F6)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ZenvestActionPill(
                        label: 'Cơ cấu danh mục',
                        trailingIcon: LucideIcons.pieChart,
                        onTap: () => context.push('/analytics/category-report'),
                      ),
                      const SizedBox(width: 8),
                      ZenvestActionPill(
                        label: 'Dự báo dòng tiền',
                        trailingIcon: LucideIcons.trendingUp,
                        onTap: () => context.push('/analytics/forecast'),
                      ),
                      const SizedBox(width: 8),
                      ZenvestActionPill(
                        label: 'Cảnh báo bất thường',
                        trailingIcon: LucideIcons.triangleAlert,
                        onTap: () => context.push('/analytics/anomalies'),
                      ),
                      const SizedBox(width: 8),
                      ZenvestActionPill(
                        label: 'Nên mua không?',
                        trailingIcon: LucideIcons.shoppingBag,
                        onTap: () => context.push('/analytics/purchase-check'),
                      ),
                      const SizedBox(width: 8),
                      ZenvestActionPill(
                        label: 'Nhận xét AI',
                        trailingIcon: LucideIcons.sparkles,
                        onTap: () => context.push('/analytics/insights'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                _buildComparison(context, ref),
                const SizedBox(height: 18),
                ZenvestSurfaceSheet(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionTitle(context, 'CƠ CẤU CHI TIÊU THEO DANH MỤC'),
                      const SizedBox(height: 14),
                      _buildBreakdown(context, ref),
                      const SizedBox(height: 24),
                      _sectionTitle(context, 'DỰ BÁO CHI TIÊU ĐẾN CUỐI THÁNG'),
                      const SizedBox(height: 14),
                      _buildForecast(context, ref),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        style: AppTypography.sectionLabel(context),
      );

  Widget _errorCard(BuildContext context, Object error, VoidCallback retry) {
    return LiquidGlassCard(
      enableBlur: false,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(errorMessage(error), textAlign: TextAlign.center),
          TextButton(onPressed: retry, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  Widget _loadingCard() => const LiquidGlassCard(
        enableBlur: false,
        child: SizedBox(
          height: 88,
          child: Center(child: CircularProgressIndicator()),
        ),
      );

  // Bộ chọn kỳ kiểu Pill Segmented Switcher (Ảnh tham chiếu 1 & 2)
  Widget _buildPeriodSelector(BuildContext context) {
    final actionColor = AppColors.primaryAction(context);
    final onActionColor = AppColors.onPrimaryAction(context);
    final mutedColor = AppColors.textMuted(context);

    Widget tab(String label, {required bool enabled}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: enabled ? actionColor : Colors.transparent,
              borderRadius: AppSpacing.roundedPill,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: enabled ? FontWeight.w700 : FontWeight.w500,
                  color: enabled ? onActionColor : mutedColor,
                ),
              ),
            ),
          ),
        );

    return Column(
      children: [
        LiquidGlassCard(
          enableBlur: false,
          borderRadius: AppSpacing.roundedPill,
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              tab('Tháng này', enabled: true),
              tab('Tuần này', enabled: false),
              tab('Năm nay', enabled: false),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text('Tuần và năm sắp có.', style: AppTypography.caption(context)),
      ],
    );
  }

  // So sánh với tháng trước (Thẻ kính Zenvest Analytics - Ảnh 2)
  Widget _buildComparison(BuildContext context, WidgetRef ref) {
    return ref.watch(monthlySummaryProvider).when(
          loading: _loadingCard,
          error: (e, _) => _errorCard(
            context,
            e,
            () => ref.invalidate(monthlySummaryProvider),
          ),
          data: (summary) {
            final change = summary.changePercent;
            if (change == null) return const SizedBox.shrink();

            final down = change < 0;
            final same = change == 0;
            final color = same
                ? AppColors.textSecondary(context)
                : (down ? AppColors.safe : AppColors.danger);
            final percent = NumberFormat('0.#', 'vi_VN').format(change.abs());
            final diff =
                (summary.totalSpentCents - summary.prevMonthSpentCents).abs();

            return ZenvestHeroDeck(
              peekBadgeText: 'TREND',
              child: LiquidGlassCard(
                variant: LiquidGlassVariant.iridescentHero,
                enableBlur: true,
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        same
                            ? LucideIcons.minus
                            : (down
                                ? LucideIcons.trendingDown
                                : LucideIcons.trendingUp),
                        color: color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            same
                                ? 'Chi tiêu không đổi'
                                : 'Chi tiêu ${down ? 'giảm' : 'tăng'} $percent%',
                            style: AppTypography.body(context).copyWith(
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            same
                                ? 'Chi tiêu bằng tháng trước.'
                                : 'Bạn đã chi ${down ? 'ít hơn' : 'nhiều hơn'} ${formatVnd(diff)} so với tháng trước.',
                            style: AppTypography.caption(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }

  Widget _buildBreakdown(BuildContext context, WidgetRef ref) {
    final palette = AppColors.activeChartPalette(context);

    return ref.watch(categoryBreakdownProvider).when(
          loading: _loadingCard,
          error: (e, _) => _errorCard(
            context,
            e,
            () => ref.invalidate(categoryBreakdownProvider),
          ),
          data: (breakdown) {
            if (breakdown.items.isEmpty) {
              return LiquidGlassCard(
                enableBlur: false,
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Chưa có chi tiêu tháng này',
                    style: AppTypography.caption(context),
                  ),
                ),
              );
            }

            return LiquidGlassCard(
              variant: LiquidGlassVariant.sheetContainer,
              enableBlur: false,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SizedBox(
                    height: 185,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 56,
                        sections: [
                          for (final (i, item) in breakdown.items.indexed)
                            PieChartSectionData(
                              color: palette[i % palette.length],
                              value: item.percent <= 0 ? 0.01 : item.percent,
                              title: item.percent >= 8
                                  ? '${item.percent.round()}%'
                                  : '',
                              radius: 36,
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.surfaceLightElevated,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final (i, item) in breakdown.items.indexed)
                    _legendRow(context, item, palette[i % palette.length]),
                ],
              ),
            );
          },
        );
  }

  Widget _legendRow(BuildContext context, CategoryShare item, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    '${item.name} (${item.percent.round()}%)',
                    style: AppTypography.body(context).copyWith(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatVnd(item.spentCents),
            style: AppTypography.tabular(
              AppTypography.bodyMedium(context).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _confidenceLabels = {
    'low': 'thấp',
    'medium': 'trung bình',
    'high': 'cao',
  };

  Widget _buildForecast(BuildContext context, WidgetRef ref) {
    final budget =
        ref.watch(planningControllerProvider).valueOrNull?.overallBudget;

    return ref.watch(forecastProvider).when(
          loading: _loadingCard,
          error: (e, _) => _errorCard(
            context,
            e,
            () => ref.invalidate(forecastProvider),
          ),
          data: (forecast) {
            if (!forecast.hasData) {
              return LiquidGlassCard(
                enableBlur: false,
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Chưa đủ dữ liệu để dự báo',
                    style: AppTypography.caption(context),
                  ),
                ),
              );
            }

            final limit = budget?.limitAmountCents;
            final ratio = limit == null || limit <= BigInt.zero
                ? null
                : (forecast.projectedSpendCents.toInt() / limit.toInt());
            final over = ratio != null && ratio > 1;

            return LiquidGlassCard(
              enableBlur: false,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _forecastRow(
                    context,
                    'Đã chi tới nay',
                    formatVnd(forecast.spentSoFarCents),
                  ),
                  const SizedBox(height: 8),
                  _forecastRow(
                    context,
                    'Dự kiến cuối tháng',
                    formatVnd(forecast.projectedSpendCents),
                    emphasize: true,
                  ),
                  if (limit != null) ...[
                    const SizedBox(height: 8),
                    _forecastRow(context, 'Ngân sách tháng', formatVnd(limit)),
                    const SizedBox(height: 12),
                    LiquidGlassProgressBar(
                      value: (ratio ?? 0).clamp(0.0, 1.0),
                      color: over ? AppColors.danger : AppColors.safe,
                      height: 8,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Độ tin cậy: ${_confidenceLabels[forecast.confidence] ?? forecast.confidence} · dựa trên ${forecast.basedOnDays} ngày',
                    style: AppTypography.caption(context),
                  ),
                  if (forecast.advice != null) ...[
                    Divider(height: 24, color: AppColors.border(context)),
                    _forecastRow(
                      context,
                      'Thu nhập tháng',
                      formatVnd(forecast.advice!.monthlyIncomeCents),
                    ),
                    const SizedBox(height: 8),
                    _forecastRow(
                      context,
                      'Số dư dự kiến cuối tháng',
                      formatVnd(forecast.advice!.projectedBalanceCents),
                      emphasize: true,
                    ),
                    if (forecast.advice!.suggestedDailyCutCents != null) ...[
                      const SizedBox(height: 8),
                      _forecastRow(
                        context,
                        'Gợi ý cắt giảm mỗi ngày',
                        formatVnd(forecast.advice!.suggestedDailyCutCents!),
                      ),
                    ],
                  ],
                ],
              ),
            );
          },
        );
  }

  Widget _forecastRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.caption(context)),
        Text(
          value,
          style: AppTypography.tabular(
            (emphasize
                    ? AppTypography.bodyLarge(context)
                    : AppTypography.bodyMedium(context))
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
