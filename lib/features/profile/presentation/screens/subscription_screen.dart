import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

/// Màn H14 & H15: Gói đăng ký FinMate Pro & Lịch sử đơn hàng (Subscription Screen)
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gói đăng ký & Dịch vụ'),
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
              // Hero Subscription Card
              ZenvestHeroDeck(
                peekBadgeText: 'PRO',
                child: LiquidGlassCard(
                  variant: LiquidGlassVariant.iridescentHero,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.2),
                              borderRadius: AppSpacing.roundedPill,
                            ),
                            child: const Text(
                              'Gói hiện tại: MIỄN PHÍ (Free)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slateAction,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nâng cấp FinMate Pro',
                        style: AppTypography.h1(context).copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mở khóa toàn bộ sức mạnh AI tài chính không giới hạn, quét hóa đơn tự động và dự báo dòng tiền chính xác.',
                        style: AppTypography.caption(context).copyWith(fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '59.000 ₫',
                            style: AppTypography.displayBalance(context).copyWith(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('/ tháng', style: AppTypography.caption(context)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text('QUYỀN LỢI ĐẶC QUYỀN GÓI PRO', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),

              ZenvestSurfaceSheet(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  children: [
                    _benefitRow('Trợ lý AI FinMate không giới hạn số lượng tin nhắn'),
                    const Divider(height: 16),
                    _benefitRow('Quét và trích xuất hóa đơn tự động từ ảnh & camera (OCR)'),
                    const Divider(height: 16),
                    _benefitRow('Dự báo dòng tiền và cảnh báo chi tiêu thông minh'),
                    const Divider(height: 16),
                    _benefitRow('Sao lưu đám mây không giới hạn và xuất file Excel'),
                    const Divider(height: 16),
                    _benefitRow('Quản lý không giới hạn số lượng ví và tài khoản ngân hàng'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              LiquidGlassPillButton(
                label: 'Đăng ký FinMate Pro ngay',
                icon: LucideIcons.sparkles,
                isFullWidth: true,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cổng thanh toán đang kết nối')),
                  );
                },
              ),

              const SizedBox(height: 28),

              Text('LỊCH SỬ THANH TOÁN (ORDERS)', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),

              LiquidGlassCard(
                variant: LiquidGlassVariant.subtle,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(LucideIcons.history, size: 20, color: AppColors.slateAction),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chưa có giao dịch thanh toán',
                            style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Lịch sử gia hạn gói dịch vụ sẽ hiển thị tại đây.',
                            style: AppTypography.caption(context).copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _benefitRow(String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.safe.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(LucideIcons.check, size: 14, color: AppColors.safe),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
