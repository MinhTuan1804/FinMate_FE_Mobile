import 'package:fl_chart/fl_chart.dart';
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
import 'package:finmate/features/analytics/domain/report_models.dart';
import 'package:finmate/features/analytics/presentation/reports_providers.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/features/forecast/domain/forecast.dart';
import 'package:finmate/features/forecast/presentation/controllers/forecast_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

final _donutPalette = <Color>[
  GlassColors.accentSkyBlue,
  GlassColors.accentDustyRose,
  GlassColors.accentWarmPeach,
  GlassColors.success,
  GlassColors.slateAnchor,
  GlassColors.warning,
];

/// F2 — Báo cáo danh mục (Luồng 6). Khác bản cũ `analytics_screen.dart` (biểu đồ tròn gộp trong
/// F1): đây là màn riêng, donut chart + list danh mục có trạng thái ngân sách thật (tái dùng
/// [budgetForecastProvider] đã có cho Luồng dự báo, không bịa "vượt/còn lại").
///
/// Nút "Xuất báo cáo PDF" bị disable (sắp có) — chưa có endpoint xuất PDF nào (Stitch vs BE thật).
/// "Thu nhập" trên segmented control dùng `category-breakdown?type=income` (BE đã hỗ trợ).
class F2CategoryReportScreen extends ConsumerStatefulWidget {
  const F2CategoryReportScreen({super.key});

  @override
  ConsumerState<F2CategoryReportScreen> createState() => _F2CategoryReportScreenState();
}

class _F2CategoryReportScreenState extends ConsumerState<F2CategoryReportScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _type = 'expense';

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _changeMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isAfter(DateTime(DateTime.now().year, DateTime.now().month))) return;
    setState(() => _month = next);
  }

  void _notAvailableYet(String what) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what sắp có.')));
  }

  @override
  Widget build(BuildContext context) {
    final ym = (_month.year, _month.month);
    final ymt = (_month.year, _month.month, _type);
    final summaryAsync = ref.watch(monthlySummaryForMonthProvider(ym));
    final breakdownAsync = ref.watch(categoryBreakdownByTypeForMonthProvider(ymt));
    final budgetsAsync = _isCurrentMonth && _type == 'expense'
        ? ref.watch(budgetForecastProvider)
        : const AsyncValue<List<BudgetForecastEntity>>.data([]);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: Icon(LucideIcons.arrowLeft, color: GlassColors.textPrimary), onPressed: () => context.pop()),
          title: Text('Báo cáo danh mục', style: GlassTypography.headlineMd()),
          actions: [_monthPicker(), const SizedBox(width: 8)],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              summaryAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (summary) => _buildTypeToggle(summary),
              ),
              const SizedBox(height: 16),
              breakdownAsync.when(
                loading: () => _loadingCard(),
                error: (e, _) => _errorCard(e, () => ref.invalidate(categoryBreakdownByTypeForMonthProvider(ymt))),
                data: (breakdown) => _buildDonutCard(breakdown, summaryAsync.valueOrNull),
              ),
              const SizedBox(height: 16),
              breakdownAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (breakdown) => _buildCategoryList(breakdown, budgetsAsync.valueOrNull ?? const []),
              ),
              const SizedBox(height: 16),
              _buildAiNote(),
              const SizedBox(height: 16),
              _buildExportButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: GlassColors.glassFill, borderRadius: GlassRadius.roundedPill, border: Border.all(color: GlassColors.glassBorder)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft, size: 18),
            onPressed: () => _changeMonth(-1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Text('Th${_month.month}/${_month.year}', style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
          IconButton(
            icon: const Icon(LucideIcons.chevronRight, size: 18),
            onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle(MonthlySummary summary) {
    Widget pill(String label, BigInt amount, bool active, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: active ? GlassColors.ink : Colors.transparent, borderRadius: GlassRadius.roundedPill),
              child: Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$label  ', style: GlassTypography.bodyMd(color: active ? Colors.white : GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                      TextSpan(text: '(${formatVnd(amount)})', style: GlassTypography.bodySm(color: active ? Colors.white70 : GlassColors.textMuted)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    return GlassCard(
      padding: const EdgeInsets.all(4),
      borderRadius: GlassRadius.roundedPill,
      child: Row(
        children: [
          pill('Chi tiêu', summary.totalSpentCents, _type == 'expense', () => setState(() => _type = 'expense')),
          pill('Thu nhập', summary.totalIncomeCents, _type == 'income', () => setState(() => _type = 'income')),
        ],
      ),
    );
  }

  Widget _buildDonutCard(CategoryBreakdown breakdown, MonthlySummary? summary) {
    final isIncome = _type == 'income';
    final items = [...breakdown.items]..sort((a, b) => b.percent.compareTo(a.percent));
    final daysInPeriod = _isCurrentMonth ? DateTime.now().day : DateTime(_month.year, _month.month + 1, 0).day;
    final change = _isCurrentMonth && !isIncome ? summary?.changePercent : null;
    final prevMonthLabel = DateFormat('MM', 'vi_VN').format(DateTime(_month.year, _month.month - 1));

    return GlassCard(
      level: 2,
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 64,
                    sections: items.isEmpty
                        ? [PieChartSectionData(color: GlassColors.secondarySurface, value: 1, showTitle: false, radius: 32)]
                        : [
                            for (final (i, item) in items.indexed)
                              PieChartSectionData(
                                color: _donutPalette[i % _donutPalette.length],
                                value: item.percent <= 0 ? 0.01 : item.percent,
                                showTitle: false,
                                radius: 32,
                              ),
                          ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isIncome ? 'TỔNG THU' : 'TỔNG CHI', style: GlassTypography.labelCaps()),
                    const SizedBox(height: 4),
                    Text(formatVnd(breakdown.totalSpentCents), style: GlassTypography.displayHero().copyWith(fontSize: 24)),
                    const SizedBox(height: 2),
                    Text('$daysInPeriod ngày qua', style: GlassTypography.bodySm()),
                  ],
                ),
              ],
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 12),
            GlassBadge(
              text: '${change < 0 ? 'Giảm' : 'Tăng'} ${NumberFormat('0.#', 'vi_VN').format(change.abs())}% so với tháng $prevMonthLabel',
              color: change < 0 ? GlassColors.success : GlassColors.danger,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryList(CategoryBreakdown breakdown, List<BudgetForecastEntity> budgets) {
    final isIncome = _type == 'income';
    final items = [...breakdown.items]..sort((a, b) => b.percent.compareTo(a.percent));
    final budgetByCategory = {for (final b in budgets) if (b.categoryId != null) b.categoryId!: b};

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isIncome ? 'Phân loại thu nhập' : 'Phân loại chi tiêu', style: GlassTypography.headlineSm()),
              Text('${items.length} DANH MỤC', style: GlassTypography.labelCaps()),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(isIncome ? 'Chưa có thu nhập trong tháng này.' : 'Chưa có chi tiêu trong tháng này.', style: GlassTypography.bodyMd()),
            )
          else
            for (final (i, item) in items.indexed) ...[
              if (i > 0) Divider(height: 1, color: GlassColors.glassBorder),
              _categoryTile(item, budgetByCategory[item.categoryId]),
            ],
        ],
      ),
    );
  }

  Widget _categoryTile(CategoryShare item, BudgetForecastEntity? budget) {
    String? subline;
    Color? sublineColor;
    if (budget != null) {
      final diff = budget.limitCents - budget.spentCents;
      if (budget.isOver) {
        subline = 'Vượt ngân sách ${formatVnd(diff.abs())}';
        sublineColor = GlassColors.danger;
      } else {
        subline = 'Còn lại ${formatVnd(diff)}';
        sublineColor = GlassColors.success;
      }
    }

    return InkWell(
      // Chưa có màn "giao dịch theo danh mục" riêng — trỏ tạm vào Lịch sử giao dịch (D1) thay vì
      // bịa đường dẫn lọc không tồn tại (cùng cách C3 đã làm khi thiếu màn chi tiết).
      onTap: () => context.push('/transactions'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: GlassColors.secondarySurface, borderRadius: BorderRadius.circular(12)),
              child: Icon(categoryIcon(item.slug), size: 20, color: GlassColors.slateAnchor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                  if (subline != null) ...[
                    const SizedBox(height: 2),
                    Text(subline, style: GlassTypography.bodySm(color: sublineColor!)),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GlassBadge(text: '${item.percent.round()}%', color: GlassColors.slateAnchor),
                const SizedBox(height: 4),
                Text(formatVnd(item.spentCents), style: GlassTypography.labelNumeric()),
              ],
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRight, size: 18, color: GlassColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildAiNote() {
    return ref.watch(spendingInsightsProvider).when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (insights) {
            if (insights.isEmpty) return const SizedBox.shrink();
            final insight = insights.first;
            return GlassCard(
              level: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.sparkles, size: 16, color: GlassColors.slateAnchor),
                      const SizedBox(width: 8),
                      Text('FINMATE AI NHẬN XÉT', style: GlassTypography.labelCaps()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(insight.title, style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(insight.body, style: GlassTypography.bodyMd()),
                ],
              ),
            );
          },
        );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _notAvailableYet('Xuất báo cáo PDF'),
        style: ElevatedButton.styleFrom(
          backgroundColor: GlassColors.ink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
        ),
        icon: const Icon(LucideIcons.download, size: 18),
        label: const Text('Xuất báo cáo chi tiết (PDF)'),
      ),
    );
  }

  Widget _loadingCard() => const GlassCard(child: SizedBox(height: 180, child: Center(child: CircularProgressIndicator())));

  Widget _errorCard(Object error, VoidCallback retry) => GlassCard(
        child: Column(
          children: [
            Text(errorMessage(error), textAlign: TextAlign.center, style: GlassTypography.bodyMd()),
            TextButton(onPressed: retry, child: const Text('Thử lại')),
          ],
        ),
      );
}
