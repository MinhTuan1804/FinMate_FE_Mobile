import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/analytics/data/reports_repository.dart';
import 'package:finmate/features/analytics/domain/report_models.dart';
import 'package:finmate/features/analytics/presentation/reports_providers.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

const _insightTypeLabel = {
  'vs_last_month': 'So với tháng trước',
  'recurring_detected': 'Khoản định kỳ',
  'unusual_spending': 'Cần chú ý',
};

const _insightTypeIcon = {
  'vs_last_month': LucideIcons.chartNoAxesCombined,
  'recurring_detected': LucideIcons.calendarClock,
  'unusual_spending': LucideIcons.triangleAlert,
};

/// Màu theo loại: cần chú ý = vàng, còn lại (so sánh/định kỳ) = xanh dương. BE chưa phân loại "điểm sáng"
/// (tốt) nên chưa có thẻ xanh lá — không tự đoán từ nội dung.
Color _insightColor(String type) => type == 'unusual_spending' ? GlassColors.warning : GlassColors.slateAnchor;

/// F6 — Nhận xét AI & Báo cáo tháng (Luồng 6). Figma vẽ vòng điểm sức khỏe tài chính, 3 chỉ số
/// 50/30/20 và khối phản hồi — BE KHÔNG có dữ liệu/endpoint cho các phần này (chỉ 3 loại insight qua
/// `GET /reports/insights`), nên bị ẩn thay vì bịa (đề xuất BE: FinMate_BE/docs/flows/financial-health-score-proposal.md).
class F6AiSummaryScreen extends ConsumerWidget {
  const F6AiSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: Icon(LucideIcons.arrowLeft, color: GlassColors.textPrimary), tooltip: 'Quay lại', onPressed: () => context.pop()),
          title: Text('Nhận xét AI & Báo cáo tháng', style: GlassTypography.headlineMd()),
          actions: [
            IconButton(
              icon: Icon(LucideIcons.share2, color: GlassColors.textPrimary),
              tooltip: 'Chia sẻ báo cáo',
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chia sẻ báo cáo sắp có.'))),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(monthlySummaryProvider);
              ref.invalidate(spendingInsightsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                ref.watch(monthlySummaryProvider).when(
                      loading: () => _loadingCard(),
                      error: (e, _) => _errorCard(e, () => ref.invalidate(monthlySummaryProvider)),
                      data: (summary) => _buildHero(now, summary),
                    ),
                const SizedBox(height: 20),
                Row(children: [
                  Icon(LucideIcons.sparkles, size: 18, color: GlassColors.slateAnchor),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Phân tích chi tiết từ trợ lý FinMate', style: GlassTypography.headlineSm())),
                ]),
                const SizedBox(height: 10),
                ref.watch(spendingInsightsProvider).when(
                      loading: () => _loadingCard(),
                      error: (e, _) => _errorCard(e, () => ref.invalidate(spendingInsightsProvider)),
                      data: (insights) => _buildInsights(context, ref, insights),
                    ),
                const SizedBox(height: 16),
                _buildExportButton(),
                const SizedBox(height: 12),
                Text(
                  'Nhận xét dựa trên các giao dịch bạn đã xác nhận trong ứng dụng — không thay thế tư vấn tài chính chuyên môn.',
                  style: GlassTypography.bodySm(),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(DateTime now, MonthlySummary summary) {
    return GlassCard(
      level: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassBadge(text: 'FinMate Intelligence', color: GlassColors.slateAnchor),
          const SizedBox(height: 12),
          Text('Báo cáo tài chính\nTháng ${now.month}/${now.year}', style: GlassTypography.headlineMd()),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _statColumn('Thu nhập', formatVnd(summary.totalIncomeCents), GlassColors.success)),
              Expanded(child: _statColumn('Chi tiêu', formatVnd(summary.totalSpentCents), GlassColors.danger)),
              Expanded(child: _statColumn('Số dư ròng', formatVnd(summary.netCents), GlassColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GlassTypography.bodySm()),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, maxLines: 1, style: GlassTypography.bodyMd(color: color).copyWith(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildInsights(BuildContext context, WidgetRef ref, List<SpendingInsight> insights) {
    if (insights.isEmpty) {
      return GlassCard(child: Text('Chưa có nhận xét nào từ AI cho tháng này.', style: GlassTypography.bodyMd()));
    }

    return Column(
      children: [for (final insight in insights) ...[_insightCard(context, ref, insight), const SizedBox(height: 12)]],
    );
  }

  Widget _insightCard(BuildContext context, WidgetRef ref, SpendingInsight insight) {
    final color = _insightColor(insight.insightType);
    final typeLabel = _insightTypeLabel[insight.insightType] ?? insight.insightType;
    return Opacity(
      opacity: insight.isRead ? 0.8 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: GlassRadius.roundedCard,
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(_insightTypeIcon[insight.insightType] ?? LucideIcons.lightbulb, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(insight.title, style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 8, runSpacing: 4, children: [
                          GlassBadge(text: typeLabel, color: color),
                          if (insight.categoryName != null) GlassBadge(text: insight.categoryName!, color: GlassColors.textMuted),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(insight.body, style: GlassTypography.bodyMd()),
              if (insight.amountCents != null) ...[
                const SizedBox(height: 8),
                Text(formatVnd(insight.amountCents!), style: GlassTypography.labelNumeric(color: color)),
              ],
              if (!insight.isRead)
                Align(
                  alignment: Alignment.centerRight,
                  child: AsyncActionBuilder(
                    onPressed: () async {
                      await ref.read(reportsRepositoryProvider).markInsightRead(insight.id);
                      ref.invalidate(spendingInsightsProvider);
                    },
                    builder: (_, onTap, running) => TextButton.icon(
                      onPressed: onTap,
                      icon: running ? const ButtonLoadingIndicator(size: 16) : Icon(LucideIcons.check, size: 16, color: GlassColors.slateAnchor),
                      label: FittedBox(fit: BoxFit.scaleDown, child: Text('Đánh dấu đã xem', style: GlassTypography.bodyMd(color: GlassColors.slateAnchor), maxLines: 1)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Chưa có tính năng xuất — nút khóa, kèm nhãn "Sắp có" (không bấm được, đọc được qua Semantics).
  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: Semantics(
        button: true,
        enabled: false,
        label: 'Tải bản tóm tắt, sắp có',
        child: ElevatedButton.icon(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: GlassColors.ink.withValues(alpha: 0.45),
            disabledForegroundColor: GlassColors.onInk,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
          ),
          icon: const Icon(LucideIcons.lock, size: 18),
          label: const Text('Tải bản tóm tắt · Sắp có', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  Widget _loadingCard() => const GlassCard(child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())));

  Widget _errorCard(Object error, VoidCallback retry) => GlassCard(
        child: Column(
          children: [
            Text(errorMessage(error), textAlign: TextAlign.center, style: GlassTypography.bodyMd()),
            TextButton(onPressed: retry, child: const Text('Thử lại')),
          ],
        ),
      );
}
