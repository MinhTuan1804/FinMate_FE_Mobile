import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/analytics/presentation/reports_providers.dart';

/// Màn F3: Dự báo dòng tiền đến cuối tháng (Cashflow Forecast Screen)
class CashflowForecastScreen extends ConsumerWidget {
  const CashflowForecastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastAsync = ref.watch(forecastProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dự báo dòng tiền'),
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
              // Hero Projection Card
              ZenvestHeroDeck(
                peekBadgeText: 'AI-FC',
                child: LiquidGlassCard(
                  variant: LiquidGlassVariant.iridescentHero,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'DỰ BÁO CHI TIÊU HẾT THÁNG',
                            style: AppTypography.caption(context).copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.safe.withValues(alpha: 0.15),
                              borderRadius: AppSpacing.roundedPill,
                            ),
                            child: const Text(
                              'Độ tin cậy: Cao',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.safe,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      forecastAsync.when(
                        data: (fc) => Text(
                          formatVnd(fc.projectedSpendCents),
                          style: AppTypography.displayBalance(context).copyWith(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        loading: () => const Text('Đang tính toán...', style: TextStyle(fontSize: 24)),
                        error: (_, __) => const Text('—', style: TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Dựa trên tốc độ chi tiêu 14 ngày qua và các giao dịch định kỳ sắp tới.',
                        style: AppTypography.caption(context).copyWith(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Forecast Chart (Solid Actual vs Dashed Projected)
              ZenvestSurfaceSheet(
                title: 'Xu hướng dòng tiền trong tháng',
                child: Column(
                  children: [
                    SizedBox(
                      height: 190,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (val) => FlLine(
                              color: AppColors.border(context).withValues(alpha: 0.3),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 5,
                                getTitlesWidget: (val, meta) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'N${val.toInt()}',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.textMuted(context),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            // Thực tế (Đường liền nét)
                            LineChartBarData(
                              spots: const [
                                FlSpot(1, 150000),
                                FlSpot(5, 620000),
                                FlSpot(10, 1450000),
                                FlSpot(15, 2300000),
                              ],
                              isCurved: true,
                              color: AppColors.secondary,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: true),
                            ),
                            // Dự báo (Đường nét đứt)
                            LineChartBarData(
                              spots: const [
                                FlSpot(15, 2300000),
                                FlSpot(20, 3100000),
                                FlSpot(25, 3850000),
                                FlSpot(30, 4600000),
                              ],
                              isCurved: true,
                              color: AppColors.tertiary,
                              dashArray: [6, 4],
                              barWidth: 2.5,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(width: 14, height: 3, color: AppColors.secondary),
                            const SizedBox(width: 6),
                            Text('Đã chi thực tế', style: AppTypography.caption(context)),
                          ],
                        ),
                        const SizedBox(width: 24),
                        Row(
                          children: [
                            Container(width: 14, height: 3, color: AppColors.tertiary),
                            const SizedBox(width: 6),
                            Text('Dự báo AI (nét đứt)', style: AppTypography.caption(context)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Metrics Cards
              Row(
                children: [
                  Expanded(
                    child: LiquidGlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(LucideIcons.calendarClock, size: 20, color: AppColors.slateAction),
                          const SizedBox(height: 10),
                          Text('Tốc độ chi tiêu/ngày', style: AppTypography.caption(context)),
                          const SizedBox(height: 4),
                          Text(
                            '153.000 ₫',
                            style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LiquidGlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(LucideIcons.shieldCheck, size: 20, color: AppColors.safe),
                          const SizedBox(height: 10),
                          Text('Khả năng thặng dư', style: AppTypography.caption(context)),
                          const SizedBox(height: 4),
                          Text(
                            '+2.400.000 ₫',
                            style: AppTypography.body(context).copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.safe,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
