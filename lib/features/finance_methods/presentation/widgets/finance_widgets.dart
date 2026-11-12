import 'package:flutter/material.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/finance_methods/domain/finance_models.dart';

/// Khung thẻ dùng chung của luồng quản lý tài chính: chuẩn Liquid Glass với hiệu năng 60fps cho danh sách.
class FinanceCard extends StatelessWidget {
  const FinanceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.variant = LiquidGlassVariant.standard,
    this.enableBlur = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final LiquidGlassVariant variant;
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    // Bọc Material trong suốt bên trong LiquidGlassCard để ListTile/ExpansionTile vẽ hiệu ứng chạm.
    return SizedBox(
      width: double.infinity,
      child: LiquidGlassCard(
        padding: EdgeInsets.zero,
        variant: variant,
        enableBlur: enableBlur,
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
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
      style: AppTypography.sectionLabel(context),
    );
  }
}

/// Màn lỗi dùng chung: nói rõ lỗi gì và cho thử lại (hoặc làm việc khác qua [secondary]).
class FinanceFailure extends StatelessWidget {
  const FinanceFailure({
    super.key,
    required this.message,
    required this.onRetry,
    this.secondary,
  });

  final String message;
  final VoidCallback onRetry;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: LiquidGlassCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.body(context).copyWith(color: AppColors.danger),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
              if (secondary != null) ...[
                const SizedBox(height: AppSpacing.sm),
                secondary!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Phần chi tiết của một cách quản lý: vì sao hợp, các bước khởi đầu và tham số kèm giá trị mặc định.
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
              child: Text(
                '${i + 1}. ${method.starterSteps[i]}',
                style: AppTypography.body(context),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (method.params.isNotEmpty) ...[
          Text('Tham số mặc định', style: AppTypography.bodyMedium(context)),
          const SizedBox(height: AppSpacing.xs),
          for (final param in method.params)
            Text(
              '${param.label}: ${param.format(param.defaultValue)}',
              style: AppTypography.caption(context),
            ),
        ],
      ],
    );
  }
}
