import 'package:flutter/material.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/finance_methods/domain/finance_models.dart';

/// Khung thẻ dùng chung của luồng quản lý tài chính: cùng bề mặt, viền và bo góc với các thẻ ở trang chủ.
class FinanceCard extends StatelessWidget {
  const FinanceCard({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpacing.lg)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Material (không phải Container có nền) để ListTile/ExpansionTile bên trong có chỗ vẽ hiệu ứng chạm.
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.roundedMedium,
          side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Nhãn nhỏ viết hoa đứng trên một khối (cùng kiểu với "GIAO DỊCH GẦN ĐÂY" ở trang chủ).
class FinanceSectionLabel extends StatelessWidget {
  const FinanceSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
    );
  }
}

/// Màn lỗi dùng chung: nói rõ lỗi gì và cho thử lại (hoặc làm việc khác qua [secondary]).
class FinanceFailure extends StatelessWidget {
  const FinanceFailure({super.key, required this.message, required this.onRetry, this.secondary});

  final String message;
  final VoidCallback onRetry;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: AppTypography.body(context).copyWith(color: AppColors.danger)),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
            if (secondary != null) ...[const SizedBox(height: AppSpacing.sm), secondary!],
          ],
        ),
      ),
    );
  }
}

/// Phần chi tiết của một cách quản lý: vì sao hợp, các bước khởi đầu và tham số kèm giá trị mặc định (chưa phải giá trị người dùng đã chỉnh).
class MethodDetails extends StatelessWidget {
  const MethodDetails({super.key, required this.method, this.showWhy = true});

  final FinanceMethod method;
  final bool showWhy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showWhy && method.whyText.isNotEmpty) ...[
          Text(method.whyText, style: AppTypography.body(context)),
          const SizedBox(height: AppSpacing.md),
        ],
        if (method.starterSteps.isNotEmpty) ...[
          Text('Các bước khởi đầu', style: AppTypography.bodyMedium(context)),
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < method.starterSteps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text('${i + 1}. ${method.starterSteps[i]}', style: AppTypography.body(context)),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (method.params.isNotEmpty) ...[
          Text('Tham số mặc định', style: AppTypography.bodyMedium(context)),
          const SizedBox(height: AppSpacing.xs),
          for (final param in method.params)
            Text('${param.label}: ${param.format(param.defaultValue)}', style: AppTypography.caption(context)),
        ],
      ],
    );
  }
}
