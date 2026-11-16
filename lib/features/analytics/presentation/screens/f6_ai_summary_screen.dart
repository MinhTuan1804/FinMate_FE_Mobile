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
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

const _insightTypeLabel = {
  'vs_last_month': 'So với tháng trước',
  'recurring_detected': 'Khoản định kỳ',
  'unusual_spending': 'Chi tiêu bất thường',
};

/// F6 — Nhận xét AI & Báo cáo tháng (Luồng 6). Stitch F6 vẽ điểm sức khỏe tài chính "/100" và
/// breakdown quy tắc 50/30/20 — BE hiện KHÔNG có 2 thứ này (chỉ `InsightGeneratorJob` với 3 loại
/// insight cố định qua `GET /reports/insights`). Theo quyết định 2026-11-16: không bịa điểm số/
/// breakdown ở FE, không tự thêm BE khi chưa duyệt — F6 chỉ hiện đúng dữ liệu thật đang có, phần
/// còn thiếu đã ghi thành đề xuất riêng gửi nhóm trưởng
/// (`FinMate_BE/docs/flows/financial-health-score-proposal.md`) để quyết định sau.
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
          leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: GlassColors.textPrimary), onPressed: () => context.pop()),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nhận xét AI & Báo cáo tháng', style: GlassTypography.headlineMd()),
              Text('FinMate Intelligence · Cập nhật ${DateFormat('dd/MM').format(now)}', style: GlassTypography.bodySm()),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.share2, color: GlassColors.textPrimary),
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
                      data: (summary) => _buildSummaryCard(now, summary),
                    ),
                const SizedBox(height: 16),
                Text('Nhận xét từ trợ lý FinMate', style: GlassTypography.headlineSm()),
                const SizedBox(height: 10),
                ref.watch(spendingInsightsProvider).when(
                      loading: () => _loadingCard(),
                      error: (e, _) => _errorCard(e, () => ref.invalidate(spendingInsightsProvider)),
                      data: (insights) => _buildInsights(context, ref, insights),
                    ),
                const SizedBox(height: 16),
                _buildExportButton(context),
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

  Widget _buildSummaryCard(DateTime now, MonthlySummary summary) {
    return GlassCard(
      level: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BÁO CÁO THÁNG ${now.month}/${now.year}', style: GlassTypography.labelCaps()),
          const SizedBox(height: 10),
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
        Text(value, style: GlassTypography.bodyMd(color: color).copyWith(fontWeight: FontWeight.w700)),
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
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GlassBadge(text: _insightTypeLabel[insight.insightType] ?? insight.insightType, color: GlassColors.slateAnchor),
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
          if (insight.categoryName != null || insight.amountCents != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (insight.categoryName != null) GlassBadge(text: insight.categoryName!, color: GlassColors.accentSkyBlue),
                if (insight.amountCents != null) GlassBadge(text: formatVnd(insight.amountCents!), color: GlassColors.textMuted),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExportButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tải báo cáo tóm tắt sắp có.'))),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: GlassColors.glassBorder), shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill)),
        icon: const Icon(LucideIcons.download, size: 18, color: GlassColors.textPrimary),
        label: Text('Tải báo cáo tóm tắt (PDF)', style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
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
