import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/native/notification_bridge.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/accounts/domain/data_coverage.dart';

/// Thẻ độ phủ dữ liệu (màn Tài khoản, màn Dự báo). Mất quyền đọc thông báo là việc người dùng tự sửa được nên đứng đầu và có nút mở Cài đặt;
/// còn lại chỉ nói số BE tính (không tự suy ra). Chưa đủ dữ liệu (`coveragePercent == null`) thì không hiện.
Widget? dataCoverageBanner(BuildContext context, DataCoverage coverage) {
  final percent = coverage.coveragePercent;
  final String text;
  final Color color;
  final IconData icon;
  if (coverage.hasPermissionLost) {
    text = 'Quyền đọc thông báo đang tắt, nên FinMate không đọc được thông báo ngân hàng và số liệu có thể thiếu giao dịch.';
    color = AppColors.danger;
    icon = LucideIcons.bellOff;
  } else if (percent == null) {
    return null;
  } else {
    final days = coverage.windowDays;
    switch (coverage.level) {
      case CoverageLevel.good:
        text = 'FinMate đọc được thông báo ngân hàng $percent% số ngày trong $days ngày gần đây.';
        color = AppColors.safe;
        icon = LucideIcons.circleCheck;
      case CoverageLevel.partial:
        text = 'FinMate chỉ đọc được thông báo ngân hàng $percent% số ngày trong $days ngày gần đây, nên có thể thiếu một vài giao dịch.';
        color = AppColors.warning;
        icon = LucideIcons.triangleAlert;
      case CoverageLevel.poor:
        text = 'Chỉ $percent% số ngày trong $days ngày gần đây FinMate đọc được thông báo ngân hàng, nên số liệu có thể thiếu giao dịch.';
        color = AppColors.danger;
        icon = LucideIcons.triangleAlert;
      case CoverageLevel.unknown:
        return null;
    }
  }

  return Container(
    key: const ValueKey('coverage-banner'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: AppSpacing.roundedMedium,
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: AppTypography.caption(context)),
              if (coverage.hasPermissionLost)
                TextButton(
                  key: const ValueKey('coverage-open-settings'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                  onPressed: sharedNotificationBridge.openNotificationAccessSettings,
                  child: const Text('Mở cài đặt thông báo'),
                ),
              if (!coverage.hasPermissionLost && coverage.level != CoverageLevel.good)
                TextButton(
                  key: const ValueKey('coverage-battery-guide'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                  onPressed: () => context.push('/battery-guide', extra: coverage.manufacturer),
                  child: const Text('Cách giữ FinMate chạy nền'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
