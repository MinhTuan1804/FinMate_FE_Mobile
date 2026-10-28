// Nút "Sửa" dùng bottom sheet gọn (draft_edit_sheet.dart), không tái dùng TransactionReviewScreen: ReviewArgs chỉ mang DraftTransaction của AI
// (chưa có id/trạng thái nháp trên server) và đường lưu của màn đó là createTransaction/transferInternal; muốn trỏ sang
// updateDraft+confirmDraft phải sửa nhiều chỗ ở luồng trợ lý.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';

/// Một nháp giao dịch chờ duyệt: số tiền (màu theo thu/chi), người nhận/mô tả, danh mục, ngày và hai nút Xác nhận / Sửa.
class DraftTransactionTile extends StatelessWidget {
  final TransactionEntity draft;

  /// Đang gửi yêu cầu cho nháp này: khoá cả hai nút để không gửi trùng
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;

  const DraftTransactionTile({super.key, required this.draft, required this.busy, required this.onConfirm, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final (color, prefix, icon) = switch (draft.type) {
      TransactionType.expense => (AppColors.expense, '-', LucideIcons.arrowDownLeft),
      TransactionType.income => (AppColors.income, '+', LucideIcons.arrowUpRight),
      TransactionType.transfer => (AppColors.transfer, '', LucideIcons.arrowLeftRight),
    };
    final merchant = draft.merchantName?.trim() ?? '';
    final title = merchant.isNotEmpty ? merchant : (draft.description.isNotEmpty ? draft.description : 'Giao dịch');

    return Column(
      children: [
        ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: AppSpacing.roundedMedium),
            child: Icon(icon, size: 20, color: color),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${draft.categoryName ?? 'Chưa phân loại'} · ${DateFormat('dd/MM/yyyy HH:mm').format(draft.date)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption(context),
          ),
          trailing: Text(
            '$prefix${draft.formattedAmount}',
            style: AppTypography.tabular(AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w700, color: color)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: busy ? null : onEdit,
                icon: const Icon(LucideIcons.pencil, size: 16),
                label: const Text('Sửa'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                onPressed: busy ? null : onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
                ),
                icon: busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.check, size: 16),
                label: const Text('Xác nhận'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
