import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';

/// Nhắc bật quyền đọc thông báo (hiện ở "Chờ duyệt" khi quyền đang tắt). Cùng kiểu khung cảnh báo với màn rà soát giao dịch.
class NotificationAccessCard extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const NotificationAccessCard({super.key, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: AppSpacing.roundedMedium,
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.bellOff, color: AppColors.warning, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chưa bật quyền đọc thông báo', style: AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'FinMate cần quyền này để tự tạo nháp từ thông báo của ngân hàng và ví. Các nháp đã có vẫn xem được bên dưới.',
                    style: AppTypography.caption(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(LucideIcons.settings, size: 16),
                    label: const Text('Mở cài đặt'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
