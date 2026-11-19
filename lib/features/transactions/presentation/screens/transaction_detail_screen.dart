import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:finmate/features/transactions/presentation/widgets/draft_edit_sheet.dart';

/// Màn D2: Chi tiết / Sửa giao dịch (Transaction Detail Screen)
class TransactionDetailScreen extends ConsumerStatefulWidget {
  final TransactionEntity transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  late final TransactionEntity _tx = widget.transaction;

  Future<void> _handleEdit() async {
    final updated = await DraftEditSheet.show(context, _tx);
    if (updated == true && mounted) {
      ref.read(transactionControllerProvider.notifier).loadTransactions();
      context.pop();
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa giao dịch này?'),
        content: const Text(
          'Hành động này sẽ xóa giao dịch và khôi phục lại số dư các tài khoản liên quan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(transactionControllerProvider.notifier).loadTransactions();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa giao dịch thành công'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    }
  }

  BoxDecoration _glass(BuildContext context, double radius) => BoxDecoration(
    color: AppColors.isDark(context)
        ? AppColors.glassFillDark
        : AppColors.glassFillLight,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.glassBorder(context)),
    boxShadow: [
      BoxShadow(
        color: AppColors.slateAction.withValues(alpha: 0.12),
        blurRadius: 32,
        spreadRadius: -8,
        offset: const Offset(0, 12),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final isExpense = _tx.type == TransactionType.expense;
    final isTransfer = _tx.isInternalTransfer;
    final typeColor = isTransfer
        ? AppColors.transferOn(context)
        : (isExpense
              ? AppColors.expenseOn(context)
              : AppColors.incomeOn(context));
    final prefix = isTransfer ? '' : (isExpense ? '-' : '+');
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final slug = categories
        .where((c) => c.id == _tx.categoryId)
        .map((c) => c.slug)
        .firstOrNull;
    final aiSource = _tx.source != 'Manual';
    final isDraft = _tx.status == TransactionStatus.draft;

    return Scaffold(
      body: AmbientGlassBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    LiquidGlassIconButton(
                      icon: LucideIcons.arrowLeft,
                      tooltip: 'Quay lại',
                      iconSize: 18,
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text(
                        'Chi tiết giao dịch',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge(context).copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    LiquidGlassIconButton(
                      icon: LucideIcons.trash2,
                      tooltip: 'Xóa',
                      iconSize: 18,
                      onPressed: _handleDelete,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _hero(
                        context,
                        typeColor: typeColor,
                        prefix: prefix,
                        isTransfer: isTransfer,
                        slug: slug,
                        isDraft: isDraft,
                      ),
                      if (aiSource) ...[
                        const SizedBox(height: 16),
                        _aiBanner(context),
                      ],
                      const SizedBox(height: 16),
                      _details(context),
                      const SizedBox(height: 16),
                      _actions(context),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Mã giao dịch: ${_tx.id.length > 8 ? _tx.id.substring(0, 8).toUpperCase() : _tx.id}',
                          style: AppTypography.caption(context).copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.66,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(
    BuildContext context, {
    required Color typeColor,
    required String prefix,
    required bool isTransfer,
    required String? slug,
    required bool isDraft,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: _glass(context, 40),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white),
            ),
            child: Icon(
              isTransfer ? LucideIcons.arrowLeftRight : categoryIcon(slug),
              size: 24,
              color: AppColors.slateOn(context),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _tx.description.isNotEmpty
                ? _tx.description
                : 'Giao dịch không tên',
            textAlign: TextAlign.center,
            style: AppTypography.h2(context).copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$prefix${_tx.formattedAmount}',
            style: AppTypography.tabular(
              AppTypography.h1(context).copyWith(
                color: typeColor,
                fontSize: 30,
                height: 1.25,
                letterSpacing: -0.75,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surface(context).withValues(alpha: 0.8),
              borderRadius: AppSpacing.roundedPill,
              border: Border.all(color: AppColors.glassBorder(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDraft ? LucideIcons.clock : LucideIcons.circleCheck,
                  size: 14,
                  color: isDraft ? AppColors.warning : AppColors.safe,
                ),
                const SizedBox(width: 6),
                Text(
                  isTransfer
                      ? 'Chuyển tiền nội bộ'
                      : (isDraft ? 'Chờ duyệt' : 'Hoàn tất'),
                  style: AppTypography.caption(context).copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.66,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Chỉ hiện khi giao dịch do AI/OCR/thông báo tạo (nguồn khác nhập tay)
  Widget _aiBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: _glass(context, 32).copyWith(
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.sparkles,
              size: 16,
              color: AppColors.slateOn(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ghi nhận bởi FinMate AI',
                  style: AppTypography.caption(context).copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.66,
                  ),
                ),
                Text(
                  'Tự động trích xuất từ ${_sourceLabel()}',
                  style: AppTypography.caption(
                    context,
                  ).copyWith(color: AppColors.textPrimary(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sourceLabel() => switch (_tx.source) {
    'Voice' => 'giọng nói',
    'Receipt' => 'hóa đơn',
    'Notification' => 'thông báo ngân hàng',
    _ => 'tin nhắn',
  };

  Widget _details(BuildContext context) {
    final secondary = AppColors.textSecondary(context);
    final divider = Divider(height: 1, color: AppColors.glassBorder(context));
    Widget row(IconData icon, String label, Widget value) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Icon(icon, size: 15, color: secondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.body(context).copyWith(color: secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );
    final valueStyle = AppTypography.bodyLarge(
      context,
    ).copyWith(fontWeight: FontWeight.w500, letterSpacing: -0.15);
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _glass(context, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            LucideIcons.calendar,
            'Thời gian',
            Text(
              DateFormat('HH:mm - dd/MM/yyyy').format(_tx.date),
              style: valueStyle,
            ),
          ),
          divider,
          row(
            LucideIcons.tag,
            'Danh mục',
            Text(
              _tx.categoryName ?? 'Chưa phân loại',
              textAlign: TextAlign.end,
              style: valueStyle,
            ),
          ),
          divider,
          row(
            LucideIcons.wallet,
            'Tài khoản thanh toán',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.slateOn(context),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _accountName(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle,
                  ),
                ),
              ],
            ),
          ),
          divider,
          row(
            LucideIcons.cloudCheck,
            'Trạng thái đồng bộ',
            Text(
              _tx.isSynced ? 'Đã đồng bộ máy chủ' : 'Lưu trữ ngoại tuyến',
              textAlign: TextAlign.end,
              style: valueStyle.copyWith(
                color: _tx.isSynced ? AppColors.safe : AppColors.warning,
              ),
            ),
          ),
          if (_tx.description.isNotEmpty) ...[
            divider,
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.fileText, size: 15, color: secondary),
                      const SizedBox(width: 8),
                      Text(
                        'Ghi chú thêm',
                        style: AppTypography.body(
                          context,
                        ).copyWith(color: secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(left: 23),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.glassBorder(context)),
                    ),
                    child: Text(
                      _tx.description,
                      style: AppTypography.body(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final secondaryStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: const StadiumBorder(),
      backgroundColor: AppColors.surface(context).withValues(alpha: 0.72),
      side: BorderSide(color: AppColors.glassBorder(context)),
      foregroundColor: AppColors.textPrimary(context),
    );
    Widget label(IconData icon, String text) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _handleEdit,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
            backgroundColor: AppColors.primaryAction(context),
            foregroundColor: AppColors.onPrimaryAction(context),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.pencil, size: 14),
              SizedBox(width: 8),
              Text(
                'Chỉnh sửa giao dịch',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: secondaryStyle,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sao chép thông tin biên lai'),
                    ),
                  );
                },
                child: label(LucideIcons.share2, 'Chia sẻ'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: secondaryStyle,
                onPressed: () => context.push('/recurring-items'),
                child: label(LucideIcons.repeat, 'Lặp lại định kỳ'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Tên ví thay cho mã (UUID); ví đã xóa hoặc chưa tải được thì ghi rõ thay vì lộ mã.
  String _accountName() {
    if (_tx.accountId.isEmpty) return 'Ví chính';
    final accounts =
        ref.watch(accountsControllerProvider).valueOrNull ?? const [];
    return accounts
            .where((a) => a.id == _tx.accountId)
            .map((a) => a.name)
            .firstOrNull ??
        'Không xác định';
  }
}
