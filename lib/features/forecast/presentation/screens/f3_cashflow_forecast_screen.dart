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
import 'package:finmate/features/forecast/data/forecast_repository.dart';
import 'package:finmate/features/forecast/domain/forecast.dart';
import 'package:finmate/features/forecast/presentation/controllers/forecast_controller.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

enum _Horizon { days30, days60, quarter }

const _confidenceLabel = {'high': 'Độ tin cậy cao', 'medium': 'Độ tin cậy trung bình', 'low': 'Độ tin cậy thấp'};

/// F3 — Dự báo dòng tiền (Luồng 6). Dùng thẳng [cashflowForecastProvider] (`GET /forecast/cashflow`,
/// đã có sẵn cho tính năng Dự báo). Khác Stitch 2 điểm có chủ đích:
/// 1. Biểu đồ Stitch vẽ "thực tế + mô phỏng AI" 2 đoạn, nhưng BE chỉ dự báo TỪ HÔM NAY trở đi (không
///    trả dữ liệu lịch sử) — vẽ 1 đường dự báo thật + dải thận trọng/lạc quan thay vì bịa đoạn "thực
///    tế" không có thật.
/// 2. Khối "Mô phỏng áp lực dòng tiền" trong Stitch lặp lại y hệt 5 lần — rõ ràng là placeholder
///    Figma chưa hoàn thiện, không phải thiết kế thật — nên thay bằng [CashflowForecastEntity.mainCauses]
///    thật (tối đa 3 nguyên nhân chính khiến số dư thay đổi, BE đã tính sẵn).
class F3CashflowForecastScreen extends ConsumerStatefulWidget {
  const F3CashflowForecastScreen({super.key});

  @override
  ConsumerState<F3CashflowForecastScreen> createState() => _F3CashflowForecastScreenState();
}

class _F3CashflowForecastScreenState extends ConsumerState<F3CashflowForecastScreen> {
  _Horizon _horizon = _Horizon.days30;

  DateTime get _to {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_horizon) {
      _Horizon.days30 => today.add(const Duration(days: 30)),
      _Horizon.days60 => today.add(const Duration(days: 60)),
      _Horizon.quarter => DateTime((now.month <= 9) ? now.year : now.year, ((now.month - 1) ~/ 3 + 1) * 3 + 1, 0),
    };
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_cashflowForHorizonProvider(_to));

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: Icon(LucideIcons.arrowLeft, color: GlassColors.textPrimary), onPressed: () => context.pop()),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dự báo dòng tiền', style: GlassTypography.headlineMd()),
              Text('FinMate Intelligence', style: GlassTypography.bodySm()),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(LucideIcons.gauge, color: GlassColors.textPrimary),
              tooltip: 'Xem chi tiết dự báo nâng cao',
              onPressed: () => context.push('/forecast'),
            ),
          ],
        ),
        body: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorMessage(e), textAlign: TextAlign.center, style: GlassTypography.bodyMd()),
                    TextButton(onPressed: () => ref.invalidate(_cashflowForHorizonProvider(_to)), child: const Text('Thử lại')),
                  ],
                ),
              ),
            ),
            data: (forecast) => _buildContent(forecast),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(CashflowForecastEntity forecast) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        _buildHorizonPills(),
        const SizedBox(height: 16),
        _buildSummaryCard(forecast),
        const SizedBox(height: 16),
        _buildChartCard(forecast),
        const SizedBox(height: 16),
        if (forecast.mainCauses.isNotEmpty) ...[
          Text('Các yếu tố ảnh hưởng dòng tiền', style: GlassTypography.headlineSm()),
          const SizedBox(height: 10),
          for (final cause in forecast.mainCauses) ...[_causeRow(cause), const SizedBox(height: 10)],
          const SizedBox(height: 6),
        ],
        _buildScenarioButton(),
        const SizedBox(height: 10),
        _buildAiSummaryLink(),
      ],
    );
  }

  Widget _buildHorizonPills() {
    Widget pill(String label, _Horizon value) {
      final selected = _horizon == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _horizon = value),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: selected ? GlassColors.ink : Colors.transparent, borderRadius: GlassRadius.roundedPill),
            child: Center(
              child: Text(label, style: GlassTypography.bodyMd(color: selected ? Colors.white : GlassColors.textMuted).copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
            ),
          ),
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(4),
      borderRadius: GlassRadius.roundedPill,
      child: Row(
        children: [
          pill('30 ngày tới', _Horizon.days30),
          pill('60 ngày tới', _Horizon.days60),
          pill('Hết quý này', _Horizon.quarter),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(CashflowForecastEntity forecast) {
    return GlassCard(
      level: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [Icon(LucideIcons.sparkles, size: 14, color: GlassColors.slateAnchor), const SizedBox(width: 6), Text('MÔ HÌNH AI DỰ BÁO DÒNG TIỀN', style: GlassTypography.labelCaps())]),
              GlassBadge(text: _confidenceLabel[forecast.confidence] ?? forecast.confidence, color: forecast.confidence == 'high' ? GlassColors.success : GlassColors.warning),
            ],
          ),
          const SizedBox(height: 10),
          Text('Dự kiến số dư cuối kỳ', style: GlassTypography.bodyMd()),
          const SizedBox(height: 2),
          Text(formatVnd(forecast.endBalanceCents), style: GlassTypography.displayHero()),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  icon: LucideIcons.trendingDown,
                  color: GlassColors.danger,
                  label: 'Thấp nhất dự kiến',
                  value: '${formatVnd(forecast.lowestBalanceCents)} (${DateFormat('dd/MM').format(forecast.lowestDay)})',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniStat(icon: LucideIcons.waves, color: GlassColors.accentSkyBlue, label: 'Số dư hiện tại', value: formatVnd(forecast.startBalanceCents)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat({required IconData icon, required Color color, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: GlassColors.secondarySurface, borderRadius: GlassRadius.roundedInput),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(label, style: GlassTypography.bodySm()),
          const SizedBox(height: 2),
          Text(value, style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildChartCard(CashflowForecastEntity forecast) {
    final days = forecast.days;
    if (days.isEmpty) {
      return GlassCard(child: Text('Chưa đủ dữ liệu để vẽ biểu đồ dòng tiền.', style: GlassTypography.bodyMd()));
    }

    final spots = <FlSpot>[for (final (i, d) in days.indexed) FlSpot(i.toDouble(), d.expectedBalanceCents.toInt().toDouble())];
    final lowSpots = <FlSpot>[for (final (i, d) in days.indexed) FlSpot(i.toDouble(), d.lowBalanceCents.toInt().toDouble())];
    final highSpots = <FlSpot>[for (final (i, d) in days.indexed) FlSpot(i.toDouble(), d.highBalanceCents.toInt().toDouble())];

    // Chú thích điểm thật: ngày có khoản phát sinh lớn nhất (không bịa sự kiện như mockup).
    var biggestIndex = -1;
    var biggestAmount = BigInt.zero;
    String biggestLabel = '';
    for (final (i, d) in days.indexed) {
      for (final e in d.events) {
        if (e.amountCents.abs() > biggestAmount) {
          biggestAmount = e.amountCents.abs();
          biggestIndex = i;
          biggestLabel = '${DateFormat('dd/MM').format(d.date)}: ${e.label} (${formatVnd(e.amountCents)})';
        }
      }
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Xu hướng số dư dự kiến', style: GlassTypography.headlineSm()),
          const SizedBox(height: 2),
          Text('Dải mờ: khoảng thận trọng – lạc quan theo AI', style: GlassTypography.bodySm()),
          if (biggestIndex >= 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: GlassColors.ink, borderRadius: GlassRadius.roundedPill),
              child: Text(biggestLabel, style: GlassTypography.bodySm(color: Colors.white)),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: (days.length / 4).clamp(1, days.length).toDouble(),
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= days.length) return const SizedBox.shrink();
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(DateFormat('dd/MM').format(days[i].date), style: GlassTypography.bodySm()));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(spots: highSpots, isCurved: true, color: GlassColors.accentSkyBlue.withValues(alpha: 0.25), barWidth: 0, dotData: const FlDotData(show: false)),
                  LineChartBarData(spots: lowSpots, isCurved: true, color: GlassColors.accentSkyBlue.withValues(alpha: 0.25), barWidth: 0, dotData: const FlDotData(show: false)),
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: GlassColors.slateAnchor,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, _) => spot.x.round() == biggestIndex,
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 5, color: GlassColors.danger, strokeWidth: 2, strokeColor: Colors.white),
                    ),
                    belowBarData: BarAreaData(show: true, color: GlassColors.accentSkyBlue.withValues(alpha: 0.12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _causeRow(CashflowCauseEntity cause) {
    final isInflow = cause.amountCents >= BigInt.zero;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(isInflow ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight, size: 18, color: isInflow ? GlassColors.success : GlassColors.danger),
          const SizedBox(width: 12),
          Expanded(child: Text(cause.label, style: GlassTypography.bodyMd(color: GlassColors.textPrimary))),
          Text(cause.formattedAmount, style: GlassTypography.labelNumeric(color: isInflow ? GlassColors.success : GlassColors.danger)),
        ],
      ),
    );
  }

  // Đúng sơ đồ điều hướng F3→F6 (roadmap) — Stitch F3 không vẽ nút này, thêm theo rule "bổ sung
  // nút điều hướng còn thiếu".
  Widget _buildAiSummaryLink() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => context.push('/analytics/insights'),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: GlassColors.glassBorder), shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill)),
        icon: Icon(LucideIcons.sparkles, size: 18, color: GlassColors.textPrimary),
        label: Text('Xem nhận xét AI & báo cáo tháng', style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildScenarioButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _openScenarioSheet(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: GlassColors.ink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
        ),
        icon: const Icon(LucideIcons.slidersHorizontal, size: 18),
        label: const Text('Tùy chỉnh kịch bản thu chi'),
      ),
    );
  }

  Future<void> _openScenarioSheet(BuildContext context) async {
    final amountController = TextEditingController();
    final labelController = TextEditingController();
    var direction = RecurringDirection.outflow;
    var date = DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: BoxDecoration(color: GlassColors.glassFillModal, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thử một khoản thu/chi giả định', style: GlassTypography.headlineSm()),
                const SizedBox(height: 4),
                Text('Không lưu gì — chỉ xem số dư cuối kỳ thay đổi thế nào nếu khoản này xảy ra.', style: GlassTypography.bodySm()),
                const SizedBox(height: 16),
                TextField(
                  controller: labelController,
                  decoration: InputDecoration(hintText: 'Mô tả (vd: Sửa xe máy)', filled: true, fillColor: GlassColors.secondarySurface, border: OutlineInputBorder(borderRadius: GlassRadius.roundedInput, borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  decoration: InputDecoration(hintText: 'Số tiền', suffixText: 'đ', filled: true, fillColor: GlassColors.secondarySurface, border: OutlineInputBorder(borderRadius: GlassRadius.roundedInput, borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final d in RecurringDirection.values)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(d.label),
                            selected: direction == d,
                            onSelected: (_) => setSheetState(() => direction = d),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = parseAmountInput(amountController.text);
                      if (amount == null) return;
                      final navigator = Navigator.of(sheetContext);
                      final repo = ref.read(forecastRepositoryProvider);
                      try {
                        final result = await repo.runScenario(items: [
                          ScenarioItemInput(date: date, amountCents: amount, direction: direction, label: labelController.text.trim().isEmpty ? null : labelController.text.trim()),
                        ]);
                        navigator.pop();
                        if (!mounted) return;
                        _showScenarioResult(result);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: GlassColors.ink, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill)),
                    child: const Text('Xem kết quả'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showScenarioResult(CashflowForecastEntity result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GlassColors.glassFillModal,
        title: Text('Số dư cuối kỳ nếu xảy ra', style: GlassTypography.headlineSm()),
        content: Text(formatVnd(result.endBalanceCents), style: GlassTypography.displayHero()),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Đóng'))],
      ),
    );
  }
}

final _cashflowForHorizonProvider = FutureProvider.autoDispose.family<CashflowForecastEntity, DateTime>(
  (ref, to) => ref.watch(forecastRepositoryProvider).getCashflow(to: to),
);
