import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:finmate/features/assistant/presentation/screens/transaction_review_screen.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';

/// Nền kính của bong bóng/thẻ trợ lý (Figma E1: nền sáng mờ, viền trắng, bóng xanh nhạt)
BoxDecoration _glassDecoration(BuildContext context, {BorderRadius? radius}) {
  final isDark = AppColors.isDark(context);
  return BoxDecoration(
    color: isDark ? AppColors.glassFillDark : AppColors.glassFillLight,
    borderRadius: radius ?? BorderRadius.circular(24),
    border: Border.all(color: AppColors.glassBorder(context)),
    boxShadow: [
      BoxShadow(
        color: AppColors.slateOn(context).withValues(alpha: 0.08),
        blurRadius: 32,
        spreadRadius: -8,
        offset: const Offset(0, 12),
      ),
    ],
  );
}

BoxDecoration _cardDecoration(BuildContext context) =>
    _glassDecoration(context);

/// Góc bo của bong bóng trợ lý: góc dưới trái nhọn
const _assistantRadius = BorderRadius.only(
  topLeft: Radius.circular(22),
  topRight: Radius.circular(22),
  bottomRight: Radius.circular(22),
  bottomLeft: Radius.circular(6),
);

/// Khối nền con bên trong thẻ (vùng số dư, tổng kết...)
BoxDecoration _insetDecoration(BuildContext context) => BoxDecoration(
  color: AppColors.isDark(context)
      ? AppColors.glassFillSubtleDark
      : AppColors.glassFillSubtleLight,
  borderRadius: BorderRadius.circular(24),
  border: Border.all(color: AppColors.glassBorder(context)),
);

/// Avatar sparkle nhỏ đứng cạnh mỗi tin nhắn của trợ lý
class AiAvatar extends StatelessWidget {
  const AiAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.glassBorder(context)),
      ),
      child: Icon(
        LucideIcons.sparkles,
        size: 14,
        color: AppColors.textPrimary(context),
      ),
    );
  }
}

/// Dòng tin nhắn của trợ lý: avatar bên trái, nội dung bên phải
class AiRow extends StatelessWidget {
  final Widget child;
  const AiRow({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: ExcludeSemantics(child: AiAvatar()),
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Bong bóng của người dùng: nền màu hành động chính, góc dưới phải nhọn; [time] là giờ hiển thị kèm dấu đã gửi
class UserBubble extends StatelessWidget {
  final String text;
  final String? time;
  const UserBubble({super.key, required this.text, this.time});

  @override
  Widget build(BuildContext context) {
    final onAction = AppColors.onPrimaryAction(context);
    return Padding(
      padding: const EdgeInsets.only(left: 40, top: 4, bottom: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.primaryAction(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(6),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryAction(context).withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                text,
                style: AppTypography.body(
                  context,
                ).copyWith(color: onAction, height: 1.625),
              ),
              if (time != null) ...[
                const SizedBox(height: 4),
                ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time!,
                        style: TextStyle(
                          fontSize: 10,
                          color: onAction.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.checkCheck,
                        size: 13,
                        color: onAction.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ảnh hóa đơn đã gửi, hiện bên phải như tin nhắn của người dùng
class ImageBubble extends StatelessWidget {
  final String path;
  const ImageBubble({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        width: 200,
        constraints: const BoxConstraints(maxHeight: 260),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(
              height: 80,
              child: Center(child: Icon(LucideIcons.imageOff)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bong bóng văn bản của trợ lý (kính sáng, góc dưới trái nhọn). Màn chat bọc thêm [AiRow].
class AssistantBubble extends StatelessWidget {
  final String text;
  const AssistantBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
        decoration: _glassDecoration(context, radius: _assistantRadius),
        child: Text(
          text,
          style: AppTypography.body(context).copyWith(height: 1.625),
        ),
      ),
    );
  }
}

/// Thẻ "Đã ghi giao dịch" khi chatbot tự lưu: lời xác nhận + thẻ giao dịch (Figma E1)
class SavedCardView extends ConsumerWidget {
  final TransactionEntity tx;
  const SavedCardView({super.key, required this.tx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = tx.type == TransactionType.expense;
    final color = isExpense ? AppColors.expense : AppColors.income;
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final accounts =
        ref.watch(accountsControllerProvider).valueOrNull ??
        const <FinancialAccount>[];
    final slug = categories
        .where((c) => c.id == tx.categoryId)
        .map((c) => c.slug)
        .firstOrNull;
    final accountName = accounts
        .where((a) => a.id == tx.accountId)
        .map((a) => a.name)
        .firstOrNull;
    final title = tx.description.isNotEmpty
        ? tx.description
        : (tx.merchantName ?? 'Giao dịch');
    final secondary = AppTypography.caption(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          decoration: _glassDecoration(context, radius: _assistantRadius),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'Đã ghi nhận giao dịch thành công!',
                  style: AppTypography.bodyMedium(context),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.circleCheck,
                size: 16,
                color: AppColors.safe,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: _glassDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      categoryIcon(slug),
                      size: 20,
                      color: AppColors.slateOn(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLarge(
                            context,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (accountName != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.wallet,
                                    size: 12,
                                    color: secondary.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(accountName, style: secondary),
                                ],
                              ),
                            Text(
                              tx.categoryName ?? 'Chưa phân loại',
                              style: secondary.copyWith(
                                color: AppColors.slateOn(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isExpense ? '-' : '+'}${tx.formattedAmount}',
                        style: AppTypography.tabular(
                          AppTypography.bodyLarge(
                            context,
                          ).copyWith(color: color, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        _dateLabel(tx.date) ?? 'Hôm nay',
                        style: secondary.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              if (tx.balanceAfterCents != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: _insetDecoration(context),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.safe,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Số dư sau giao dịch',
                          style: AppTypography.caption(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                      Text(
                        formatVnd(tx.balanceAfterCents!),
                        style: AppTypography.tabular(
                          AppTypography.bodyMedium(context).copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.safe,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context.push('/transactions'),
                  icon: const Icon(LucideIcons.receipt, size: 14),
                  label: const Text('Xem giao dịch'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Thẻ số liệu tóm tắt (chatbot trả lời câu hỏi về chi tiêu)
class SummaryCardView extends StatelessWidget {
  final ChatSummary summary;
  const SummaryCardView({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.caption(context)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: AppTypography.tabular(
                AppTypography.bodyMedium(
                  context,
                ).copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(17),
      decoration: _glassDecoration(context, radius: _assistantRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tóm tắt chi tiêu ${summary.periodLabel}',
            style: AppTypography.bodyMedium(
              context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: _insetDecoration(context),
            child: Column(
              children: [
                row('Tổng chi', formatVnd(summary.expenseCents)),
                if (summary.incomeCents > BigInt.zero)
                  row(
                    'Tổng thu',
                    formatVnd(summary.incomeCents),
                    color: AppColors.income,
                  ),
                row(
                  'Còn lại',
                  formatVnd(summary.leftCents),
                  color: summary.leftCents < BigInt.zero
                      ? AppColors.danger
                      : AppColors.safe,
                ),
              ],
            ),
          ),
          if (summary.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final item in summary.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        categoryIcon(item.slug),
                        size: 14,
                        color: AppColors.slateOn(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        style: AppTypography.body(context),
                      ),
                    ),
                    Text(
                      '${(item.share * 100).round()}%',
                      style: AppTypography.caption(context),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatVnd(item.amountCents),
                      style: AppTypography.tabular(AppTypography.body(context)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// "Ngày 05/01" cho bản nháp có ngày khác hôm nay (thêm năm nếu khác năm nay); null nếu là hôm nay hoặc không có ngày
String? _dateLabel(DateTime? date) {
  if (date == null) return null;
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day)
    return null;
  final day =
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  return date.year == now.year ? 'Ngày $day' : 'Ngày $day/${date.year}';
}

/// Thẻ bản nháp cần xác nhận/bổ sung trước khi lưu
class DraftCardView extends ConsumerWidget {
  final DraftCard card;
  const DraftCardView({super.key, required this.card});

  static String _fieldLabel(String field) => switch (field) {
    'category' => 'danh mục',
    'accounts' => 'tài khoản',
    'amount' => 'số tiền',
    _ => field,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = card.draft;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final categoryName = categories
        .where((c) => c.slug == draft.categorySlug)
        .map((c) => c.name)
        .firstOrNull;
    final isTransfer = draft.kind == DraftKind.transfer;
    final isSplit =
        !isTransfer &&
        draft.receiptGroups.length >=
            2; // cùng điều kiện với màn rà soát: mỗi nhóm lưu thành một giao dịch
    final dateLabel = _dateLabel(draft.transactedAt);

    Widget warning(String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(
            LucideIcons.triangleAlert,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTypography.caption(
                context,
              ).copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );

    if (card.resolved) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(context),
        child: Row(
          children: [
            const Icon(
              LucideIcons.circleCheck,
              size: 18,
              color: AppColors.safe,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                card.resolvedSummary ?? 'Đã ghi',
                style: AppTypography.body(context),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTransfer
                ? 'Chuyển tiền cần xác nhận'
                : (isSplit
                      ? 'Hóa đơn tách thành ${draft.receiptGroups.length} nhóm'
                      : 'Giao dịch cần xác nhận'),
            style: AppTypography.bodyMedium(
              context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            draft.amountCents == null ? '—' : formatVnd(draft.amountCents!),
            style: AppTypography.tabular(
              AppTypography.h2(context).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          if ((draft.description ?? draft.merchantName) != null)
            Text(
              draft.description ?? draft.merchantName!,
              style: AppTypography.body(context),
            ),
          if (isSplit)
            for (final group in draft.receiptGroups)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      group.categorySlug == null
                          ? LucideIcons.circleHelp
                          : categoryIcon(group.categorySlug!),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        categories
                                .where((c) => c.slug == group.categorySlug)
                                .map((c) => c.name)
                                .firstOrNull ??
                            'Chưa phân loại',
                        style: AppTypography.body(context),
                      ),
                    ),
                    Text(
                      formatVnd(group.amountCents),
                      style: AppTypography.tabular(AppTypography.body(context)),
                    ),
                  ],
                ),
              )
          else if (categoryName != null)
            Text(categoryName, style: AppTypography.caption(context)),
          if (dateLabel != null)
            Text(dateLabel, style: AppTypography.caption(context)),
          if (draft.hasPossibleDuplicate)
            warning(
              draft.hasGroupDuplicate
                  ? 'Có nhóm có thể trùng với một giao dịch bạn vừa ghi (cùng số tiền).'
                  : 'Có thể trùng với một giao dịch bạn vừa ghi (cùng số tiền).',
            ),
          if (draft.needsReview)
            warning(
              'AI chưa chắc về hóa đơn này, nên kiểm tra lại các chi tiết trước khi lưu.',
            ),
          if (draft.missingFields.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  LucideIcons.triangleAlert,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Cần bổ sung: ${draft.missingFields.map(_fieldLabel).join(', ')}',
                    style: AppTypography.caption(
                      context,
                    ).copyWith(color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () => context.push(
                '/assistant/review',
                extra: ReviewArgs(draft, messageId: card.id),
              ),
              child: const Text('Xem và lưu'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ gộp cho câu nhiều khoản: xem các khoản và xác nhận MỘT lần. Khác danh mục thì mỗi khoản là một giao dịch riêng.
/// Dấu của một khoản trong thẻ gộp: thu nhập +1, chi -1, chuyển khoản 0 (không đổi tổng). Không rõ loại thì coi là chi, như [DraftKind] mặc định.
int _signOf(DraftTransaction d) => switch (d.type) {
  TransactionType.income => 1,
  TransactionType.transfer => 0,
  _ => -1,
};

/// "+10.000.000 ₫" / "-1.000.000 ₫"; dấu 0 thì không thêm gì. [cents] là số dương, dấu lấy từ [sign].
String _signedVnd(BigInt cents, int sign) =>
    '${sign > 0
        ? '+'
        : sign < 0
        ? '-'
        : ''}${formatVnd(cents)}';

Color? _signColor(int sign) => sign > 0
    ? AppColors.income
    : sign < 0
    ? AppColors.expense
    : null;

class DraftBatchCardView extends ConsumerWidget {
  final DraftBatchCard card;
  const DraftBatchCardView({super.key, required this.card});

  /// Khung sửa nhanh một dòng: số tiền, ghi chú và danh mục; lưu thì quay lại thẻ gộp
  Future<void> _editRow(
    BuildContext context,
    AssistantController controller,
    List<Category> categories,
    int index,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _RowEditSheet(
        draft: card.drafts[index],
        categories: categories,
        onSave: (amount, note, slug) {
          controller.updateBatchDraft(
            card.id,
            index,
            amountCents: amount,
            description: note,
            categorySlug: slug,
          );
          Navigator.pop(ctx);
        },
      ),
    );
  }

  /// Chọn danh mục chi tiêu cho khoản [index] (không có danh mục thu nhập: đây là khoản chi)
  Future<void> _pickCategory(
    BuildContext context,
    AssistantController controller,
    List<Category> categories,
    int index,
  ) async {
    final slug = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in categories.where((c) => c.slug != 'income'))
              ListTile(
                key: ValueKey('pick-${c.slug}'),
                leading: Icon(categoryIcon(c.slug)),
                title: Text(c.name),
                onTap: () => Navigator.pop(ctx, c.slug),
              ),
          ],
        ),
      ),
    );
    if (slug != null) controller.setBatchCategory(card.id, index, slug);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final sending = ref.watch(
      assistantControllerProvider.select((s) => s.isSending),
    );
    final controller = ref.read(assistantControllerProvider.notifier);
    final total = card.drafts.fold<BigInt>(
      BigInt.zero,
      (a, d) => a + BigInt.from(_signOf(d)) * (d.amountCents ?? BigInt.zero),
    );

    if (card.resolved) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(context),
        child: Row(
          children: [
            const Icon(
              LucideIcons.circleCheck,
              size: 18,
              color: AppColors.safe,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                card.resolvedSummary ?? 'Đã ghi',
                style: AppTypography.body(context),
              ),
            ),
          ],
        ),
      );
    }

    final incomplete = [
      for (final d in card.drafts)
        if (!DraftBatchCard.isSavableAsIs(d)) d,
    ];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xác nhận ${card.drafts.length} khoản',
            style: AppTypography.caption(context),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < card.drafts.length; i++)
            InkWell(
              key: ValueKey('batch-row-$i'),
              onTap: sending
                  ? null
                  : () => _editRow(context, controller, categories, i),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      card.drafts[i].categorySlug == null
                          ? LucideIcons.circleHelp
                          : categoryIcon(card.drafts[i].categorySlug!),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (card.drafts[i].categorySlug == null &&
                              card.drafts[i].type != TransactionType.income)
                            ActionChip(
                              key: ValueKey('batch-pick-$i'),
                              avatar: const Icon(LucideIcons.tag, size: 14),
                              label: const Text('Chọn danh mục'),
                              onPressed: sending
                                  ? null
                                  : () => _pickCategory(
                                      context,
                                      controller,
                                      categories,
                                      i,
                                    ),
                            )
                          else
                            Text(
                              categories
                                      .where(
                                        (c) =>
                                            c.slug ==
                                            card.drafts[i].categorySlug,
                                      )
                                      .map((c) => c.name)
                                      .firstOrNull ??
                                  (card.drafts[i].type == TransactionType.income
                                      ? 'Thu nhập'
                                      : 'Chưa phân loại'),
                              style: AppTypography.body(
                                context,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          if ((card.drafts[i].description ?? '').isNotEmpty)
                            Text(
                              card.drafts[i].description!,
                              style: AppTypography.caption(context),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      card.drafts[i].amountCents == null
                          ? '—'
                          : _signedVnd(
                              card.drafts[i].amountCents!,
                              _signOf(card.drafts[i]),
                            ),
                      style: AppTypography.tabular(
                        AppTypography.body(context),
                      ).copyWith(color: _signColor(_signOf(card.drafts[i]))),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(),
          Row(
            children: [
              Expanded(child: Text('Tổng', style: AppTypography.body(context))),
              Text(
                _signedVnd(total.abs(), total.sign),
                style: AppTypography.tabular(
                  AppTypography.body(context).copyWith(
                    fontWeight: FontWeight.w700,
                    color: _signColor(total.sign),
                  ),
                ),
              ),
            ],
          ),
          if (incomplete.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.triangleAlert,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Cần bổ sung thông tin cho ${incomplete.length} khoản trước khi lưu',
                      style: AppTypography.caption(
                        context,
                      ).copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          if (card.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                card.error!,
                style: AppTypography.caption(
                  context,
                ).copyWith(color: AppColors.danger),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                key: const ValueKey('batch-split'),
                onPressed: sending
                    ? null
                    : () => controller.splitBatch(card.id),
                child: const Text('Sửa từng khoản'),
              ),
              if (incomplete.isEmpty) ...[
                ElevatedButton(
                  key: const ValueKey('batch-save'),
                  onPressed: sending
                      ? null
                      : () => controller.confirmBatch(card.id),
                  child: const Text('Lưu tất cả'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Thẻ xác nhận mục tiêu tiết kiệm từ câu chat. Hiện ngày hạn cụ thể (kèm cụm người dùng đã nói) để họ soát; không bao giờ tự tạo.
class GoalDraftCardView extends ConsumerWidget {
  final GoalDraftCard card;
  const GoalDraftCardView({super.key, required this.card});

  Future<void> _edit(
    BuildContext context,
    AssistantController controller,
  ) async {
    final result = await showModalBottomSheet<(String, BigInt)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GoalEditSheet(goal: card.goal),
    );
    if (result != null)
      controller.updateGoal(card.id, name: result.$1, targetCents: result.$2);
  }

  Future<void> _pickDeadline(
    BuildContext context,
    AssistantController controller,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: card.goal.deadline ?? now.add(const Duration(days: 90)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 30)),
    );
    if (picked != null)
      controller.updateGoal(
        card.id,
        deadline: DateTime(picked.year, picked.month, picked.day, 23, 59, 59),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(assistantControllerProvider.notifier);
    final goal = card.goal;

    if (card.status == GoalCardStatus.created ||
        card.status == GoalCardStatus.cancelled) {
      final created = card.status == GoalCardStatus.created;
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(context),
        child: Row(
          children: [
            Icon(
              created ? LucideIcons.circleCheck : LucideIcons.circleX,
              size: 18,
              color: created ? AppColors.safe : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                created
                    ? 'Đã tạo mục tiêu "${goal.name}" (${formatVnd(goal.targetCents)}). Xem ở tab Kế hoạch.'
                    : 'Đã hủy, mình không tạo mục tiêu nào.',
                style: AppTypography.body(context),
              ),
            ),
          ],
        ),
      );
    }

    final saving = card.status == GoalCardStatus.saving;
    final perMonth = goal.requiredPerMonth();
    final deadline = goal.deadline;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mục tiêu tiết kiệm mới', style: AppTypography.caption(context)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.target, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      key: const ValueKey('goal-name-text'),
                      style: AppTypography.body(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (goal.nameIsDefault)
                      Text(
                        'Mình đặt tên tạm, bấm Sửa để đổi tên',
                        style: AppTypography.caption(context),
                      ),
                  ],
                ),
              ),
              Text(
                formatVnd(goal.targetCents),
                key: const ValueKey('goal-target-text'),
                style: AppTypography.tabular(AppTypography.body(context)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.calendar, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  deadline == null
                      ? 'Chưa có hạn'
                      : 'Hạn: ${DateFormat('dd/MM/yyyy').format(deadline)}${goal.deadlineText == null ? '' : ' (${goal.deadlineText})'}',
                  key: const ValueKey('goal-deadline-text'),
                  style: AppTypography.body(context),
                ),
              ),
              TextButton(
                key: const ValueKey('goal-deadline'),
                onPressed: saving
                    ? null
                    : () => _pickDeadline(context, controller),
                child: Text(deadline == null ? 'Thêm hạn' : 'Đổi hạn'),
              ),
            ],
          ),
          if (perMonth != null)
            Text(
              'Cần ~${formatVnd(perMonth)}/tháng',
              key: const ValueKey('goal-per-month'),
              style: AppTypography.caption(context),
            ),
          if (card.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                card.error!,
                style: AppTypography.caption(
                  context,
                ).copyWith(color: AppColors.danger),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                key: const ValueKey('goal-cancel'),
                onPressed: saving ? null : () => controller.cancelGoal(card.id),
                child: const Text('Hủy'),
              ),
              TextButton(
                key: const ValueKey('goal-edit'),
                onPressed: saving ? null : () => _edit(context, controller),
                child: const Text('Sửa'),
              ),
              ElevatedButton(
                key: const ValueKey('goal-create'),
                onPressed: saving
                    ? null
                    : () => controller.confirmGoal(card.id),
                child: Text(saving ? 'Đang tạo...' : 'Tạo mục tiêu'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Thẻ khoản ĐỊNH mua từ câu "mua X được không?". Không ghi chi tiêu; thẻ tự hỏi backend và hiện kết luận ngay trên thẻ ("Thử lại" chỉ khi lỗi).
class PurchaseCardView extends ConsumerWidget {
  final PurchaseCard card;
  const PurchaseCardView({super.key, required this.card});

  static (String, Color?, IconData) _verdictStyle(String verdict) =>
      switch (verdict) {
        'fits_plan' => (
          'Phù hợp kế hoạch',
          AppColors.safe,
          LucideIcons.circleCheck,
        ),
        'off_plan' => (
          'Đủ tiền nhưng lệch kế hoạch',
          AppColors.warning,
          LucideIcons.triangleAlert,
        ),
        'consider' => (
          'Nên cân nhắc',
          AppColors.warning,
          LucideIcons.triangleAlert,
        ),
        'shortfall_risk' => (
          'Có nguy cơ thiếu tiền',
          AppColors.danger,
          LucideIcons.circleX,
        ),
        _ => ('Chưa đủ dữ liệu để kết luận', null, LucideIcons.circleHelp),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(assistantControllerProvider.notifier);
    final purchase = card.purchase;
    final assessment = card.assessment;

    if (card.status == PurchaseCardStatus.cancelled) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(context),
        child: Row(
          children: [
            const Icon(LucideIcons.circleX, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Đã bỏ qua, mình không ghi gì.',
                style: AppTypography.body(context),
              ),
            ),
          ],
        ),
      );
    }

    final checking = card.status == PurchaseCardStatus.checking;
    final date = purchase.purchaseDate;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Khoản định mua', style: AppTypography.caption(context)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.shoppingBag, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  purchase.item ?? 'Khoản chưa đặt tên',
                  key: const ValueKey('purchase-item'),
                  style: AppTypography.body(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                formatVnd(purchase.amountCents),
                key: const ValueKey('purchase-amount'),
                style: AppTypography.tabular(AppTypography.body(context)),
              ),
            ],
          ),
          if (date != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Ngày mua: ${DateFormat('dd/MM/yyyy').format(date)}',
                style: AppTypography.caption(context),
              ),
            ),
          if (assessment != null) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final (title, color, icon) = _verdictStyle(assessment.verdict);
                return Row(
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        key: const ValueKey('purchase-verdict'),
                        style: AppTypography.bodyMedium(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (assessment.summary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  assessment.summary,
                  style: AppTypography.body(context),
                ),
              ),
            for (final warning in assessment.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      LucideIcons.triangleAlert,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        warning,
                        style: AppTypography.caption(
                          context,
                        ).copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            if (assessment.maxAffordableCents != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Mức mua tối đa lúc này: ${formatVnd(assessment.maxAffordableCents!)}',
                  style: AppTypography.caption(context),
                ),
              ),
            if (assessment.earliestSafeDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Ngày an toàn sớm nhất: ${DateFormat('dd/MM/yyyy').format(assessment.earliestSafeDate!)}',
                  style: AppTypography.caption(context),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Chỉ để tham khảo, mình không ghi khoản này vào chi tiêu.',
              style: AppTypography.caption(context),
            ),
          ] else if (checking) ...[
            const SizedBox(height: 12),
            Row(
              key: const ValueKey('purchase-checking'),
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text('Đang đánh giá...', style: AppTypography.body(context)),
              ],
            ),
          ] else ...[
            // Chỉ tới đây khi lần đánh giá tự động bị lỗi: cho thử lại hoặc bỏ qua
            if (card.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  card.error!,
                  style: AppTypography.caption(
                    context,
                  ).copyWith(color: AppColors.danger),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  key: const ValueKey('purchase-cancel'),
                  onPressed: () => controller.cancelPurchase(card.id),
                  child: const Text('Bỏ qua'),
                ),
                ElevatedButton(
                  key: const ValueKey('purchase-assess'),
                  onPressed: () => controller.assessPurchase(card.id),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalEditSheet extends StatefulWidget {
  final GoalDraft goal;
  const _GoalEditSheet({required this.goal});

  @override
  State<_GoalEditSheet> createState() => _GoalEditSheetState();
}

class _GoalEditSheetState extends State<_GoalEditSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.goal.name,
  );
  late final TextEditingController _amount = TextEditingController(
    text: formatAmountDigits(widget.goal.targetCents),
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final parsed = parseAmountInput(_amount.text);
    if (parsed == null) {
      setState(() => _error = 'Nhập số tiền hợp lệ (lớn hơn 0)');
      return;
    }
    Navigator.pop(context, (_name.text.trim(), parsed));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('goal-name'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Tên mục tiêu'),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('goal-amount'),
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsSeparatorInputFormatter()],
            decoration: InputDecoration(
              labelText: 'Số tiền mục tiêu (₫)',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              key: const ValueKey('goal-edit-save'),
              onPressed: _save,
              child: const Text('Xong'),
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorNoteView extends StatelessWidget {
  final ErrorNote note;
  final VoidCallback onRetry;
  const ErrorNoteView({super.key, required this.note, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: AppSpacing.roundedMedium,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.alertCircle,
            size: 18,
            color: AppColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note.message,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
          if (note.retryText != null)
            TextButton(onPressed: onRetry, child: const Text('Gửi lại')),
        ],
      ),
    );
  }
}

/// Khung sửa một dòng của thẻ gộp. Tự giữ và hủy các ô nhập, nên đóng khung (đang chạy hiệu ứng) không dùng ô đã hủy.
class _RowEditSheet extends StatefulWidget {
  final DraftTransaction draft;
  final List<Category> categories;
  final void Function(BigInt amount, String note, String? categorySlug) onSave;

  const _RowEditSheet({
    required this.draft,
    required this.categories,
    required this.onSave,
  });

  @override
  State<_RowEditSheet> createState() => _RowEditSheetState();
}

class _RowEditSheetState extends State<_RowEditSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.draft.amountCents == null
        ? ''
        : formatAmountDigits(widget.draft.amountCents!),
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.draft.description ?? '',
  );
  late String? _slug = widget.draft.categorySlug;
  String? _error;

  bool get _isIncome => widget.draft.type == TransactionType.income;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final parsed = parseAmountInput(_amount.text);
    if (parsed == null) {
      setState(() => _error = 'Nhập số tiền hợp lệ (lớn hơn 0)');
      return;
    }
    widget.onSave(parsed, _note.text.trim(), _isIncome ? null : _slug);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('edit-amount'),
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsSeparatorInputFormatter()],
            decoration: InputDecoration(
              labelText: 'Số tiền (₫)',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('edit-note'),
            controller: _note,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
          ),
          if (!_isIncome) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in widget.categories.where(
                  (c) => c.slug != 'income',
                ))
                  ChoiceChip(
                    key: ValueKey('edit-cat-${c.slug}'),
                    label: Text(c.name),
                    selected: _slug == c.slug,
                    onSelected: (_) => setState(() => _slug = c.slug),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              key: const ValueKey('edit-save'),
              onPressed: _save,
              child: const Text('Xong'),
            ),
          ),
        ],
      ),
    );
  }
}
