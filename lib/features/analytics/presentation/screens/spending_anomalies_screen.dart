import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

class SpendingAnomaly {
  final String id;
  final String title;
  final String description;
  final BigInt amountCents;
  final DateTime date;
  final String category;
  final double variancePercent;
  bool? isHelpful;

  SpendingAnomaly({
    required this.id,
    required this.title,
    required this.description,
    required this.amountCents,
    required this.date,
    required this.category,
    required this.variancePercent,
    this.isHelpful,
  });
}

/// Màn F4: Cảnh báo và phát hiện bất thường chi tiêu (Spending Anomalies Screen)
class SpendingAnomaliesScreen extends ConsumerStatefulWidget {
  const SpendingAnomaliesScreen({super.key});

  @override
  ConsumerState<SpendingAnomaliesScreen> createState() => _SpendingAnomaliesScreenState();
}

class _SpendingAnomaliesScreenState extends ConsumerState<SpendingAnomaliesScreen> {
  final List<SpendingAnomaly> _anomalies = [
    SpendingAnomaly(
      id: 'a1',
      title: 'Chi tiêu Ăn uống đột biến',
      description: 'Giao dịch 450.000 ₫ tại Nhà hàng lẩu cao hơn 180% so với mức trung bình bữa tối thường ngày của bạn.',
      amountCents: BigInt.from(450000),
      date: DateTime.now().subtract(const Duration(hours: 18)),
      category: 'Ăn uống',
      variancePercent: 180,
    ),
    SpendingAnomaly(
      id: 'a2',
      title: 'Khoản trừ phí đăng ký bất thường',
      description: 'Phát hiện khoản trừ 249.000 ₫ cho dịch vụ phần mềm chưa từng xuất hiện trong lịch sử 3 tháng qua.',
      amountCents: BigInt.from(249000),
      date: DateTime.now().subtract(const Duration(days: 2)),
      category: 'Dịch vụ mạng',
      variancePercent: 100,
    ),
    SpendingAnomaly(
      id: 'a3',
      title: 'Tần suất mua sắm dày đặc',
      description: 'Bạn đã thực hiện 5 giao dịch mua sắm thương mại điện tử trong vòng 48 giờ.',
      amountCents: BigInt.from(1280000),
      date: DateTime.now().subtract(const Duration(days: 4)),
      category: 'Mua sắm',
      variancePercent: 95,
    ),
  ];

  void _rateFeedback(String id, bool helpful) {
    setState(() {
      final index = _anomalies.indexWhere((a) => a.id == id);
      if (index != -1) {
        _anomalies[index].isHelpful = helpful;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(helpful ? 'Cảm ơn phản hồi của bạn!' : 'FinMate đã ghi nhận và sẽ điều chỉnh thuật toán.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cảnh báo & Bất thường'),
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
              // Header Summary Card
              ZenvestHeroDeck(
                peekBadgeText: 'ANOMALY',
                child: LiquidGlassCard(
                  variant: LiquidGlassVariant.iridescentHero,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.triangleAlert, color: AppColors.warning, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phát hiện ${_anomalies.length} bất thường',
                              style: AppTypography.h2(context).copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Hệ thống đối chiếu lịch sử để bảo vệ ngân sách của bạn kịp thời.',
                              style: AppTypography.caption(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              for (final item in _anomalies) ...[
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
                                color: AppColors.danger.withValues(alpha: 0.12),
                                borderRadius: AppSpacing.roundedPill,
                              ),
                              child: Text(
                                '+${item.variancePercent.toInt()}% so với kỳ vọng',
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat('HH:mm - dd/MM').format(item.date),
                              style: AppTypography.caption(context).copyWith(fontSize: 11.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.title,
                          style: AppTypography.body(context).copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style: AppTypography.caption(context).copyWith(
                            fontSize: 13,
                            color: AppColors.textSecondary(context),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatVnd(item.amountCents),
                              style: AppTypography.displayBalance(context).copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.danger,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Hữu ích?',
                                  style: AppTypography.caption(context).copyWith(fontSize: 12),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _rateFeedback(item.id, true),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: item.isHelpful == true
                                          ? AppColors.safe.withValues(alpha: 0.2)
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      LucideIcons.thumbsUp,
                                      size: 16,
                                      color: item.isHelpful == true ? AppColors.safe : AppColors.textMuted(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _rateFeedback(item.id, false),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: item.isHelpful == false
                                          ? AppColors.danger.withValues(alpha: 0.2)
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      LucideIcons.thumbsDown,
                                      size: 16,
                                      color: item.isHelpful == false ? AppColors.danger : AppColors.textMuted(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
