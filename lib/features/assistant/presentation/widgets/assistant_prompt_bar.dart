import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

/// Thanh gợi mở trợ lý AI ở Trang chủ: phong cách Pill Search / Prompt từ Serene Glass FinTech (Ảnh 1).
/// Vùng chạm nút Quét hóa đơn và Giọng nói đạt chuẩn >= 44x44pt.
class AssistantPromptBar extends StatelessWidget {
  const AssistantPromptBar({super.key});

  @override
  Widget build(BuildContext context) {
    final actionColor = AppColors.primaryAction(context);
    final isDark = AppColors.isDark(context);

    return LiquidGlassCard(
      enableBlur: false,
      borderRadius: AppSpacing.roundedPill,
      padding: const EdgeInsets.only(left: 16, right: 6, top: 4, bottom: 4),
      onTap: () => context.push('/assistant'),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.secondary.withValues(alpha: 0.16)
                  : AppColors.tertiary.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.sparkles, size: 17, color: actionColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Hỏi FinMate: ăn phở 45k, tháng này tôi tiêu bao nhiêu?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(context).copyWith(
                color: AppColors.textSecondary(context),
                fontSize: 13.5,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Quét hóa đơn',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => context.push('/assistant?start=scan'),
            icon: Icon(LucideIcons.scanLine, size: 19, color: actionColor),
          ),
          IconButton(
            tooltip: 'Nhập bằng giọng nói',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => context.push('/assistant?start=voice'),
            icon: Icon(LucideIcons.mic, size: 19, color: actionColor),
          ),
        ],
      ),
    );
  }
}
