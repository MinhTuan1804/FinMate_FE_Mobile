import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';

/// Sửa một nháp rồi xác nhận ngay: `saveDraft` (PATCH) và `confirmDraft`.
/// Đóng sheet và trả `true` khi cả hai thành công.
class DraftEditSheet extends ConsumerStatefulWidget {
  final TransactionEntity draft;

  const DraftEditSheet({super.key, required this.draft});

  static Future<bool?> show(BuildContext context, TransactionEntity draft) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      // Đóng chỉ qua nút Hủy/Back (PopScope chặn lúc đang lưu): chạm nền hay kéo xuống giữa lúc đang gửi sẽ
      // khiến pop(true) sau khi lưu xong đóng nhầm màn hình bên dưới.
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => DraftEditSheet(draft: draft),
    );
  }

  @override
  ConsumerState<DraftEditSheet> createState() => _DraftEditSheetState();
}

class _DraftEditSheetState extends ConsumerState<DraftEditSheet> {
  late final _amount = TextEditingController(text: widget.draft.amountCents.toString());
  late final _merchant = TextEditingController(text: widget.draft.merchantName ?? '');
  late final _note = TextEditingController(text: widget.draft.description);
  late TransactionType _type = widget.draft.type;
  late String? _categoryId = widget.draft.categoryId;
  late String? _accountId = widget.draft.accountId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(List<FinancialAccount> accounts) async {
    if (_saving) return;
    final amount = parseAmountInput(_amount.text);
    final accountId = accounts.any((a) => a.id == _accountId) ? _accountId : accounts.firstOrNull?.id;
    if (amount == null) {
      setState(() => _error = 'Vui lòng nhập số tiền hợp lệ');
      return;
    }
    if (accountId == null) {
      setState(() => _error = 'Bạn cần có ít nhất một tài khoản để lưu giao dịch');
      return;
    }

    final navigator = Navigator.of(context);
    final controller = ref.read(transactionControllerProvider.notifier);
    final merchant = _merchant.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    var saved = false;
    try {
      await controller.saveDraft(
        id: widget.draft.id,
        accountId: accountId,
        categoryId: _categoryId,
        amountCents: amount,
        type: _type,
        date: widget.draft.date,
        merchantName: merchant.isEmpty ? null : merchant,
        description: _note.text.trim(),
      );
      saved = true;
      await controller.confirmDraft(widget.draft.id);
      if (!mounted) return;
      navigator.pop(true);
    } catch (e) {
      // Lưu được mà xác nhận lỗi: nháp đã cập nhật vẫn nằm trong danh sách, sheet mở lại để thử xác nhận
      if (mounted) setState(() => _error = saved ? 'Đã lưu chỉnh sửa nhưng chưa xác nhận được: ${errorMessage(e)}' : errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accounts = ref.watch(accountsControllerProvider).valueOrNull ?? const <FinancialAccount>[];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final media = MediaQuery.of(context);
    final accountValue = accounts.any((a) => a.id == _accountId) ? _accountId : accounts.firstOrNull?.id;

    // Đẩy sheet lên trên bàn phím để không che ô nhập
    return PopScope(
      canPop: !_saving,
      child: Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9 - media.viewInsets.bottom),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: AppSpacing.rLarge),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sửa giao dịch chờ duyệt', style: AppTypography.h3(context)),
                const SizedBox(height: AppSpacing.lg),
                // Nháp từ thông báo chỉ là thu/chi; chuyển tiền nội bộ không đổi qua đây
                Row(
                  children: [
                    for (final (label, type) in const [('Chi tiêu', TransactionType.expense), ('Thu nhập', TransactionType.income)]) ...[
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text(label)),
                          selected: _type == type,
                          onSelected: _saving || widget.draft.type == TransactionType.transfer ? null : (v) => v ? setState(() => _type = type) : null,
                        ),
                      ),
                      if (type == TransactionType.expense) const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  key: const ValueKey('draft-amount'),
                  controller: _amount,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Số tiền (VNĐ)', prefixIcon: Icon(LucideIcons.coins, size: 20)),
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String?>(
                  key: ValueKey('cat-$_categoryId-${categories.length}'),
                  initialValue: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Danh mục', prefixIcon: Icon(LucideIcons.tag, size: 20)),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Chưa phân loại')),
                    for (final c in categories)
                      DropdownMenuItem<String?>(
                        value: c.id,
                        child: Row(children: [
                          Icon(categoryIcon(c.slug), size: 18),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                  ],
                  onChanged: _saving ? null : (v) => setState(() => _categoryId = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  key: ValueKey('acc-$accountValue-${accounts.length}'),
                  initialValue: accountValue,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tài khoản', prefixIcon: Icon(LucideIcons.wallet, size: 20)),
                  items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))],
                  onChanged: _saving ? null : (v) => setState(() => _accountId = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _merchant,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Cửa hàng / đối tác', prefixIcon: Icon(LucideIcons.store, size: 20)),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _note,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(LucideIcons.fileText, size: 20)),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Text(_error!, textAlign: TextAlign.center, style: AppTypography.body(context).copyWith(color: AppColors.danger)),
                  ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: _saving ? null : () => _submit(accounts),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Lưu & xác nhận'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Hủy'),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
