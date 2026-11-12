import 'package:flutter/material.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';

/// Một dòng giao dịch (icon theo danh mục + tên/phụ đề + số tiền) — dùng chung cho danh sách
/// "Giao dịch gần đây" ở trang chủ (B1) và chi tiết hũ (B6).
class GlassTransactionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String amountText;
  final bool isExpense;

  const GlassTransactionRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amountText,
    required this.isExpense,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: GlassTypography.bodySm()),
              ],
            ),
          ),
          Text(
            amountText,
            style: GlassTypography.labelNumeric(color: isExpense ? GlassColors.danger : GlassColors.success),
          ),
        ],
      ),
    );
  }
}
