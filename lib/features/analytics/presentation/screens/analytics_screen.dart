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
import 'package:finmate/features/analytics/data/reports_repository.dart';
import 'package:finmate/features/analytics/domain/report_models.dart';
import 'package:finmate/features/analytics/presentation/reports_providers.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_bottom_nav.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_progress_bar.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

enum _Period { day, week, month, year }

/// F1 — Tổng quan phân tích (Luồng 6, tab "Phân tích"). 2 thẻ Thu nhập/Chi tiêu đổi theo tab
/// Ngày/Tuần/Tháng/Năm: Tháng dùng `/reports/monthly-summary` (có sẵn %thay đổi so tháng trước),
/// Ngày/Tuần/Năm cộng dồn qua `/reports/timeline` (không có %thay đổi — BE chưa có kỳ trước để so).
///
/// Thêm 3 lối vào F3 (Dự báo dòng tiền)/F4 (Cảnh báo & bất thường)/F5 (Kiểm tra mua sắm) mà Stitch
/// F1 không vẽ — roadmap `F1 → [F2|F3→F6|F4|F5]` yêu cầu cả 4 nhánh, nên bổ sung hàng "Công cụ
/// phân tích" thay vì chỉ làm đúng mockup (không có nút nào khác trỏ tới các màn này).
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  _Period _period = _Period.month;

  /// Khoảng ngày (local, bao gồm 2 đầu) cho tab hiện tại — null khi [_period] là tháng (dùng
  /// monthly-summary thay vì timeline).
  DateRange? get _range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _Period.day:
        return (
          today,
          today.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
        );
      case _Period.week:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        final sunday = monday.add(
          const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
        );
        return (monday, sunday);
      case _Period.year:
        return (DateTime(now.year), DateTime(now.year, 12, 31, 23, 59, 59));
      case _Period.month:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Theo Figma F1: thanh header riêng (nền sáng hơn nền trang, viền dưới) cố định ở trên, nội dung cuộn bên dưới
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildHeaderBar(context, user?.displayName),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(monthlySummaryProvider);
                    final range = _range;
                    if (range != null) {
                      ref.invalidate(periodSummaryProvider(range));
                    }
                    ref.invalidate(dailySpendingProvider(_chartRange));
                    ref.invalidate(categoryBreakdownProvider);
                    ref.invalidate(forecastProvider);
                    ref.invalidate(spendingInsightsProvider);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    children: [
                      Text(
                        'TỔNG QUAN TÀI CHÍNH',
                        style: GlassTypography.labelCaps(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Phân tích tài chính',
                        style: GlassTypography.headlineLg(),
                      ),
                      const SizedBox(height: 16),
                      _buildPeriodSelector(context),
                      const SizedBox(height: 16),
                      _buildStatCards(context, ref),
                      const SizedBox(height: 16),
                      _buildSpendingDetailCard(context, ref),
                      const SizedBox(height: 16),
                      _buildTools(context),
                      const SizedBox(height: 16),
                      _buildBreakdownCard(context, ref),
                      const SizedBox(height: 16),
                      _buildAiInsightCard(context, ref),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: GlassBottomNav(
          currentIndex: 3,
          onDestinationSelected: (idx) => _onNavSelected(context, idx),
        ),
      ),
    );
  }

  void _onNavSelected(BuildContext context, int idx) {
    switch (idx) {
      case 0:
        context.go('/home');
      case 1:
        context.push('/transactions');
      case -1:
        context.push('/qr-transfers/scan');
      case 2:
        context.push('/planning');
      case 3:
        break; // đang ở Phân tích
    }
  }

  /// Thanh header cố định: phủ lên tận mép trên (sau thanh trạng thái), nền sáng hơn nền trang và đường viền mảnh phía dưới.
  Widget _buildHeaderBar(BuildContext context, String? displayName) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 8,
        12,
        8,
      ),
      decoration: BoxDecoration(
        color: GlassColors.glassFillModal,
        border: Border(bottom: BorderSide(color: GlassColors.glassBorder)),
      ),
      child: _buildHeader(context, displayName),
    );
  }

  Widget _buildHeader(BuildContext context, String? displayName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Xin chào,', style: GlassTypography.bodyMd()),
            const SizedBox(height: 2),
            Text(
              displayName ?? 'Bạn của FinMate',
              style: GlassTypography.headlineMd(),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(
                LucideIcons.bell,
                size: 22,
                color: GlassColors.textPrimary,
              ),
              onPressed: () => context.push('/notifications'),
            ),
            IconButton(
              icon: Icon(
                LucideIcons.circleUser,
                size: 24,
                color: GlassColors.textPrimary,
              ),
              onPressed: () => context.push('/profile'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    Widget pill(String label, _Period period) {
      final selected = period == _period;
      return Expanded(
        child: GestureDetector(
          onTap: selected ? null : () => setState(() => _period = period),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? GlassColors.ink : Colors.transparent,
              borderRadius: GlassRadius.roundedPill,
            ),
            child: Center(
              child: Text(
                label,
                style:
                    GlassTypography.bodyMd(
                      color: selected
                          ? GlassColors.onInk
                          : GlassColors.textMuted,
                    ).copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
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
          pill('Ngày', _Period.day),
          pill('Tuần', _Period.week),
          pill('Tháng', _Period.month),
          pill('Năm', _Period.year),
        ],
      ),
    );
  }

  Widget _buildStatCards(BuildContext context, WidgetRef ref) {
    final range = _range;
    final summaryAsync = range == null
        ? ref.watch(monthlySummaryProvider)
        : ref.watch(periodSummaryProvider(range));
    void retry() => range == null
        ? ref.invalidate(monthlySummaryProvider)
        : ref.invalidate(periodSummaryProvider(range));

    return summaryAsync.when(
      loading: () => _loadingCard(),
      error: (e, _) => _errorCard(context, e, retry),
      data: (summary) {
        final change = summary.changePercent;
        final down = change != null && change < 0;
        final expenseColor = change == null
            ? GlassColors.textMuted
            : (down ? GlassColors.success : GlassColors.danger);

        // IntrinsicHeight + stretch: hai thẻ cao bằng nhau dù chỉ một thẻ có dòng phụ so với kỳ trước.
        return IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _statCard(
                label: 'Thu nhập',
                amount: formatVnd(summary.totalIncomeCents),
                icon: LucideIcons.trendingUp,
                color: GlassColors.success,
                // Không có số liệu thu nhập tháng trước ở BE — không bịa % thay đổi.
                sublabel: null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                label: 'Chi tiêu',
                amount: formatVnd(summary.totalSpentCents),
                icon: down ? LucideIcons.trendingDown : LucideIcons.trendingUp,
                color: GlassColors.danger,
                sublabelColor: expenseColor,
                sublabel: change == null
                    ? null
                    : '${down ? '↓' : '↑'} ${NumberFormat('0.#', 'vi_VN').format(change.abs())}% so với tháng trước',
              ),
            ),
          ],
        ),
        );
      },
    );
  }

  Widget _statCard({
    required String label,
    required String amount,
    required IconData icon,
    required Color color,
    String? sublabel,
    Color? sublabelColor,
  }) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: GlassTypography.bodyMd(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            amount,
            style: GlassTypography.displayHero().copyWith(fontSize: 20),
          ),
          if (sublabel != null) ...[
            const SizedBox(height: 6),
            // Một dòng, tự thu nhỏ chữ khi hẹp thay vì xuống hàng.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(sublabel, maxLines: 1, style: GlassTypography.bodySm(color: sublabelColor ?? color)),
            ),
          ],
        ],
      ),
    );
  }

  /// Khoảng ngày của biểu đồ: tab Tháng không có [_range] (dùng monthly-summary) nên lấy cả tháng hiện tại.
  DateRange get _chartRange {
    final r = _range;
    if (r != null) return r;
    final now = DateTime.now();
    return (
      DateTime(now.year, now.month),
      DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
  }

  Widget _buildSpendingDetailCard(BuildContext context, WidgetRef ref) {
    final range = _chartRange;
    final daysAsync = ref.watch(dailySpendingProvider(range));
    String dd(DateTime d) => d.day.toString().padLeft(2, '0');
    final from = range.$1;
    final to = DateTime(range.$2.year, range.$2.month, range.$2.day);
    final periodLabel = _period == _Period.day
        ? 'Hôm nay: ${dd(from)} Th${from.month}, ${from.year}'
        : _period == _Period.year
        ? 'Chu kỳ: Năm ${from.year}'
        : 'Chu kỳ: ${dd(from)} Th${from.month} – ${dd(to)} Th${to.month}, ${to.year}';

    final bars = daysAsync.valueOrNull == null
        ? null
        : _buildBars(daysAsync.valueOrNull!, from, to);
    final total = bars?.fold<BigInt>(BigInt.zero, (a, b) => a + b.cents);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final elapsed =
        (today.isBefore(to) ? today : to).difference(from).inDays + 1;
    final avgPerDay = total == null || elapsed < 1
        ? null
        : total ~/ BigInt.from(elapsed);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Chi tiết chi tiêu',
                  style: GlassTypography.headlineSm(),
                ),
              ),
              if (avgPerDay != null && avgPerDay > BigInt.zero) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: GlassBadge(
                    text: 'TB: ${formatVnd(avgPerDay)}/ngày',
                    color: GlassColors.slateAnchor,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(periodLabel, style: GlassTypography.bodySm()),
          const SizedBox(height: 12),
          daysAsync.when(
            loading: () => const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Column(
              children: [
                Text(
                  errorMessage(e),
                  textAlign: TextAlign.center,
                  style: GlassTypography.bodyMd(),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(dailySpendingProvider(range)),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
            data: (_) => total == null || total == BigInt.zero
                ? SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(
                        'Chưa có chi tiêu trong kỳ này.',
                        style: GlassTypography.bodyMd(),
                      ),
                    ),
                  )
                : _SpendingBarChart(
                    key: ValueKey('$_period-${from.millisecondsSinceEpoch}'),
                    bars: bars!,
                    yearly: _period == _Period.year,
                  ),
          ),
        ],
      ),
    );
  }

  /// Gộp ngày thành cột: Ngày/Tuần/Tháng mỗi ngày một cột (kể cả ngày 0 đồng), Năm gộp theo tháng.
  List<_Bar> _buildBars(
    List<TimelineDaySummary> days,
    DateTime from,
    DateTime to,
  ) {
    final byDay = <DateTime, BigInt>{};
    for (final d in days) {
      final date = d.date;
      if (date == null) continue;
      final key = _period == _Period.year
          ? DateTime(date.year, date.month)
          : DateTime(date.year, date.month, date.day);
      byDay[key] = (byDay[key] ?? BigInt.zero) + d.totalSpentCents;
    }
    if (_period == _Period.year) {
      return [
        for (var m = 1; m <= 12; m++)
          _Bar(
            DateTime(from.year, m),
            byDay[DateTime(from.year, m)] ?? BigInt.zero,
          ),
      ];
    }
    final count = to.difference(from).inDays + 1;
    return [
      for (var i = 0; i < count; i++)
        _Bar(
          DateTime(from.year, from.month, from.day + i),
          byDay[DateTime(from.year, from.month, from.day + i)] ?? BigInt.zero,
        ),
    ];
  }

  Widget _buildTools(BuildContext context) {
    Widget tool(String label, IconData icon, String route) => Expanded(
      child: GestureDetector(
        onTap: () => context.push(route),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            children: [
              Icon(icon, size: 18, color: GlassColors.slateAnchor),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GlassTypography.bodySm(
                  color: GlassColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );

    return Row(
      children: [
        tool('Dự báo\ndòng tiền', LucideIcons.waves, '/analytics/cashflow'),
        const SizedBox(width: 10),
        tool(
          'Cảnh báo &\nbất thường',
          LucideIcons.triangleAlert,
          '/analytics/alerts',
        ),
        const SizedBox(width: 10),
        tool(
          'Kiểm tra\nmua sắm',
          LucideIcons.shoppingCart,
          '/analytics/purchase-check',
        ),
      ],
    );
  }

  Widget _buildBreakdownCard(BuildContext context, WidgetRef ref) {
    return ref
        .watch(categoryBreakdownProvider)
        .when(
          loading: () => _loadingCard(),
          error: (e, _) => _errorCard(
            context,
            e,
            () => ref.invalidate(categoryBreakdownProvider),
          ),
          data: (breakdown) {
            final items = [...breakdown.items]
              ..sort((a, b) => b.percent.compareTo(a.percent));
            final top5 = items.take(5).toList();

            return GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cơ cấu chi tiêu',
                              style: GlassTypography.headlineSm(),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${top5.length} danh mục trọng điểm tháng này',
                              style: GlassTypography.bodySm(),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Báo cáo theo danh mục',
                        icon: Icon(
                          LucideIcons.slidersHorizontal,
                          size: 20,
                          color: GlassColors.slateAnchor,
                        ),
                        onPressed: () => context.push('/analytics/categories'),
                      ),
                    ],
                  ),
                  if (top5.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Chưa có chi tiêu tháng này.',
                        style: GlassTypography.bodyMd(),
                      ),
                    )
                  else
                    for (final item in top5) _categoryRow(item),
                ],
              ),
            );
          },
        );
  }

  Widget _categoryRow(CategoryShare item) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: GlassColors.secondarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              categoryIcon(item.slug),
              size: 18,
              color: GlassColors.slateAnchor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: GlassTypography.bodyMd(
                          color: GlassColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatVnd(item.spentCents),
                      style: GlassTypography.labelNumeric(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                GlassProgressBar(percent: item.percent),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${item.percent.round()}%', style: GlassTypography.bodySm()),
        ],
      ),
    );
  }

  Widget _buildAiInsightCard(BuildContext context, WidgetRef ref) {
    return ref
        .watch(spendingInsightsProvider)
        .when(
          loading: () => _loadingCard(),
          error: (_, __) =>
              const SizedBox.shrink(), // nhận xét AI chỉ là gợi ý phụ, lỗi thì ẩn thay vì chắn màn
          data: (insights) {
            if (insights.isEmpty) {
              return GlassCard(
                level: 2,
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.sparkles,
                      size: 22,
                      color: GlassColors.slateAnchor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Trợ lý FinMate AI chưa có nhận xét mới tháng này.',
                        style: GlassTypography.bodyMd(),
                      ),
                    ),
                  ],
                ),
              );
            }

            final insight = insights.first;
            return GlassCard(
              level: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            LucideIcons.sparkles,
                            size: 20,
                            color: GlassColors.slateAnchor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Trợ lý FinMate AI',
                            style: GlassTypography.headlineSm(),
                          ),
                        ],
                      ),
                      if (!insight.isRead)
                        AsyncActionBuilder(
                          onPressed: () async {
                            await ref
                                .read(reportsRepositoryProvider)
                                .markInsightRead(insight.id);
                            ref.invalidate(spendingInsightsProvider);
                          },
                          builder: (_, onTap, running) => TextButton(
                            onPressed: onTap,
                            child: running ? const ButtonLoadingIndicator() : Text(
                              'Đã xem',
                              style: GlassTypography.bodyMd(
                                color: GlassColors.accentSkyBlue,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    insight.title,
                    style: GlassTypography.bodyMd(
                      color: GlassColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(insight.body, style: GlassTypography.bodyMd()),
                ],
              ),
            );
          },
        );
  }

  Widget _loadingCard() => const GlassCard(
    child: SizedBox(
      height: 60,
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  Widget _errorCard(BuildContext context, Object error, VoidCallback retry) {
    return GlassCard(
      child: Column(
        children: [
          Text(
            errorMessage(error),
            textAlign: TextAlign.center,
            style: GlassTypography.bodyMd(),
          ),
          TextButton(onPressed: retry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _Bar {
  final DateTime date;
  final BigInt cents;
  const _Bar(this.date, this.cents);
}

/// Biểu đồ cột chi tiêu (Figma F1): chạm một cột để hiện tooltip "số tiền • ngày", cột đang chọn đậm màu nhấn.
class _SpendingBarChart extends StatefulWidget {
  final List<_Bar> bars;
  final bool yearly;
  const _SpendingBarChart({
    super.key,
    required this.bars,
    required this.yearly,
  });

  @override
  State<_SpendingBarChart> createState() => _SpendingBarChartState();
}

class _SpendingBarChartState extends State<_SpendingBarChart> {
  int? _selected;

  String _label(_Bar b) => widget.yearly
      ? 'Th${b.date.month}'
      : b.date.day.toString().padLeft(2, '0');

  String _tipDate(_Bar b) => widget.yearly
      ? 'Th${b.date.month}/${b.date.year}'
      : '${b.date.day} Th${b.date.month}';

  @override
  Widget build(BuildContext context) {
    final bars = widget.bars;
    // Tối đa ~10 nhãn trục để không chen chúc ở 360dp
    final step = (bars.length / 10).ceil().clamp(1, 99);
    final max = bars.fold<BigInt>(
      BigInt.zero,
      (a, b) => b.cents > a ? b.cents : a,
    );
    final maxY =
        max.toDouble() * 1.15; // chỉ để vẽ tỉ lệ cột, không phải tính tiền

    return Semantics(
      label: 'Biểu đồ cột chi tiêu theo ${widget.yearly ? 'tháng' : 'ngày'}',
      child: SizedBox(
        height: 160,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceBetween,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= bars.length || i % step != 0) {
                      return const SizedBox.shrink();
                    }
                    final selected = i == _selected;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _label(bars[i]),
                        style:
                            GlassTypography.bodySm(
                              color: selected
                                  ? GlassColors.textPrimary
                                  : GlassColors.textMuted,
                            ).copyWith(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchCallback: (event, response) {
                final i = response?.spot?.touchedBarGroupIndex;
                if (i != null && event is FlTapUpEvent && i != _selected) {
                  setState(() => _selected = i);
                }
              },
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => GlassColors.ink,
                tooltipRoundedRadius: 12,
                fitInsideHorizontally: true,
                getTooltipItem: (group, _, rod, __) {
                  final b = bars[group.x];
                  return BarTooltipItem(
                    '${formatVnd(b.cents)} • ${_tipDate(b)}',
                    GlassTypography.bodySm(
                      color: GlassColors.onInk,
                    ).copyWith(fontWeight: FontWeight.w600),
                  );
                },
              ),
            ),
            barGroups: [
              for (final (i, b) in bars.indexed)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: b.cents.toDouble(),
                      width: bars.length > 16 ? 6 : 14,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      color: i == _selected
                          ? GlassColors.ink
                          : GlassColors.accentSkyBlue.withValues(
                              alpha: GlassColors.dark ? 0.55 : 0.6,
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
