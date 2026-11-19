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
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// Màu từng lát donut (đồng thời là chấm màu trên icon danh mục). Là hàm vì [GlassColors] đổi theo
/// chế độ sáng/tối — không được giữ trong biến toàn cục.
Color _sliceColor(int i) {
  final palette = <Color>[
    GlassColors.accentDustyRose,
    GlassColors.accentWarmPeach,
    GlassColors.accentSkyBlue,
    GlassColors.success,
    GlassColors.textMuted,
    GlassColors.warning,
  ];
  return palette[i % palette.length];
}

/// F2 — Báo cáo danh mục (Luồng 6). Khác bản cũ `analytics_screen.dart` (biểu đồ tròn gộp trong
/// F1): đây là màn riêng, donut chart + list danh mục có trạng thái ngân sách thật (tái dùng
/// [budgetForecastProvider] đã có cho Luồng dự báo, không bịa "vượt/còn lại").
///
/// Nút "Xuất báo cáo PDF" bị khóa kèm nhãn "Sắp có" — chưa có endpoint xuất PDF nào.
/// Không hiện "Tiết kiệm X" và "N giao dịch nhỏ" của Figma: BE không trả dữ liệu tương ứng.
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
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: 'Quay lại',
            icon: Icon(LucideIcons.arrowLeft, color: GlassColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          titleSpacing: 0,
          title: Text('Báo cáo danh mục', style: GlassTypography.headlineMd(), maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [_monthPicker(), const SizedBox(width: 16)],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              _buildTypeToggle(summaryAsync.valueOrNull),
              const SizedBox(height: 16),
              breakdownAsync.when(
                loading: () => _loadingCard(),
                error: (e, _) => _errorCard(e, () => ref.invalidate(categoryBreakdownByTypeForMonthProvider(ymt))),
                data: (breakdown) => _buildDonutCard(breakdown, summaryAsync.valueOrNull),
              ),
              const SizedBox(height: 24),
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

  /// Nút chọn tháng dạng pill (Figma): lịch + "Tháng M/yyyy" + mũi tên; chọn trong 12 tháng gần nhất.
  Widget _monthPicker() {
    final now = DateTime.now();
    final months = [for (var i = 0; i < 12; i++) DateTime(now.year, now.month - i)];
    return PopupMenuButton<DateTime>(
      tooltip: 'Chọn tháng báo cáo',
      initialValue: _month,
      onSelected: (m) => setState(() => _month = m),
      itemBuilder: (_) => [
        for (final m in months) PopupMenuItem(value: m, child: Text('Tháng ${m.month}/${m.year}')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: GlassColors.glassFillModal,
          borderRadius: GlassRadius.roundedPill,
          border: Border.all(color: GlassColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.calendar, size: 16, color: GlassColors.slateAnchor),
            const SizedBox(width: 6),
            Text('Tháng ${_month.month}/${_month.year}', style: GlassTypography.bodySm(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronDown, size: 16, color: GlassColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle(MonthlySummary? summary) {
    Widget pill(String label, BigInt? amount, bool active, VoidCallback onTap) => Expanded(
          child: Semantics(
            button: true,
            selected: active,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(color: active ? GlassColors.ink : Colors.transparent, borderRadius: GlassRadius.roundedPill),
                child: Center(
                  child: Text.rich(
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    TextSpan(
                      children: [
                        TextSpan(text: label, style: GlassTypography.bodyMd(color: active ? GlassColors.onInk : GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                        if (amount != null)
                          TextSpan(text: ' (${formatVnd(amount)})', style: GlassTypography.bodySm(color: active ? GlassColors.onInk.withValues(alpha: 0.85) : GlassColors.textMuted).copyWith(fontSize: 11)),
                      ],
                    ),
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
          pill('Chi tiêu', summary?.totalSpentCents, _type == 'expense', () => setState(() => _type = 'expense')),
          pill('Thu nhập', summary?.totalIncomeCents, _type == 'income', () => setState(() => _type = 'income')),
        ],
      ),
    );
  }

  Widget _buildDonutCard(CategoryBreakdown breakdown, MonthlySummary? summary) {
    final isIncome = _type == 'income';
    final items = [...breakdown.items]..sort((a, b) => b.percent.compareTo(a.percent));
    final daysInPeriod = _isCurrentMonth ? DateTime.now().day : DateTime(_month.year, _month.month + 1, 0).day;
    final change = !isIncome ? summary?.changePercent : null;
    final prevMonth = DateTime(_month.year, _month.month - 1).month;
    final diff = summary == null ? null : summary.totalSpentCents - summary.prevMonthSpentCents;
    final good = change != null && change < 0;
    final tone = good ? GlassColors.success : GlassColors.danger;

    return GlassCard(
      level: 2,
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 78,
                    sections: items.isEmpty
                        ? [PieChartSectionData(color: GlassColors.secondarySurface, value: 1, showTitle: false, radius: 20)]
                        : [
                            for (final (i, item) in items.indexed)
                              PieChartSectionData(
                                color: _sliceColor(i),
                                value: item.percent <= 0 ? 0.01 : item.percent,
                                showTitle: false,
                                radius: 20,
                              ),
                          ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isIncome ? 'TỔNG THU' : 'TỔNG CHI', style: GlassTypography.labelCaps()),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(formatVnd(breakdown.totalSpentCents), style: GlassTypography.displayHero().copyWith(fontSize: 26)),
                      ),
                      const SizedBox(height: 2),
                      Text('$daysInPeriod ngày qua', style: GlassTypography.bodySm()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: GlassColors.glassFillModal,
                borderRadius: GlassRadius.roundedPill,
                border: Border.all(color: GlassColors.glassBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: tone.withValues(alpha: 0.14), shape: BoxShape.circle),
                    child: Icon(good ? LucideIcons.arrowDown : LucideIcons.arrowUp, size: 12, color: tone),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        style: GlassTypography.bodySm(color: GlassColors.textSecondary),
                        children: [
                          TextSpan(text: good ? 'Giảm ' : 'Tăng '),
                          TextSpan(
                            text: '${NumberFormat('0.#', 'vi_VN').format(change.abs())}%',
                            style: TextStyle(color: tone, fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: ' so với tháng $prevMonth'),
                          if (diff != null) TextSpan(text: ' (${diff < BigInt.zero ? '' : '+'}${formatVnd(diff)})'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(child: Text(isIncome ? 'Phân loại thu nhập' : 'Phân loại chi tiêu', style: GlassTypography.headlineMd())),
              const SizedBox(width: 8),
              Text('${items.length} DANH MỤC', style: GlassTypography.labelCaps()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          GlassCard(
            child: SizedBox(
              width: double.infinity,
              child: Text(isIncome ? 'Chưa có thu nhập trong tháng này.' : 'Chưa có chi tiêu trong tháng này.', style: GlassTypography.bodyMd()),
            ),
          )
        else
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            _categoryTile(item, i, budgetByCategory[item.categoryId]),
          ],
      ],
    );
  }

  Widget _categoryTile(CategoryShare item, int index, BudgetForecastEntity? budget) {
    String? subline;
    Color? sublineColor;
    IconData? sublineIcon;
    if (budget != null) {
      final diff = budget.limitCents - budget.spentCents;
      if (budget.isOver) {
        subline = 'Vượt ngân sách ${formatVnd(diff.abs())}';
        sublineColor = GlassColors.danger;
        sublineIcon = LucideIcons.circleAlert;
      } else {
        subline = 'Còn lại ${formatVnd(diff)}';
        sublineColor = GlassColors.textMuted;
      }
    }
    final color = _sliceColor(index);

    return Semantics(
      button: true,
      label: '${item.name}, ${item.percent.round()}%, ${formatVnd(item.spentCents)}',
      child: GestureDetector(
        // Chưa có màn "giao dịch theo danh mục" riêng — trỏ tạm vào Lịch sử giao dịch (D1) thay vì
        // bịa đường dẫn lọc không tồn tại (cùng cách C3 đã làm khi thiếu màn chi tiết).
        onTap: () => context.push('/transactions'),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Icon(categoryIcon(item.slug), size: 22, color: GlassColors.textPrimary),
                    ),
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: GlassColors.glassFillModal, width: 2)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.25), borderRadius: GlassRadius.roundedPill),
                          child: Text('${NumberFormat('0.#', 'vi_VN').format(item.percent)}%', style: GlassTypography.labelCaps(color: GlassColors.textPrimary).copyWith(fontSize: 11)),
                        ),
                      ],
                    ),
                    if (subline != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (sublineIcon != null) ...[Icon(sublineIcon, size: 13, color: sublineColor), const SizedBox(width: 4)],
                          Flexible(child: Text(subline, style: GlassTypography.bodySm(color: sublineColor!))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(formatVnd(item.spentCents), style: GlassTypography.labelNumeric()),
              const SizedBox(width: 2),
              Icon(LucideIcons.chevronRight, size: 18, color: GlassColors.textMuted),
            ],
          ),
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
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: GlassColors.ink, shape: BoxShape.circle),
                    child: Icon(LucideIcons.sparkles, size: 18, color: GlassColors.onInk),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FINMATE AI NHẬN XÉT', style: GlassTypography.labelCaps(color: GlassColors.slateAnchor)),
                        const SizedBox(height: 6),
                        Text(insight.title, style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(insight.body, style: GlassTypography.bodyMd()),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
  }

  /// Chưa có API xuất PDF: nút khóa kèm nhãn "Sắp có", không giả vờ chạy.
  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: GlassColors.secondarySurface,
          disabledForegroundColor: GlassColors.textMuted,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
        ),
        icon: const Icon(LucideIcons.download, size: 18),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text('Xuất báo cáo chi tiết (PDF) · Sắp có', textAlign: TextAlign.center, style: GlassTypography.buttonText(color: GlassColors.textMuted), maxLines: 1)),
      ),
    );
  }

  Widget _loadingCard() => const GlassCard(child: SizedBox(height: 180, child: Center(child: CircularProgressIndicator())));

  Widget _errorCard(Object error, VoidCallback retry) => GlassCard(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Text(errorMessage(error), textAlign: TextAlign.center, style: GlassTypography.bodyMd()),
              TextButton(onPressed: retry, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
}
