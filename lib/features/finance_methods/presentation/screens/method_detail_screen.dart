import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

/// Màn B6: Chi tiết một phương pháp tài chính (Method Detail / Jars Screen)
class MethodDetailScreen extends ConsumerWidget {
  const MethodDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quy tắc quản lý hũ chi tiêu'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.slidersHorizontal),
            tooltip: 'Tùy chỉnh tỷ lệ',
            onPressed: () => context.push('/alert-thresholds'),
          ),
        ],
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Method Card
              ZenvestHeroDeck(
                peekBadgeText: 'JARS',
                child: LiquidGlassCard(
                  variant: LiquidGlassVariant.iridescentHero,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.pieChart, color: AppColors.secondary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Phương pháp 6 Chiếc Hũ (Jars)',
                                  style: AppTypography.h2(context).copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Đang áp dụng cho tài khoản của bạn',
                                  style: AppTypography.caption(context),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        'Phân chia thu nhập hàng tháng tự động vào các hũ chi tiêu để bạn vừa đáp ứng nhu cầu thiết yếu, vừa đầu tư cho tương lai mà không phải đắn đo.',
                        style: AppTypography.caption(context).copyWith(
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text('DANH SÁCH CÁC HŨ CHI TIÊU', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),

              _jarItem(
                context,
                name: 'Nhu cầu thiết yếu (NEC)',
                percent: 55,
                amount: 8250000,
                color: AppColors.chartPalette[0],
                description: 'Tiền nhà, ăn uống, điện nước, di chuyển và sinh hoạt phí.',
              ),
              _jarItem(
                context,
                name: 'Tiết kiệm dài hạn (LTSS)',
                percent: 10,
                amount: 1500000,
                color: AppColors.chartPalette[1],
                description: 'Mua sắm lớn, quỹ dự phòng hoặc các mục tiêu tương lai.',
              ),
              _jarItem(
                context,
                name: 'Giáo dục & Phát triển (EDUC)',
                percent: 10,
                amount: 1500000,
                color: AppColors.chartPalette[2],
                description: 'Sách, khóa học, nâng cao kỹ năng nghề nghiệp.',
              ),
              _jarItem(
                context,
                name: 'Tự do tài chính (FFA)',
                percent: 10,
                amount: 1500000,
                color: AppColors.chartPalette[3],
                description: 'Đầu tư sinh lời, tạo dòng tiền thu nhập thụ động.',
              ),
              _jarItem(
                context,
                name: 'Hưởng thụ cá nhân (PLAY)',
                percent: 10,
                amount: 1500000,
                color: AppColors.chartPalette[4],
                description: 'Ăn nhà hàng sang, du lịch, giải trí và chăm sóc bản thân.',
              ),
              _jarItem(
                context,
                name: 'Cho đi & Giúp đỡ (GIVE)',
                percent: 5,
                amount: 750000,
                color: AppColors.chartPalette[5],
                description: 'Từ thiện, giúp đỡ gia đình, bạn bè và người thân.',
              ),

              const SizedBox(height: 20),

              LiquidGlassPillButton(
                label: 'Đổi phương pháp khác',
                icon: LucideIcons.refreshCw,
                isFullWidth: true,
                onPressed: () => context.push('/finance-survey'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jarItem(
    BuildContext context, {
    required String name,
    required int percent,
    required int amount,
    required Color color,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: AppTypography.body(context).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: AppSpacing.roundedPill,
                  ),
                  child: Text(
                    '$percent%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: AppTypography.caption(context).copyWith(fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Hạn mức tháng:', style: AppTypography.caption(context).copyWith(fontSize: 12)),
                Text(
                  formatVnd(BigInt.from(amount)),
                  style: AppTypography.tabular(
                    AppTypography.body(context).copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LiquidGlassProgressBar(
              value: percent / 100,
              color: color,
              height: 5,
            ),
          ],
        ),
      ),
    );
  }
}
