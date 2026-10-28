import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';

/// Thanh gợi mở trợ lý ở Trang chủ: chạm để mở màn chat
class AssistantPromptBar extends StatelessWidget {
  const AssistantPromptBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => context.push('/assistant'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLight,
          borderRadius: AppSpacing.roundedLarge,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.sparkles, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hỏi FinMate: ăn phở 45k, tháng này tôi tiêu bao nhiêu?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(context).copyWith(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/assistant?start=scan'),
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(LucideIcons.scanLine, size: 20, color: AppColors.primary),
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/assistant?start=voice'),
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(LucideIcons.mic, size: 20, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
