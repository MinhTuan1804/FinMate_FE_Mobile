import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/analytics/data/reports_repository.dart';
import 'package:finmate/features/analytics/domain/report_models.dart';
import 'package:finmate/features/analytics/presentation/reports_providers.dart';

/// Giao diện của từng loại nhận xét do backend sinh ra.
({String tag, IconData icon, Color color, String? actionLabel, String? route}) _style(BuildContext context, String type) => switch (type) {
      'vs_last_month' => (
          tag: 'So với tháng trước',
          icon: LucideIcons.chartLine,
          color: AppColors.secondary,
          actionLabel: 'Xem báo cáo',
          route: '/analytics',
        ),
      'recurring_detected' => (
          tag: 'Khoản định kỳ',
          icon: LucideIcons.repeat,
          color: AppColors.slateOn(context),
          actionLabel: 'Xem khoản định kỳ',
          route: '/planning/recurring',
        ),
      'unusual_spending' => (
          tag: 'Chi tiêu bất thường',
          icon: LucideIcons.triangleAlert,
          color: AppColors.warning,
          actionLabel: 'Xem bất thường',
          route: '/analytics/anomalies',
        ),
      _ => (tag: 'Nhận xét', icon: LucideIcons.sparkles, color: AppColors.secondary, actionLabel: null, route: null),
    };

/// Màn F6: Nhận xét của AI, dữ liệu thật từ `/api/v1/reports/insights`.
class AiInsightsScreen extends ConsumerWidget {
  const AiInsightsScreen({super.key});

  Future<void> _markRead(BuildContext context, WidgetRef ref, SpendingInsight insight) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(reportsRepositoryProvider).markInsightRead(insight.id);
      ref.invalidate(spendingInsightsProvider);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(spendingInsightsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhận xét của AI'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Quay lại',
          onPressed: () => context.pop(),
        ),
      ),
      body: AmbientGlassBackground(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(spendingInsightsProvider.future),
          child: insights.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Message(
              text: errorMessage(e),
              actionLabel: 'Thử lại',
              onAction: () => ref.invalidate(spendingInsightsProvider),
            ),
            data: (items) => items.isEmpty
                ? const _Message(text: 'Chưa có nhận xét nào. FinMate sẽ gửi nhận xét khi có đủ dữ liệu chi tiêu của bạn.')
                : _list(context, ref, items),
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, List<SpendingInsight> items) {
    final unread = items.where((i) => !i.isRead).length;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      children: [
        ZenvestHeroDeck(
          peekBadgeText: 'INSIGHT',
          child: LiquidGlassCard(
            variant: LiquidGlassVariant.iridescentHero,
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: AppColors.safe.withValues(alpha: 0.16), shape: BoxShape.circle),
                  child: const Icon(LucideIcons.sparkles, color: AppColors.safe, size: 26),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unread == 0 ? 'Bạn đã xem hết nhận xét' : '$unread nhận xét mới',
                        style: AppTypography.h2(context).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tổng hợp từ chi tiêu thật của bạn, không phải lời khuyên đầu tư.',
                        style: AppTypography.caption(context).copyWith(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('GỢI Ý TÙY BIẾN CHO BẠN', style: AppTypography.sectionLabel(context)),
        const SizedBox(height: 12),
        for (final insight in items) _card(context, ref, insight),
      ],
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, SpendingInsight insight) {
    final style = _style(context, insight.insightType);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.14),
                    borderRadius: AppSpacing.roundedPill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.icon, size: 12, color: style.color),
                      const SizedBox(width: 4),
                      Text(
                        style.tag,
                        style: TextStyle(color: style.color, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd/MM').format(insight.createdAt),
                  style: AppTypography.caption(context).copyWith(fontSize: 11.5),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              insight.title,
              style: AppTypography.body(context).copyWith(
                fontWeight: insight.isRead ? FontWeight.w600 : FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              insight.body,
              style: AppTypography.caption(context).copyWith(
                fontSize: 13,
                color: AppColors.textSecondary(context),
                height: 1.45,
              ),
            ),
            if (insight.amountCents != null) ...[
              const SizedBox(height: 8),
              Text(
                formatVnd(insight.amountCents!),
                style: AppTypography.tabular(
                  AppTypography.caption(context).copyWith(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (style.route != null)
                  OutlinedButton.icon(
                    icon: const Icon(LucideIcons.arrowRight, size: 14),
                    label: Text(style.actionLabel!),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => context.push(style.route!),
                  ),
                if (!insight.isRead)
                  TextButton.icon(
                    icon: const Icon(LucideIcons.check, size: 14),
                    label: const Text('Đánh dấu đã đọc'),
                    onPressed: () => _markRead(context, ref, insight),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    // Cuộn được để kéo-làm-mới hoạt động cả khi rỗng/lỗi.
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Text(text, textAlign: TextAlign.center, style: AppTypography.body(context)),
        if (actionLabel != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(child: OutlinedButton(onPressed: onAction, child: Text(actionLabel!))),
        ],
      ],
    );
  }
}
