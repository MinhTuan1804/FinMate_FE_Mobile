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
        return (today, today.add(const Duration(hours: 23, minutes: 59, seconds: 59)));
      case _Period.week:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        final sunday = monday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
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
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(monthlySummaryProvider);
              final range = _range;
              if (range != null) ref.invalidate(periodSummaryProvider(range));
              ref.invalidate(categoryBreakdownProvider);
              ref.invalidate(forecastProvider);
              ref.invalidate(spendingInsightsProvider);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                _buildHeader(context, user?.displayName),
                const SizedBox(height: 20),
                Text('TỔNG QUAN TÀI CHÍNH', style: GlassTypography.labelCaps()),
                const SizedBox(height: 4),
                Text('Phân tích tài chính', style: GlassTypography.headlineLg()),
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
        bottomNavigationBar: GlassBottomNav(currentIndex: 3, onDestinationSelected: (idx) => _onNavSelected(context, idx)),
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

  Widget _buildHeader(BuildContext context, String? displayName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Xin chào,', style: GlassTypography.bodyMd()),
            const SizedBox(height: 2),
            Text(displayName ?? 'Bạn của FinMate', style: GlassTypography.headlineMd()),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(LucideIcons.bell, size: 22, color: GlassColors.textPrimary),
              onPressed: () => context.push('/notifications'),
            ),
            IconButton(
              icon: const Icon(LucideIcons.circleUser, size: 24, color: GlassColors.textPrimary),
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
                style: GlassTypography.bodyMd(color: selected ? Colors.white : GlassColors.textMuted)
                    .copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
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
    final summaryAsync = range == null ? ref.watch(monthlySummaryProvider) : ref.watch(periodSummaryProvider(range));
    void retry() => range == null ? ref.invalidate(monthlySummaryProvider) : ref.invalidate(periodSummaryProvider(range));

    return summaryAsync.when(
          loading: () => _loadingCard(),
          error: (e, _) => _errorCard(context, e, retry),
          data: (summary) {
            final change = summary.changePercent;
            final down = change != null && change < 0;
            final expenseColor = change == null ? GlassColors.textMuted : (down ? GlassColors.success : GlassColors.danger);

            return Row(
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
                    color: expenseColor,
                    sublabel: change == null
                        ? null
                        : '${down ? '↓' : '↑'} ${NumberFormat('0.#', 'vi_VN').format(change.abs())}% so với tháng trước',
                  ),
                ),
              ],
            );
          },
        );
  }

  Widget _statCard({required String label, required String amount, required IconData icon, required Color color, String? sublabel}) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GlassTypography.bodyMd()),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(amount, style: GlassTypography.displayHero().copyWith(fontSize: 20)),
          if (sublabel != null) ...[
            const SizedBox(height: 6),
            Text(sublabel, style: GlassTypography.bodySm(color: color)),
          ],
        ],
      ),
    );
  }

  Widget _buildSpendingDetailCard(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final forecast = ref.watch(forecastProvider).valueOrNull;
    final summary = ref.watch(monthlySummaryProvider).valueOrNull;

    final daysElapsed = forecast != null && forecast.daysElapsed > 0 ? forecast.daysElapsed : now.day;
    final avgPerDay = summary == null ? null : summary.totalSpentCents ~/ BigInt.from(daysElapsed.clamp(1, 999));

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Chi tiết chi tiêu', style: GlassTypography.headlineSm()),
              if (avgPerDay != null)
                GlassBadge(text: 'TB: ${formatVnd(avgPerDay)}/ngày', color: GlassColors.slateAnchor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Chu kỳ: 01 Th${now.month} – $lastDay Th${now.month}, ${now.year}',
            style: GlassTypography.bodySm(),
          ),
        ],
      ),
    );
  }

  Widget _buildTools(BuildContext context) {
    Widget tool(String label, IconData icon, String route) => Expanded(
          child: GestureDetector(
            onTap: () => context.push(route),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Column(
                children: [
                  Icon(icon, size: 20, color: GlassColors.slateAnchor),
                  const SizedBox(height: 8),
                  Text(label, textAlign: TextAlign.center, style: GlassTypography.bodySm(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        );

    return Row(
      children: [
        tool('Dự báo\ndòng tiền', LucideIcons.waves, '/analytics/cashflow'),
        const SizedBox(width: 10),
        tool('Cảnh báo &\nbất thường', LucideIcons.triangleAlert, '/analytics/alerts'),
        const SizedBox(width: 10),
        tool('Kiểm tra\nmua sắm', LucideIcons.shoppingCart, '/analytics/purchase-check'),
      ],
    );
  }

  Widget _buildBreakdownCard(BuildContext context, WidgetRef ref) {
    return ref.watch(categoryBreakdownProvider).when(
          loading: () => _loadingCard(),
          error: (e, _) => _errorCard(context, e, () => ref.invalidate(categoryBreakdownProvider)),
          data: (breakdown) {
            final items = [...breakdown.items]..sort((a, b) => b.percent.compareTo(a.percent));
            final top5 = items.take(5).toList();

            return GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cơ cấu chi tiêu', style: GlassTypography.headlineSm()),
                          const SizedBox(height: 2),
                          Text('${top5.length} danh mục trọng điểm tháng này', style: GlassTypography.bodySm()),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.slidersHorizontal, size: 20, color: GlassColors.slateAnchor),
                        onPressed: () => context.push('/analytics/categories'),
                      ),
                    ],
                  ),
                  if (top5.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('Chưa có chi tiêu tháng này.', style: GlassTypography.bodyMd()),
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
            decoration: BoxDecoration(color: GlassColors.secondarySurface, borderRadius: BorderRadius.circular(10)),
            child: Icon(categoryIcon(item.slug), size: 18, color: GlassColors.slateAnchor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text(item.name, style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    Text(formatVnd(item.spentCents), style: GlassTypography.labelNumeric()),
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
    return ref.watch(spendingInsightsProvider).when(
          loading: () => _loadingCard(),
          error: (_, __) => const SizedBox.shrink(), // nhận xét AI chỉ là gợi ý phụ, lỗi thì ẩn thay vì chắn màn
          data: (insights) {
            if (insights.isEmpty) {
              return GlassCard(
                level: 2,
                child: Row(
                  children: [
                    const Icon(LucideIcons.sparkles, size: 22, color: GlassColors.slateAnchor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Trợ lý FinMate AI chưa có nhận xét mới tháng này.', style: GlassTypography.bodyMd()),
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
                          const Icon(LucideIcons.sparkles, size: 20, color: GlassColors.slateAnchor),
                          const SizedBox(width: 8),
                          Text('Trợ lý FinMate AI', style: GlassTypography.headlineSm()),
                        ],
                      ),
                      if (!insight.isRead)
                        TextButton(
                          onPressed: () async {
                            await ref.read(reportsRepositoryProvider).markInsightRead(insight.id);
                            ref.invalidate(spendingInsightsProvider);
                          },
                          child: Text('Đã xem', style: GlassTypography.bodyMd(color: GlassColors.accentSkyBlue)),
                        ),
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

  Widget _loadingCard() => const GlassCard(child: SizedBox(height: 60, child: Center(child: CircularProgressIndicator())));

  Widget _errorCard(BuildContext context, Object error, VoidCallback retry) {
    return GlassCard(
      child: Column(
        children: [
          Text(errorMessage(error), textAlign: TextAlign.center, style: GlassTypography.bodyMd()),
          TextButton(onPressed: retry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
