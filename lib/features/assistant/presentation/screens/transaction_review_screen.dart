import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/assistant/data/transfer_hints.dart';
import 'package:finmate/features/assistant/domain/assistant_models.dart';
import 'package:finmate/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';

/// Tham số mở màn rà soát; [messageId] là thẻ nháp trong chat cần đánh dấu "đã ghi" sau khi lưu
class ReviewArgs {
  final DraftTransaction draft;
  final int? messageId;

  const ReviewArgs(this.draft, {this.messageId});
}

enum _GroupStatus { pending, saving, saved, failed }

/// Một nhóm của hóa đơn đã tách trên màn rà soát. [clientRequestId] suy ra từ lần quét + nhóm, nên thử lại
/// hay mở lại thẻ đều được BE nhận ra là cùng một giao dịch (không tạo trùng nếu lần trước thực ra đã lưu).
class _GroupEntry {
  final ReceiptGroup group;
  final String clientRequestId;
  String? categoryId;
  bool categoryTouched = false;
  bool skipped = false;
  _GroupStatus status = _GroupStatus.pending;
  String? error;

  _GroupEntry(this.group, String? scanId) : clientRequestId = group.requestId(scanId);
}

/// Rà soát và lưu một bản nháp giao dịch do AI trích xuất (chat, giọng nói, hóa đơn)
class TransactionReviewScreen extends ConsumerStatefulWidget {
  final ReviewArgs args;

  const TransactionReviewScreen({super.key, required this.args});

  @override
  ConsumerState<TransactionReviewScreen> createState() => _TransactionReviewScreenState();
}

class _TransactionReviewScreenState extends ConsumerState<TransactionReviewScreen> {
  late final TextEditingController _amount = TextEditingController(text: widget.args.draft.amountCents?.toString() ?? '');
  late final TextEditingController _merchant = TextEditingController(text: widget.args.draft.merchantName ?? '');
  late final TextEditingController _note = TextEditingController(text: widget.args.draft.description ?? '');
  late TransactionType _type = _initialType();
  late DateTime _date = widget.args.draft.transactedAt ?? DateTime.now();

  String? _categoryId;
  bool _categoryTouched = false;
  String? _accountId;
  String? _toAccountId;
  bool _isSaving = false;
  String? _error;

  DraftTransaction get _draft => widget.args.draft;

  /// Hóa đơn từ 2 nhóm trở lên: mỗi nhóm một thẻ và một giao dịch; 0–1 nhóm đi đường cũ
  late final List<_GroupEntry> _groups =
      _draft.kind == DraftKind.expense && _draft.receiptGroups.length >= 2 ? _draft.receiptGroups.map((g) => _GroupEntry(g, _draft.scanId)).toList() : const [];
  bool get _isSplit => _groups.isNotEmpty;
  Iterable<_GroupEntry> get _keptGroups => _groups.where((g) => !g.skipped);

  TransactionType _initialType() {
    if (_draft.kind == DraftKind.transfer) return TransactionType.transfer;
    return _draft.type == TransactionType.income ? TransactionType.income : TransactionType.expense;
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _effectiveCategory(List<Category> categories) {
    if (_categoryTouched) return _categoryId;
    final slug = _draft.categorySlug;
    if (slug == null) return null;
    for (final c in categories) {
      if (c.slug == slug) return c.id;
    }
    return null;
  }

  String? _effectiveAccount(List<FinancialAccount> accounts) {
    if (accounts.isEmpty) return null;
    if (_type == TransactionType.transfer) return _transferPair(accounts).$1;
    for (final candidate in [_accountId, _draft.suggestedAccountId]) {
      if (candidate != null && accounts.any((a) => a.id == candidate)) return candidate;
    }
    return accounts.first.id;
  }

  String? _effectiveToAccount(List<FinancialAccount> accounts, String? from) {
    if (_type == TransactionType.transfer) return _transferPair(accounts).$2;
    if (_toAccountId != null && accounts.any((a) => a.id == _toAccountId)) return _toAccountId;
    for (final a in accounts) {
      if (a.id != from) return a.id;
    }
    return null;
  }

  /// Chuyển tiền: (ví nguồn, ví đích). Người dùng đã chọn thì giữ; chưa thì theo CÂU NÓI ("chuyển sang tiết kiệm" = đích là Tiết kiệm, "rút từ tiết kiệm"
  /// = nguồn là Tiết kiệm), rồi ví đang chọn ở chat, rồi ví đầu tiên. Nguồn và đích không bao giờ tự trùng nhau (người dùng vẫn có thể chọn trùng và sẽ bị báo khi lưu).
  (String?, String?) _transferPair(List<FinancialAccount> accounts) {
    if (accounts.isEmpty) return (null, null);
    bool has(String? id) => id != null && accounts.any((a) => a.id == id);
    final hints = transferAccountHints(_draft.description, accounts);
    final userFrom = has(_accountId) ? _accountId : null;
    final userTo = has(_toAccountId) ? _toAccountId : null;

    var to = userTo ?? hints.toId;
    var from = userFrom;
    if (from == null) {
      for (final candidate in [hints.fromId, _draft.suggestedAccountId]) {
        if (has(candidate) && candidate != to) {
          from = candidate;
          break;
        }
      }
    }
    from ??= accounts.where((a) => a.id != to).map((a) => a.id).firstOrNull ?? accounts.first.id;
    if (to == null || (to == from && userTo == null)) to = accounts.where((a) => a.id != from).map((a) => a.id).firstOrNull;
    return (from, to);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    if (!mounted) return;
    setState(() => _date = DateTime(date.year, date.month, date.day, time?.hour ?? _date.hour, time?.minute ?? _date.minute));
  }

  String? _groupCategory(_GroupEntry g, List<Category> categories) {
    if (g.categoryTouched) return g.categoryId;
    return categories.where((c) => c.slug == g.group.categorySlug).map((c) => c.id).firstOrNull;
  }

  Future<void> _pickGroupCategory(_GroupEntry g, List<Category> categories) async {
    final current = _groupCategory(g, categories);
    final picked = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in categories)
              ListTile(
                leading: Icon(categoryIcon(c.slug), size: 20),
                title: Text(c.name),
                selected: c.id == current,
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      g.categoryTouched = true;
      g.categoryId = picked.id;
    });
  }

  /// Lưu lần lượt các nhóm chưa lưu (bỏ qua nhóm đã bỏ và nhóm đã lưu), nên bấm lại chỉ gửi nhóm lỗi
  Future<void> _saveSplit(List<Category> categories, List<FinancialAccount> accounts) async {
    if (_isSaving) return;
    final account = _effectiveAccount(accounts);
    if (account == null) {
      setState(() => _error = 'Bạn cần có ít nhất một tài khoản để lưu giao dịch');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(transactionControllerProvider.notifier);
    final note = _note.text.trim();
    final merchant = _merchant.text.trim();

    setState(() {
      _isSaving = true;
      _error = null;
    });
    for (final g in _keptGroups.where((g) => g.status != _GroupStatus.saved).toList()) {
      setState(() {
        g.status = _GroupStatus.saving;
        g.error = null;
      });
      try {
        await controller.createTransaction(
          accountId: account,
          categoryId: _groupCategory(g, categories),
          amountCents: g.group.amountCents,
          type: _type,
          merchantName: merchant.isEmpty ? null : merchant,
          description: note,
          date: _date,
          source: _draft.source.apiValue,
          receiptScanId: _draft.scanId,
          // Nhóm gốc của lần quét (kể cả khi người dùng đổi danh mục): BE dùng để chống trùng và đo AI
          receiptGroup: g.group.apiKey,
          clientRequestId: g.clientRequestId,
        );
        g.status = _GroupStatus.saved;
      } catch (e) {
        g.status = _GroupStatus.failed;
        g.error = errorMessage(e);
      }
      if (!mounted) return;
      setState(() {});
    }

    final kept = _keptGroups.toList();
    final saved = kept.where((g) => g.status == _GroupStatus.saved).toList();
    final done = saved.length == kept.length;
    if (done) {
      // Chỉ đánh dấu thẻ chat khi mọi nhóm đã lưu; còn nhóm lỗi thì thẻ vẫn mở lại được (id cố định nên không trùng)
      final messageId = widget.args.messageId;
      if (messageId != null) {
        final total = saved.fold<BigInt>(BigInt.zero, (sum, g) => sum + g.group.amountCents);
        ref.read(assistantControllerProvider.notifier).resolveDraft(messageId, 'Đã ghi ${saved.length} giao dịch: ${formatVnd(total)}');
      }
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Đã ghi nhận ${saved.length} giao dịch thành công!'), backgroundColor: AppColors.safe));
    } else {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _save(List<Category> categories, List<FinancialAccount> accounts) async {
    if (_isSaving) return;
    final isTransfer = _type == TransactionType.transfer;
    final from = _effectiveAccount(accounts);
    final to = _effectiveToAccount(accounts, from);
    final amount = parseAmountInput(_amount.text);

    String? problem;
    if (accounts.isEmpty) {
      problem = 'Bạn cần có ít nhất một tài khoản để lưu giao dịch';
    } else if (isTransfer && accounts.length < 2) {
      problem = 'Cần ít nhất 2 tài khoản để chuyển tiền';
    } else if (amount == null) {
      problem = 'Vui lòng nhập số tiền hợp lệ';
    } else if (isTransfer && from == to) {
      problem = 'Tài khoản nguồn và đích không được trùng nhau';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(transactionControllerProvider.notifier);
    final categoryId = _effectiveCategory(categories);
    final categoryName = categories.where((c) => c.id == categoryId).map((c) => c.name).firstOrNull;
    final note = _note.text.trim();
    final merchant = _merchant.text.trim();

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      if (isTransfer) {
        await controller.transferInternal(amountCents: amount!, fromAccountId: from!, toAccountId: to!, description: note.isEmpty ? 'Chuyển tiền nội bộ' : note, date: _date);
      } else {
        await controller.createTransaction(
          accountId: from!,
          categoryId: categoryId,
          amountCents: amount!,
          type: _type,
          merchantName: merchant.isEmpty ? null : merchant,
          description: note,
          date: _date,
          source: _draft.source.apiValue,
          receiptScanId: _draft.scanId,
        );
      }

      final messageId = widget.args.messageId;
      if (messageId != null) {
        ref.read(assistantControllerProvider.notifier).resolveDraft(
              messageId,
              isTransfer ? 'Đã chuyển: ${formatVnd(amount)}' : 'Đã ghi: ${formatVnd(amount)} · ${categoryName ?? 'Chưa phân loại'}',
              categorySlug: isTransfer ? null : categories.where((c) => c.id == categoryId).firstOrNull?.slug,
            );
      }
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Đã ghi nhận giao dịch thành công!'), backgroundColor: AppColors.safe));
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final accounts = ref.watch(accountsControllerProvider).valueOrNull ?? const <FinancialAccount>[];
    final from = _effectiveAccount(accounts);
    final to = _effectiveToAccount(accounts, from);
    final selectedCategory = _effectiveCategory(categories);
    final isTransfer = _type == TransactionType.transfer;
    final lowConfidence = (_draft.confidence ?? 1.0) < 0.85;
    final needsReview = lowConfidence || _draft.missingFields.isNotEmpty || _draft.needsReview || _draft.hasPossibleDuplicate;

    // Không cho rời màn khi đang lưu, để không bỏ dở một lần lưu đang chạy
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Xác nhận thông tin giao dịch'),
          leading: IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: _isSaving ? null : () => Navigator.of(context).pop()),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (needsReview)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: AppSpacing.roundedMedium,
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.triangleAlert, color: AppColors.warning, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AI cần bạn kiểm tra lại một số chi tiết',
                                style: AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.w600, color: AppColors.warning)),
                            const SizedBox(height: 4),
                            Text(
                              _draft.missingFields.isNotEmpty
                                  ? 'Còn thiếu: ${_draft.missingFields.map(_fieldLabel).join(", ")}. Vui lòng bổ sung trước khi lưu.'
                                  : _draft.hasPossibleDuplicate
                                      ? '${_draft.hasGroupDuplicate ? 'Có nhóm có thể trùng' : 'Giao dịch này có thể trùng'} với một giao dịch bạn đã ghi gần đây (cùng số tiền). Nếu là khoản thứ hai thật, cứ lưu bình thường.'
                                      : lowConfidence
                                          ? 'Độ tin cậy nhận diện: ${((_draft.confidence ?? 0) * 100).round()}%. Vui lòng rà soát lại thông tin.'
                                          : 'AI chưa chắc về hóa đơn này. Vui lòng rà soát lại thông tin.',
                              style: AppTypography.caption(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (_isSplit) ...[
                Text('CÁC NHÓM TRONG HÓA ĐƠN', style: _label(context)),
                const SizedBox(height: 4),
                Text('Tổng hóa đơn ${formatVnd(_draft.amountCents ?? BigInt.zero)} · mỗi nhóm lưu thành một giao dịch', style: AppTypography.caption(context)),
                const SizedBox(height: 8),
                for (final (i, g) in _groups.indexed) _groupCard(i, g, categories),
              ] else ...[
                Text('LOẠI GIAO DỊCH', style: _label(context)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _typeChip('Chi tiêu', TransactionType.expense, AppColors.expense)),
                    const SizedBox(width: 8),
                    Expanded(child: _typeChip('Thu nhập', TransactionType.income, AppColors.income)),
                    const SizedBox(width: 8),
                    Expanded(child: _typeChip('Chuyển tiền', TransactionType.transfer, AppColors.primary)),
                  ],
                ),

                const SizedBox(height: 20),
                Text('SỐ TIỀN (VNĐ)', style: _label(context)),
                const SizedBox(height: 8),
                TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  style: AppTypography.tabular(AppTypography.h2(context).copyWith(fontWeight: FontWeight.w700)),
                  decoration: InputDecoration(prefixIcon: const Icon(LucideIcons.coins, size: 20), suffixText: '₫', suffixStyle: AppTypography.body(context)),
                ),
              ],

              if (!isTransfer && !_isSplit) ...[
                const SizedBox(height: 20),
                Text('DANH MỤC', style: _label(context)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories
                      .map((c) => FilterChip(
                            avatar: Icon(categoryIcon(c.slug), size: 16),
                            label: Text(c.name),
                            selected: selectedCategory == c.id,
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            onSelected: (v) => setState(() {
                              _categoryTouched = true;
                              _categoryId = v ? c.id : null;
                            }),
                          ))
                      .toList(),
                ),
              ],

              const SizedBox(height: 20),
              Text(isTransfer ? 'TỪ TÀI KHOẢN' : 'TÀI KHOẢN', style: _label(context)),
              const SizedBox(height: 8),
              _accountDropdown('from', accounts, from, (v) => setState(() => _accountId = v)),
              if (isTransfer) ...[
                const SizedBox(height: 20),
                Text('ĐẾN TÀI KHOẢN', style: _label(context)),
                const SizedBox(height: 8),
                _accountDropdown('to', accounts, to, (v) => setState(() => _toAccountId = v)),
              ],

              if (!isTransfer) ...[
                const SizedBox(height: 20),
                Text('CỬA HÀNG / ĐỐI TÁC', style: _label(context)),
                const SizedBox(height: 8),
                TextField(controller: _merchant, decoration: const InputDecoration(hintText: 'Ví dụ: WinMart', prefixIcon: Icon(LucideIcons.store, size: 20))),
              ],

              const SizedBox(height: 20),
              Text('GHI CHÚ', style: _label(context)),
              const SizedBox(height: 8),
              TextField(controller: _note, decoration: const InputDecoration(hintText: 'Nhập ghi chú giao dịch...', prefixIcon: Icon(LucideIcons.fileText, size: 20))),

              const SizedBox(height: 20),
              Text('THỜI GIAN', style: _label(context)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(LucideIcons.calendar, size: 18),
                label: Text(DateFormat('dd/MM/yyyy HH:mm').format(_date)),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ),

              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isSaving ? null : () => _isSplit ? _saveSplit(categories, accounts) : _save(categories, accounts),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.check, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _isSplit ? 'Lưu ${_keptGroups.where((g) => g.status != _GroupStatus.saved).length} giao dịch' : 'Xác nhận & Lưu giao dịch',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill)),
                child: const Text('Hủy bỏ bản ghi nháp'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _fieldLabel(String field) => switch (field) {
        'category' => 'danh mục',
        'accounts' => 'tài khoản',
        'amount' => 'số tiền',
        _ => field,
      };

  Widget _groupCard(int index, _GroupEntry g, List<Category> categories) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = categories.where((c) => c.id == _groupCategory(g, categories)).firstOrNull;
    final locked = _isSaving || g.status == _GroupStatus.saved;
    // Phải còn ít nhất một nhóm được lưu
    final canSkip = !locked && (g.skipped || _keptGroups.length > 1);
    final items = g.group.items.map((i) => i.name).where((n) => n.isNotEmpty).join(', ');

    return Opacity(
      key: ValueKey('receipt-group-$index'),
      opacity: g.skipped ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: AppSpacing.roundedMedium,
          border: Border.all(color: g.status == _GroupStatus.failed ? AppColors.danger : (isDark ? AppColors.borderDark : AppColors.borderLight)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(categoryIcon(category?.slug ?? g.group.categorySlug), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(category?.name ?? 'Chưa phân loại', style: AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.w600))),
              Text(formatVnd(g.group.amountCents), style: AppTypography.tabular(AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.w700))),
            ]),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(items, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.caption(context)),
            ],
            if (g.status == _GroupStatus.saving)
              _groupStatus(const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)), 'Đang lưu...', null)
            else if (g.status == _GroupStatus.saved)
              _groupStatus(const Icon(LucideIcons.circleCheck, size: 16, color: AppColors.safe), 'Đã lưu', AppColors.safe)
            else if (g.status == _GroupStatus.failed)
              _groupStatus(const Icon(LucideIcons.circleAlert, size: 16, color: AppColors.danger), g.error ?? 'Lưu thất bại', AppColors.danger),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: locked || g.skipped || categories.isEmpty ? null : () => _pickGroupCategory(g, categories),
                  icon: const Icon(LucideIcons.tag, size: 16),
                  label: const Text('Đổi danh mục'),
                ),
                TextButton.icon(
                  onPressed: canSkip ? () => setState(() => g.skipped = !g.skipped) : null,
                  icon: Icon(g.skipped ? LucideIcons.undo2 : LucideIcons.ban, size: 16),
                  label: Text(g.skipped ? 'Giữ lại' : 'Bỏ nhóm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupStatus(Widget icon, String text, Color? color) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          icon,
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: AppTypography.caption(context).copyWith(color: color))),
        ]),
      );

  TextStyle _label(BuildContext context) => AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5);

  /// [role] ('from' | 'to') nằm trong khóa: chuyển tiền có HAI ô cùng một Column, và khi hai giá trị trùng nhau (cả hai null lúc danh sách tài khoản
  /// đang tải lại, hoặc người dùng chọn cùng một ví) hai khóa giống hệt nhau sẽ làm Flutter báo "Duplicate keys" rồi hỏng cây giao diện.
  Widget _accountDropdown(String role, List<FinancialAccount> accounts, String? value, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      key: ValueKey('acc-$role-$value-${accounts.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.wallet, size: 20)),
      items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _typeChip(String label, TransactionType type, Color color) {
    final selected = _type == type;
    return ChoiceChip(
      label: Center(child: Text(label)),
      selected: selected,
      onSelected: (v) {
        if (v) setState(() => _type = type);
      },
      selectedColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(color: selected ? color : null, fontWeight: FontWeight.w600),
    );
  }
}
