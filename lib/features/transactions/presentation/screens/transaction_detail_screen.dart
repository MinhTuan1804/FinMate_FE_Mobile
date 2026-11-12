import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:finmate/features/transactions/presentation/widgets/draft_edit_sheet.dart';

/// Màn D2: Chi tiết / Sửa giao dịch (Transaction Detail Screen)
class TransactionDetailScreen extends ConsumerStatefulWidget {
  final TransactionEntity transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  ConsumerState<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends ConsumerState<TransactionDetailScreen> {
  late TransactionEntity _tx = widget.transaction;

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
        content: const Text('Hành động này sẽ xóa giao dịch và khôi phục lại số dư các tài khoản liên quan.'),
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

  @override
  Widget build(BuildContext context) {
    final isExpense = _tx.type == TransactionType.expense;
    final isTransfer = _tx.isInternalTransfer;
    final typeColor = isTransfer
        ? AppColors.transfer
        : (isExpense ? AppColors.expense : AppColors.income);
    final prefix = isTransfer ? '' : (isExpense ? '-' : '+');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết giao dịch'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.pencil),
            tooltip: 'Sửa giao dịch',
            onPressed: _handleEdit,
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, color: AppColors.danger),
            tooltip: 'Xóa',
            onPressed: _handleDelete,
          ),
        ],
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Amount Card
              ZenvestHeroDeck(
                peekBadgeText: isTransfer ? 'TRF' : (isExpense ? 'OUT' : 'IN'),
                child: LiquidGlassCard(
                  variant: LiquidGlassVariant.iridescentHero,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: typeColor.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            isTransfer
                                ? LucideIcons.arrowLeftRight
                                : (isExpense ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight),
                            size: 28,
                            color: typeColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _tx.description.isNotEmpty ? _tx.description : 'Giao dịch không tên',
                        textAlign: TextAlign.center,
                        style: AppTypography.h2(context).copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$prefix${_tx.formattedAmount}',
                        style: AppTypography.displayBalance(context).copyWith(
                          color: typeColor,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: AppSpacing.roundedPill,
                        ),
                        child: Text(
                          isTransfer
                              ? 'Chuyển tiền nội bộ'
                              : (isExpense ? 'Chi tiêu cá nhân' : 'Thu nhập'),
                          style: TextStyle(
                            color: typeColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Transaction Metadata Sheet
              ZenvestSurfaceSheet(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _infoRow(
                      context,
                      icon: LucideIcons.calendar,
                      label: 'Thời gian',
                      value: DateFormat('HH:mm - dd/MM/yyyy').format(_tx.date),
                    ),
                    const Divider(height: 24),
                    _infoRow(
                      context,
                      icon: LucideIcons.tag,
                      label: 'Danh mục',
                      value: _tx.categoryName ?? 'Chưa phân loại',
                    ),
                    const Divider(height: 24),
                    _infoRow(
                      context,
                      icon: LucideIcons.wallet,
                      label: 'Tài khoản thanh toán',
                      value: _tx.accountId.isNotEmpty ? _tx.accountId : 'Ví chính',
                    ),
                    const Divider(height: 24),
                    _infoRow(
                      context,
                      icon: LucideIcons.cloudCheck,
                      label: 'Trạng thái đồng bộ',
                      value: _tx.isSynced ? 'Đã đồng bộ máy chủ' : 'Lưu trữ ngoại tuyến',
                      valueColor: _tx.isSynced ? AppColors.safe : AppColors.warning,
                    ),
                    if (_tx.description.isNotEmpty) ...[
                      const Divider(height: 24),
                      _infoRow(
                        context,
                        icon: LucideIcons.fileText,
                        label: 'Ghi chú thêm',
                        value: _tx.description,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(LucideIcons.pencil, size: 16),
                      label: const Text('Chỉnh sửa'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _handleEdit,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(LucideIcons.share2, size: 16),
                      label: const Text('Chia sẻ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAction(context),
                        foregroundColor: AppColors.onPrimaryAction(context),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép thông tin biên lai')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted(context)),
        const SizedBox(width: 12),
        Text(
          label,
          style: AppTypography.caption(context).copyWith(
            fontSize: 13,
            color: AppColors.textSecondary(context),
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTypography.body(context).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: valueColor ?? AppColors.textPrimary(context),
            ),
          ),
        ),
      ],
    );
  }
}
