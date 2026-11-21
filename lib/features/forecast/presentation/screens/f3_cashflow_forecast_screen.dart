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
import 'package:finmate/core/widgets/async_action_builder.dart';

enum _Horizon { days30, days60, quarter }

// BE trả 'normal' | 'low' (cùng từ vựng với các màn dự báo khác); 'high'/'medium' giữ lại cho tương thích.
const _confidenceLabel = {'high': 'Độ tin cậy cao', 'medium': 'Độ tin cậy trung bình', 'normal': 'Độ tin cậy bình thường', 'low': 'Độ tin cậy thấp'};

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
  _ScenarioRun? _scenario;

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
        const SizedBox(height: 12),
        _buildBalanceFacts(forecast),
        const SizedBox(height: 16),
        if (forecast.mainCauses.isNotEmpty) ...[
          Text('Mô phỏng áp lực dòng tiền', style: GlassTypography.headlineSm()),
          const SizedBox(height: 10),
          for (final (i, cause) in forecast.mainCauses.indexed) ...[_CauseTile(cause: cause, events: _eventsOf(forecast, cause), initiallyOpen: i == 0), const SizedBox(height: 10)],
          const SizedBox(height: 6),
        ],
        if (_scenario != null) ...[_buildScenarioCard(forecast, _scenario!), const SizedBox(height: 16)],
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
              child: Text(label, style: GlassTypography.bodyMd(color: selected ? GlassColors.onInk : GlassColors.textMuted).copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
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

  /// Thu/Chi dự kiến thật: thu = các khoản có dấu dương trong events; chi = các khoản âm + chi tiêu hằng ngày
  /// (flexibleSpendCents, BE không đưa vào events). Cộng lại khớp với số dư cuối kỳ.
  (BigInt, BigInt) _inflowOutflow(CashflowForecastEntity f) {
    var inflow = BigInt.zero;
    var outflow = BigInt.zero;
    for (final d in f.days) {
      outflow += d.flexibleSpendCents.abs();
      for (final e in d.events) {
        if (e.amountCents > BigInt.zero) {
          inflow += e.amountCents;
        } else {
          outflow += e.amountCents.abs();
        }
      }
    }
    return (inflow, outflow);
  }

  List<(DateTime, CashflowEventEntity)> _eventsOf(CashflowForecastEntity f, CashflowCauseEntity cause) => [
        for (final d in f.days)
          for (final e in d.events)
            if (e.label == cause.label) (d.date, e),
      ];

  String _signedPercent(double v) => '${v >= 0 ? '+' : '-'}${v.abs().toStringAsFixed(1).replaceAll('.', ',')}%';

  Widget _buildSummaryCard(CashflowForecastEntity forecast) {
    final (inflow, outflow) = _inflowOutflow(forecast);
    // % thay đổi số dư cuối kỳ so với hiện tại — chỉ tính khi số dư hiện tại dương (tránh chia cho 0/âm)
    final change = forecast.startBalanceCents > BigInt.zero ? (forecast.endBalanceCents - forecast.startBalanceCents).toDouble() / forecast.startBalanceCents.toDouble() * 100 : null;
    return GlassCard(
      level: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrap: tiêu đề dài và nhãn độ tin cậy tự xuống dòng khi hẹp thay vì tràn phải
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.sparkles, size: 14, color: GlassColors.slateAnchor), const SizedBox(width: 6), Flexible(child: Text('MÔ HÌNH AI DỰ BÁO DÒNG TIỀN', maxLines: 2, overflow: TextOverflow.ellipsis, style: GlassTypography.labelCaps()))]),
              GlassBadge(text: _confidenceLabel[forecast.confidence] ?? forecast.confidence, color: forecast.confidence == 'high' ? GlassColors.success : GlassColors.warning),
              if (change != null) GlassBadge(text: '${_signedPercent(change)} so với hiện tại', color: change >= 0 ? GlassColors.success : GlassColors.danger),
            ],
          ),
          const SizedBox(height: 10),
          Text('Dự kiến số dư cuối kỳ', style: GlassTypography.bodyMd()),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(formatVnd(forecast.endBalanceCents), maxLines: 1, style: GlassTypography.displayHero())),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _miniStat(icon: LucideIcons.arrowUp, color: GlassColors.success, label: 'Thu dự kiến', value: '+${formatVnd(inflow)}')),
              const SizedBox(width: 10),
              Expanded(child: _miniStat(icon: LucideIcons.arrowDown, color: GlassColors.danger, label: 'Chi dự kiến', value: '-${formatVnd(outflow)}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceFacts(CashflowForecastEntity forecast) {
    return Row(
      children: [
        Expanded(
          child: _miniStat(icon: LucideIcons.trendingDown, color: GlassColors.danger, label: 'Thấp nhất dự kiến', value: formatVnd(forecast.lowestBalanceCents), note: 'Ngày ${DateFormat('dd/MM').format(forecast.lowestDay)}'),
        ),
        const SizedBox(width: 10),
        Expanded(child: _miniStat(icon: LucideIcons.waves, color: GlassColors.accentSkyBlue, label: 'Số dư hiện tại', value: formatVnd(forecast.startBalanceCents))),
      ],
    );
  }

  /// Ô số liệu nhỏ: nhãn một dòng, số tiền một dòng (tự co nếu hẹp), ghi chú phụ (ví dụ ngày) ở dòng riêng.
  /// Luôn có dòng ghi chú (rỗng nếu không có) để hai ô cạnh nhau cao bằng nhau.
  Widget _miniStat({required IconData icon, required Color color, required String label, required String value, String? note}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: GlassColors.secondarySurface, borderRadius: GlassRadius.roundedInput),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon và nhãn cùng một hàng (trước đây icon chiếm riêng một dòng phía trên).
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GlassTypography.bodySm())),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w700)),
          ),
          Text(note ?? ' ', maxLines: 1, overflow: TextOverflow.ellipsis, style: GlassTypography.bodySm()),
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
          const SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            CustomPaint(size: const Size(24, 2), painter: _DashPainter(GlassColors.slateAnchor)),
            const SizedBox(width: 8),
            Flexible(child: Text('Dự báo AI từ ${DateFormat('dd/MM').format(days.first.date)} – ${DateFormat('dd/MM').format(days.last.date)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GlassTypography.bodySm())),
          ]),
          if (biggestIndex >= 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: GlassColors.ink, borderRadius: GlassRadius.roundedPill),
              child: Text(biggestLabel, style: GlassTypography.bodySm(color: GlassColors.onInk)),
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
                // Chỉ đường số dư dự kiến (bar 2) có tooltip: ngày + số tiền VNĐ. Hai dải mờ không hiện số thô nữa.
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => GlassColors.ink,
                    tooltipRoundedRadius: 12,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    fitInsideHorizontally: true,
                    getTooltipItems: (touched) => [
                      for (final s in touched)
                        if (s.barIndex != 2)
                          null
                        else
                          LineTooltipItem(
                            '${DateFormat('dd/MM').format(days[s.x.round().clamp(0, days.length - 1)].date)}\n',
                            GlassTypography.bodySm(color: GlassColors.onInk.withValues(alpha: 0.75)),
                            children: [
                              TextSpan(
                                text: formatVnd(BigInt.from(s.y.round())),
                                style: GlassTypography.bodyMd(color: GlassColors.onInk).copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                    ],
                  ),
                  getTouchedSpotIndicator: (bar, indexes) => [
                    for (final _ in indexes)
                      bar.barWidth == 0
                          ? null
                          : TouchedSpotIndicatorData(
                              FlLine(color: GlassColors.slateAnchor.withValues(alpha: 0.4), strokeWidth: 1.5),
                              const FlDotData(show: true),
                            ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(spots: highSpots, isCurved: true, color: GlassColors.accentSkyBlue.withValues(alpha: 0.25), barWidth: 0, dotData: const FlDotData(show: false)),
                  LineChartBarData(spots: lowSpots, isCurved: true, color: GlassColors.accentSkyBlue.withValues(alpha: 0.25), barWidth: 0, dotData: const FlDotData(show: false)),
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: GlassColors.slateAnchor,
                    barWidth: 3,
                    dashArray: [8, 5],
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

  // Đúng sơ đồ điều hướng F3→F6 (roadmap) — Stitch F3 không vẽ nút này, thêm theo rule "bổ sung
  // nút điều hướng còn thiếu".
  Widget _buildAiSummaryLink() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => context.push('/analytics/insights'),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: GlassColors.glassBorder), shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill)),
        icon: Icon(LucideIcons.sparkles, size: 18, color: GlassColors.textPrimary),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text('Xem nhận xét AI & báo cáo tháng', style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600), maxLines: 1)),
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
          foregroundColor: GlassColors.onInk,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
        ),
        icon: const Icon(LucideIcons.slidersHorizontal, size: 18),
        label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Tùy chỉnh kịch bản thu chi', maxLines: 1)),
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
          // GlassCard có BackdropFilter làm mờ nội dung phía sau; chỉ tô màu trong suốt thì chữ của màn dưới xuyên qua sheet.
          child: GlassCard(
            level: 3,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                            label: Text(d.label, style: TextStyle(color: direction == d ? GlassColors.activeFg : GlassColors.textSecondary, fontWeight: FontWeight.w600)),
                            selectedColor: GlassColors.activeFill,
                            showCheckmark: false,
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
                  child: AsyncActionBuilder(
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
                        setState(() => _scenario = _ScenarioRun(label: labelController.text.trim(), amount: amount, direction: direction, date: date, result: result));
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
                      }
                    },
                    builder: (_, onTap, running) => ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(backgroundColor: GlassColors.ink, foregroundColor: GlassColors.onInk, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill)),
                      child: running ? const ButtonLoadingIndicator() : const Text('Xem kết quả'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScenarioCard(CashflowForecastEntity base, _ScenarioRun run) {
    final isIn = run.direction == RecurringDirection.inflow;
    final name = run.label.isEmpty ? (isIn ? 'khoản thu giả định' : 'khoản chi giả định') : run.label;
    final end = run.result.endBalanceCents;
    // Thanh = số dư cuối kỳ sau kịch bản so với dự báo gốc (chỉ vẽ khi gốc dương)
    final ratio = base.endBalanceCents > BigInt.zero ? (end.toDouble() / base.endBalanceCents.toDouble()).clamp(0.0, 1.0) : null;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: GlassColors.accentSkyBlue.withValues(alpha: 0.25), shape: BoxShape.circle),
              child: Icon(LucideIcons.sparkles, size: 18, color: GlassColors.slateAnchor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Kịch bản giả định', style: GlassTypography.headlineSm())),
          ]),
          const SizedBox(height: 12),
          Text('${isIn ? 'Thu thêm' : 'Chi thêm'} ${formatVnd(run.amount)} ($name) ngày ${DateFormat('dd/MM').format(run.date)}: số dư cuối kỳ còn ${formatVnd(end)}, thấp nhất ${formatVnd(run.result.lowestBalanceCents)} ngày ${DateFormat('dd/MM').format(run.result.lowestDay)}.', style: GlassTypography.bodyMd()),
          if (ratio != null) ...[
            const SizedBox(height: 12),
            Semantics(
              label: 'Số dư cuối kỳ sau kịch bản bằng ${(ratio * 100).round()}% dự báo gốc',
              child: ClipRRect(borderRadius: GlassRadius.roundedPill, child: LinearProgressIndicator(value: ratio, minHeight: 6, color: GlassColors.slateAnchor, backgroundColor: GlassColors.secondarySurface)),
            ),
            const SizedBox(height: 4),
            Text('So với dự báo gốc ${formatVnd(base.endBalanceCents)}', style: GlassTypography.bodySm()),
          ],
        ],
      ),
    );
  }
}

class _ScenarioRun {
  final String label;
  final BigInt amount;
  final RecurringDirection direction;
  final DateTime date;
  final CashflowForecastEntity result;
  const _ScenarioRun({required this.label, required this.amount, required this.direction, required this.date, required this.result});
}

/// Thẻ nguyên nhân chính; mở ra thấy các khoản phát sinh thật cùng tên trong kỳ (nếu có).
class _CauseTile extends StatefulWidget {
  final CashflowCauseEntity cause;
  final List<(DateTime, CashflowEventEntity)> events;
  final bool initiallyOpen;
  const _CauseTile({required this.cause, required this.events, required this.initiallyOpen});

  @override
  State<_CauseTile> createState() => _CauseTileState();
}

class _CauseTileState extends State<_CauseTile> {
  late bool _open = widget.initiallyOpen && widget.events.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final cause = widget.cause;
    final isInflow = cause.amountCents >= BigInt.zero;
    final color = isInflow ? GlassColors.success : GlassColors.danger;
    final canOpen = widget.events.isNotEmpty;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: canOpen,
            expanded: canOpen ? _open : null,
            child: InkWell(
              onTap: canOpen ? () => setState(() => _open = !_open) : null,
              child: Row(
                children: [
                  Icon(isInflow ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight, size: 18, color: color),
                  const SizedBox(width: 12),
                  Expanded(child: Text(cause.label, style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600))),
                  const SizedBox(width: 8),
                  Text(cause.formattedAmount, style: GlassTypography.labelNumeric(color: color)),
                  if (canOpen) ...[const SizedBox(width: 6), Icon(_open ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 16, color: GlassColors.textMuted)],
                ],
              ),
            ),
          ),
          if (_open)
            Container(
              margin: const EdgeInsets.only(top: 10, left: 8),
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: GlassColors.accentSkyBlue, width: 2))),
              child: Column(
                children: [
                  for (final (date, e) in widget.events)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Text(DateFormat('dd/MM').format(date), style: GlassTypography.bodySm()),
                        const SizedBox(width: 10),
                        Expanded(child: Text(e.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GlassTypography.bodyMd(color: GlassColors.textPrimary))),
                        const SizedBox(width: 8),
                        Text(formatVnd(e.amountCents), style: GlassTypography.bodySm(color: GlassColors.textSecondary)),
                      ]),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Nét đứt mẫu cho chú thích "Dự báo AI".
class _DashPainter extends CustomPainter {
  final Color color;
  const _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, size.height / 2), Offset((x + 5).clamp(0, size.width), size.height / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

final _cashflowForHorizonProvider = FutureProvider.autoDispose.family<CashflowForecastEntity, DateTime>(
  (ref, to) => ref.watch(forecastRepositoryProvider).getCashflow(to: to),
);
