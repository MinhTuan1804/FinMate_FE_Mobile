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

/// Màn F2: Báo cáo theo danh mục (Category Report Screen)
class CategoryReportScreen extends ConsumerStatefulWidget {
  const CategoryReportScreen({super.key});

  @override
  ConsumerState<CategoryReportScreen> createState() => _CategoryReportScreenState();
}

class _CategoryReportScreenState extends ConsumerState<CategoryReportScreen> {
  int _selectedPeriod = 1; // 0: Tuần, 1: Tháng, 2: Năm
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final breakdownAsync = ref.watch(categoryBreakdownProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cơ cấu theo danh mục'),
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
              // Period selector pill
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLightSubtle.withValues(alpha: 0.7),
                  borderRadius: AppSpacing.roundedPill,
                  border: Border.all(color: AppColors.borderLight, width: 1),
                ),
                child: Row(
                  children: [
                    _periodTab('Tuần này', 0),
                    _periodTab('Tháng này', 1),
                    _periodTab('Năm nay', 2),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              breakdownAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => LiquidGlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(LucideIcons.alertCircle, color: AppColors.danger, size: 36),
                      const SizedBox(height: 12),
                      const Text('Không thể tải dữ liệu danh mục'),
                      TextButton(
                        onPressed: () => ref.invalidate(categoryBreakdownProvider),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
                data: (breakdown) {
                  final items = breakdown.items;
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'Chưa có dữ liệu chi tiêu trong kỳ này.',
                          style: AppTypography.caption(context),
                        ),
                      ),
                    );
                  }

                  final totalSpent = breakdown.totalSpentCents;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Donut Chart Hero
                      ZenvestHeroDeck(
                        peekBadgeText: 'CAT',
                        child: LiquidGlassCard(
                          variant: LiquidGlassVariant.iridescentHero,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                'TỔNG CHI TIÊU',
                                style: AppTypography.caption(context).copyWith(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatVnd(totalSpent),
                                style: AppTypography.displayBalance(context).copyWith(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 190,
                                child: PieChart(
                                  PieChartData(
                                    pieTouchData: PieTouchData(
                                      touchCallback: (event, response) {
                                        setState(() {
                                          if (!event.isInterestedForInteractions ||
                                              response == null ||
                                              response.touchedSection == null) {
                                            _touchedIndex = -1;
                                            return;
                                          }
                                          _touchedIndex = response.touchedSection!.touchedSectionIndex;
                                        });
                                      },
                                    ),
                                    borderData: FlBorderData(show: false),
                                    sectionsSpace: 3,
                                    centerSpaceRadius: 44,
                                    sections: List.generate(items.length, (i) {
                                      final isTouched = i == _touchedIndex;
                                      final fontSize = isTouched ? 14.0 : 11.0;
                                      final radius = isTouched ? 48.0 : 40.0;
                                      final color = AppColors.chartPalette[i % AppColors.chartPalette.length];
                                      final item = items[i];
                                      return PieChartSectionData(
                                        color: color,
                                        value: item.spentCents.toDouble(),
                                        title: '${item.percent.toStringAsFixed(0)}%',
                                        radius: radius,
                                        titleStyle: TextStyle(
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // List of categories
                      ZenvestSurfaceSheet(
                        title: 'Danh sách phân bổ chi tiêu',
                        child: Column(
                          children: [
                            for (var i = 0; i < items.length; i++)
                              Builder(
                                builder: (context) {
                                  final item = items[i];
                                  final color = AppColors.chartPalette[i % AppColors.chartPalette.length];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                item.name,
                                                style: AppTypography.body(context).copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              formatVnd(item.spentCents),
                                              style: AppTypography.tabular(
                                                AppTypography.bodyMedium(context).copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '(${item.percent.toStringAsFixed(1)}%)',
                                              style: AppTypography.caption(context).copyWith(
                                                color: AppColors.textMuted(context),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        LiquidGlassProgressBar(
                                          value: (item.percent / 100).clamp(0.0, 1.0),
                                          color: color,
                                          height: 6,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodTab(String label, int index) {
    final selected = _selectedPeriod == index;
    final activeBg = AppColors.primaryAction(context);
    final activeFg = AppColors.onPrimaryAction(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? activeBg : Colors.transparent,
            borderRadius: AppSpacing.roundedPill,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? activeFg : AppColors.textPrimary(context),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
