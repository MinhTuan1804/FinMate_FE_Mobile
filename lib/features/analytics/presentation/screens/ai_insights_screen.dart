import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

class AiInsightCardData {
  final String title;
  final String body;
  final String tag;
  final IconData icon;
  final Color color;
  final String actionLabel;
  final String route;

  const AiInsightCardData({
    required this.title,
    required this.body,
    required this.tag,
    required this.icon,
    required this.color,
    required this.actionLabel,
    required this.route,
  });
}

/// Màn F6: Nhận xét và tư vấn thông minh từ AI (AI Insights Screen)
class AiInsightsScreen extends ConsumerWidget {
  const AiInsightsScreen({super.key});

  static const _insights = [
    AiInsightCardData(
      title: 'Tối ưu chi phí ăn uống ngoài',
      body: 'Tuần qua bạn đã chi 42% ngân sách tháng cho việc đi ăn tiệm. Nấu ăn tại nhà thêm 2 bữa/tuần sẽ giúp bạn tiết kiệm khoảng 450.000 ₫/tuần.',
      tag: 'Tiết kiệm',
      icon: LucideIcons.utensils,
      color: AppColors.secondary,
      actionLabel: 'Xem ngân sách Ăn uống',
      route: '/planning',
    ),
    AiInsightCardData(
      title: 'Tiến độ mục tiêu Quỹ Du Lịch rất tốt',
      body: 'Với tốc độ tích lũy hiện tại, bạn dự kiến sẽ hoàn thành mục tiêu 10.000.000 ₫ sớm hơn 12 ngày so với kế hoạch ban đầu.',
      tag: 'Mục tiêu',
      icon: LucideIcons.trophy,
      color: AppColors.safe,
      actionLabel: 'Xem chi tiết mục tiêu',
      route: '/planning',
    ),
    AiInsightCardData(
      title: 'Tái cân bằng hạn mức ngân sách',
      body: 'Danh mục Mua sắm đang còn dư 60% hạn mức trong khi danh mục Di chuyển sắp chạm ngưỡng cảnh báo. Đề xuất điều chuyển 300.000 ₫ giữa 2 danh mục.',
      tag: 'Tối ưu hóa',
      icon: LucideIcons.slidersHorizontal,
      color: AppColors.slateAction,
      actionLabel: 'Điều chỉnh hạn mức',
      route: '/planning',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhận xét của AI'),
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
              // Health Score Hero Card
              ZenvestHeroDeck(
                peekBadgeText: 'HEALTH',
                child: LiquidGlassCard(
                  variant: LiquidGlassVariant.iridescentHero,
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: AppColors.safe.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.safe.withValues(alpha: 0.4), width: 2),
                        ),
                        child: const Center(
                          child: Text(
                            '88',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.safe,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sức khỏe tài chính: Rất Tốt',
                              style: AppTypography.h2(context).copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tỷ lệ tiết kiệm đạt 24% thu nhập. Các khoản chi cố định được duy trì ổn định trong ngưỡng an toàn.',
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

              Text(
                'GỢI Ý TÙY BIẾN CHO BẠN',
                style: AppTypography.sectionLabel(context),
              ),
              const SizedBox(height: 12),

              for (final insight in _insights) ...[
                Padding(
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
                                color: insight.color.withValues(alpha: 0.14),
                                borderRadius: AppSpacing.roundedPill,
                              ),
                              child: Text(
                                insight.tag,
                                style: TextStyle(
                                  color: insight.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          insight.title,
                          style: AppTypography.body(context).copyWith(
                            fontWeight: FontWeight.w700,
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
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          icon: const Icon(LucideIcons.arrowRight, size: 14),
                          label: Text(insight.actionLabel),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => context.push(insight.route),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
