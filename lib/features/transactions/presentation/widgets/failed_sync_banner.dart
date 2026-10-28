import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/database/app_database.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';

/// Số giao dịch ở máy mà server từ chối khi đồng bộ (đánh dấu failed sau nhiều lần thử)
final failedSyncCountProvider = FutureProvider.autoDispose<int>((ref) => ref.watch(databaseProvider).failedSyncCount());

/// Báo khi có giao dịch ghi ở máy nhưng server từ chối: chúng không bị xóa, chỉ chưa lên được máy chủ nên cần xem lại
class FailedSyncBanner extends ConsumerWidget {
  const FailedSyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(failedSyncCountProvider).valueOrNull ?? 0;
    if (count == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(LucideIcons.triangleAlert, size: 18, color: AppColors.warning),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$count giao dịch chưa đồng bộ được lên máy chủ. Chúng vẫn nằm trên máy này, bạn kiểm tra lại giúp mình nhé.',
            style: AppTypography.caption(context),
          ),
        ),
      ]),
    );
  }
}
