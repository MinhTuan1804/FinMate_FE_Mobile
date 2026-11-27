import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_links.dart';

/// Một nháp giao dịch chờ duyệt: số tiền (màu theo thu/chi), người nhận/mô tả, danh mục, ngày và hai nút Xác nhận / Sửa.
class DraftTransactionTile extends StatelessWidget {
  final TransactionEntity draft;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;

  const DraftTransactionTile({
    super.key,
    required this.draft,
    required this.busy,
    required this.onConfirm,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final (color, prefix, icon) = switch (draft.type) {
      TransactionType.expense => (
        AppColors.expense,
        '-',
        LucideIcons.arrowDownLeft,
      ),
      TransactionType.income => (
        AppColors.income,
        '+',
        LucideIcons.arrowUpRight,
      ),
      TransactionType.transfer => (
        AppColors.transfer,
        '',
        LucideIcons.arrowLeftRight,
      ),
    };
    final merchant = draft.merchantName?.trim() ?? '';
    final title = merchant.isNotEmpty
        ? merchant
        : (draft.description.isNotEmpty ? draft.description : 'Giao dịch');

    return Column(
      children: [
        ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${draft.categoryName ?? 'Chưa phân loại'} · ${DateFormat('dd/MM/yyyy HH:mm').format(draft.date)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption(context),
          ),
          trailing: Text(
            '$prefix${draft.formattedAmount}',
            style: AppTypography.tabular(
              AppTypography.bodyLarge(
                context,
              ).copyWith(fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ),
        if (draft.links.duplicateCandidate case final dup?) _duplicateBanner(context, dup),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: busy ? null : onEdit,
                icon: const Icon(LucideIcons.pencil, size: 16),
                label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Sửa', maxLines: 1)),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                onPressed: busy ? null : onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryAction(context),
                  foregroundColor: AppColors.onPrimaryAction(context),
                  shape: const StadiumBorder(),
                ),
                icon: busy
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimaryAction(context),
                        ),
                      )
                    : const Icon(LucideIcons.check, size: 16),
                label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Xác nhận', maxLines: 1)),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.border(context)),
      ],
    );
  }

  /// Nháp bị nghi trùng (Phase 82): hiện khoản bị nghi trùng ngay trong danh sách và mở chi tiết để Gộp / Không trùng.
  Widget _duplicateBanner(BuildContext context, DuplicateSummary dup) {
    final what = dup.merchantName ?? dup.categoryName ?? 'một giao dịch';
    final when = dup.transactedAt == null ? '' : ' • ${DateFormat('dd/MM HH:mm').format(dup.transactedAt!)}';
    return Container(
      key: ValueKey('draft-duplicate-${draft.id}'),
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.copy, size: 16, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Có thể trùng với $what • ${formatVnd(dup.amountCents)}$when',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption(context),
            ),
          ),
          TextButton(
            key: ValueKey('draft-duplicate-review-${draft.id}'),
            onPressed: busy ? null : () => context.push('/transaction-detail', extra: draft),
            child: const Text('Xem'),
          ),
        ],
      ),
    );
  }
}
