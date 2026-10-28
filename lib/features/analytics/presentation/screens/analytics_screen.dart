import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/analytics/domain/report_models.dart';
import 'package:finmate/features/analytics/presentation/reports_providers.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';

/// Màu các lát của biểu đồ cơ cấu chi tiêu (lặp vòng nếu nhiều danh mục)
const _palette = <Color>[
  AppColors.primary,
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFF8B5CF6),
  Color(0xFF06B6D4),
  Color(0xFFEC4899),
];

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Phân tích chi tiêu & Xu hướng')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(monthlySummaryProvider);
          ref.invalidate(categoryBreakdownProvider);
          ref.invalidate(forecastProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPeriodSelector(context, isDark),
              const SizedBox(height: 24),
              _buildComparison(context, ref, isDark),
              const SizedBox(height: 28),
              _sectionTitle(context, 'CƠ CẤU CHI TIÊU THEO DANH MỤC'),
              const SizedBox(height: 16),
              _buildBreakdown(context, ref, isDark),
              const SizedBox(height: 28),
              _sectionTitle(context, 'DỰ BÁO CHI TIÊU ĐẾN CUỐI THÁNG'),
              const SizedBox(height: 16),
              _buildForecast(context, ref, isDark),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
      );

  BoxDecoration _card(bool isDark) => BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedLarge,
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      );

  /// Lỗi tải một phần: thông điệp thân thiện + Thử lại
  Widget _errorCard(BuildContext context, Object error, VoidCallback retry, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _card(isDark),
      child: Column(
        children: [
          Text(errorMessage(error), textAlign: TextAlign.center),
          TextButton(onPressed: retry, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  Widget _loadingCard(bool isDark) => Container(
        height: 120,
        decoration: _card(isDark),
        child: const Center(child: CircularProgressIndicator()),
      );

  // Bộ chọn kỳ: hiện chỉ có báo cáo tháng
  Widget _buildPeriodSelector(BuildContext context, bool isDark) {
    Widget tab(String label, {required bool enabled}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: enabled ? AppColors.primary : Colors.transparent,
              borderRadius: AppSpacing.roundedPill,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: enabled ? FontWeight.w600 : FontWeight.w400,
                  color: enabled ? Colors.white : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
            ),
          ),
        );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightSubtle,
            borderRadius: AppSpacing.roundedPill,
          ),
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

  // So sánh với tháng trước (ẩn nếu tháng trước không có dữ liệu)
  Widget _buildComparison(BuildContext context, WidgetRef ref, bool isDark) {
    return ref.watch(monthlySummaryProvider).when(
          loading: () => _loadingCard(isDark),
          error: (e, _) => _errorCard(context, e, () => ref.invalidate(monthlySummaryProvider), isDark),
          data: (summary) {
            final change = summary.changePercent;
            if (change == null) return const SizedBox.shrink();

            final down = change < 0;
            final same = change == 0;
            final color = same ? AppColors.textSecondaryDark : (down ? AppColors.safe : AppColors.danger);
            final percent = NumberFormat('0.#', 'vi_VN').format(change.abs());
            final diff = (summary.totalSpentCents - summary.prevMonthSpentCents).abs();

            return Container(
              padding: const EdgeInsets.all(18),
              decoration: _card(isDark),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: Icon(same ? LucideIcons.minus : (down ? LucideIcons.trendingDown : LucideIcons.trendingUp), color: color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          same ? 'Chi tiêu không đổi' : 'Chi tiêu ${down ? 'giảm' : 'tăng'} $percent%',
                          style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, color: color),
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
            );
          },
        );
  }

  Widget _buildBreakdown(BuildContext context, WidgetRef ref, bool isDark) {
    return ref.watch(categoryBreakdownProvider).when(
          loading: () => _loadingCard(isDark),
          error: (e, _) => _errorCard(context, e, () => ref.invalidate(categoryBreakdownProvider), isDark),
          data: (breakdown) {
            if (breakdown.items.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: _card(isDark),
                child: Center(child: Text('Chưa có chi tiêu tháng này', style: AppTypography.caption(context))),
              );
            }

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: _card(isDark),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 55,
                        sections: [
                          for (final (i, item) in breakdown.items.indexed)
                            PieChartSectionData(
                              color: _palette[i % _palette.length],
                              value: item.percent <= 0 ? 0.01 : item.percent,
                              title: item.percent >= 8 ? '${item.percent.round()}%' : '',
                              radius: 35,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final (i, item) in breakdown.items.indexed) _legendRow(context, item, _palette[i % _palette.length]),
                ],
              ),
            );
          },
        );
  }

  Widget _legendRow(BuildContext context, CategoryShare item, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Flexible(child: Text('${item.name} (${item.percent.round()}%)', style: AppTypography.caption(context), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Text(formatVnd(item.spentCents), style: AppTypography.tabular(AppTypography.caption(context).copyWith(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  static const _confidenceLabels = {'low': 'thấp', 'medium': 'trung bình', 'high': 'cao'};

  Widget _buildForecast(BuildContext context, WidgetRef ref, bool isDark) {
    final budget = ref.watch(planningControllerProvider).valueOrNull?.overallBudget;

    return ref.watch(forecastProvider).when(
          loading: () => _loadingCard(isDark),
          error: (e, _) => _errorCard(context, e, () => ref.invalidate(forecastProvider), isDark),
          data: (forecast) {
            if (!forecast.hasData) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: _card(isDark),
                child: Center(child: Text('Chưa đủ dữ liệu để dự báo', style: AppTypography.caption(context))),
              );
            }

            final limit = budget?.limitAmountCents;
            final ratio = limit == null || limit <= BigInt.zero ? null : (forecast.projectedSpendCents.toInt() / limit.toInt());
            final over = ratio != null && ratio > 1;

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: _card(isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _forecastRow(context, 'Đã chi tới nay', formatVnd(forecast.spentSoFarCents)),
                  const SizedBox(height: 8),
                  _forecastRow(context, 'Dự kiến cuối tháng', formatVnd(forecast.projectedSpendCents), emphasize: true),
                  if (limit != null) ...[
                    const SizedBox(height: 8),
                    _forecastRow(context, 'Ngân sách tháng', formatVnd(limit)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (ratio ?? 0).clamp(0.0, 1.0),
                        backgroundColor: isDark ? Colors.white10 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(over ? AppColors.danger : AppColors.safe),
                        minHeight: 8,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Độ tin cậy: ${_confidenceLabels[forecast.confidence] ?? forecast.confidence} · dựa trên ${forecast.basedOnDays} ngày',
                    style: AppTypography.caption(context),
                  ),
                  if (forecast.advice != null) ...[
                    const Divider(height: 24),
                    _forecastRow(context, 'Thu nhập tháng', formatVnd(forecast.advice!.monthlyIncomeCents)),
                    const SizedBox(height: 8),
                    _forecastRow(context, 'Số dư dự kiến cuối tháng', formatVnd(forecast.advice!.projectedBalanceCents), emphasize: true),
                    if (forecast.advice!.suggestedDailyCutCents != null) ...[
                      const SizedBox(height: 8),
                      _forecastRow(context, 'Gợi ý cắt giảm mỗi ngày', formatVnd(forecast.advice!.suggestedDailyCutCents!)),
                    ],
                  ],
                ],
              ),
            );
          },
        );
  }

  Widget _forecastRow(BuildContext context, String label, String value, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.caption(context)),
        Text(
          value,
          style: AppTypography.tabular(
            (emphasize ? AppTypography.bodyLarge(context) : AppTypography.bodyMedium(context)).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
