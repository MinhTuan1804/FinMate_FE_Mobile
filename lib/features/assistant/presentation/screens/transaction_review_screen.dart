import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
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

/// "1250000" -> "1.250.000" (chỉ giữ chữ số)
String _groupThousands(String raw) => raw
    .replaceAll(RegExp(r'\D'), '')
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

/// Gom nhóm hàng nghìn khi gõ số tiền; [parseAmountInput] bỏ dấu chấm nên không đổi giá trị lưu
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = _groupThousands(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

enum _GroupStatus { pending, saving, saved, failed }

class _GroupEntry {
  final ReceiptGroup group;
  final String clientRequestId;
  String? categoryId;
  bool categoryTouched = false;
  bool skipped = false;
  _GroupStatus status = _GroupStatus.pending;
  String? error;

  _GroupEntry(this.group, String? scanId)
    : clientRequestId = group.requestId(scanId);
}

/// Rà soát và lưu một bản nháp giao dịch do AI trích xuất (chat, giọng nói, hóa đơn)
class TransactionReviewScreen extends ConsumerStatefulWidget {
  final ReviewArgs args;

  const TransactionReviewScreen({super.key, required this.args});

  @override
  ConsumerState<TransactionReviewScreen> createState() =>
      _TransactionReviewScreenState();
}

class _TransactionReviewScreenState
    extends ConsumerState<TransactionReviewScreen> {
  late final TextEditingController _amount = TextEditingController(
    text: _groupThousands(widget.args.draft.amountCents?.toString() ?? ''),
  );
  final FocusNode _amountFocus = FocusNode();
  late final TextEditingController _merchant = TextEditingController(
    text: widget.args.draft.merchantName ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.args.draft.description ?? '',
  );
  late TransactionType _type = _initialType();
  late DateTime _date = widget.args.draft.transactedAt ?? DateTime.now();

  String? _categoryId;
  bool _categoryTouched = false;
  String? _accountId;
  String? _toAccountId;
  bool _isSaving = false;
  String? _error;

  DraftTransaction get _draft => widget.args.draft;

  late final List<_GroupEntry> _groups =
      _draft.kind == DraftKind.expense && _draft.receiptGroups.length >= 2
      ? _draft.receiptGroups.map((g) => _GroupEntry(g, _draft.scanId)).toList()
      : const [];
  bool get _isSplit => _groups.isNotEmpty;
  Iterable<_GroupEntry> get _keptGroups => _groups.where((g) => !g.skipped);

  TransactionType _initialType() {
    if (_draft.kind == DraftKind.transfer) return TransactionType.transfer;
    return _draft.type == TransactionType.income
        ? TransactionType.income
        : TransactionType.expense;
  }

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
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
      if (candidate != null && accounts.any((a) => a.id == candidate)) {
        return candidate;
      }
    }
    return accounts.first.id;
  }

  String? _effectiveToAccount(List<FinancialAccount> accounts, String? from) {
    if (_type == TransactionType.transfer) return _transferPair(accounts).$2;
    if (_toAccountId != null && accounts.any((a) => a.id == _toAccountId)) {
      return _toAccountId;
    }
    for (final a in accounts) {
      if (a.id != from) return a.id;
    }
    return null;
  }

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
    from ??=
        accounts.where((a) => a.id != to).map((a) => a.id).firstOrNull ??
        accounts.first.id;
    if (to == null || (to == from && userTo == null)) {
      to = accounts.where((a) => a.id != from).map((a) => a.id).firstOrNull;
    }
    return (from, to);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (!mounted) return;
    setState(
      () => _date = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _date.hour,
        time?.minute ?? _date.minute,
      ),
    );
  }

  String? _groupCategory(_GroupEntry g, List<Category> categories) {
    if (g.categoryTouched) return g.categoryId;
    return categories
        .where((c) => c.slug == g.group.categorySlug)
        .map((c) => c.id)
        .firstOrNull;
  }

  Future<void> _pickGroupCategory(
    _GroupEntry g,
    List<Category> categories,
  ) async {
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

  Future<void> _saveSplit(
    List<Category> categories,
    List<FinancialAccount> accounts,
  ) async {
    if (_isSaving) return;
    final account = _effectiveAccount(accounts);
    if (account == null) {
      setState(
        () => _error = 'Bạn cần có ít nhất một tài khoản để lưu giao dịch',
      );
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
    for (final g
        in _keptGroups.where((g) => g.status != _GroupStatus.saved).toList()) {
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
      final messageId = widget.args.messageId;
      if (messageId != null) {
        final total = saved.fold<BigInt>(
          BigInt.zero,
          (sum, g) => sum + g.group.amountCents,
        );
        ref
            .read(assistantControllerProvider.notifier)
            .resolveDraft(
              messageId,
              savedSummary(saved.length, total, _date),
            );
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Đã ghi nhận ${saved.length} giao dịch thành công!'),
          backgroundColor: AppColors.safe,
        ),
      );
    } else {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _save(
    List<Category> categories,
    List<FinancialAccount> accounts,
  ) async {
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
    final categoryName = categories
        .where((c) => c.id == categoryId)
        .map((c) => c.name)
        .firstOrNull;
    final note = _note.text.trim();
    final merchant = _merchant.text.trim();

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      if (isTransfer) {
        await controller.transferInternal(
          amountCents: amount!,
          fromAccountId: from!,
          toAccountId: to!,
          description: note.isEmpty ? 'Chuyển tiền nội bộ' : note,
          date: _date,
        );
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
        ref
            .read(assistantControllerProvider.notifier)
            .resolveDraft(
              messageId,
              isTransfer
                  ? 'Đã chuyển: ${formatVnd(amount)}'
                  : 'Đã ghi: ${formatVnd(amount)} · ${categoryName ?? 'Chưa phân loại'}',
              categorySlug: isTransfer
                  ? null
                  : categories
                        .where((c) => c.id == categoryId)
                        .firstOrNull
                        ?.slug,
            );
      }
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã ghi nhận giao dịch thành công!'),
          backgroundColor: AppColors.safe,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final accounts =
        ref.watch(accountsControllerProvider).valueOrNull ??
        const <FinancialAccount>[];
    final from = _effectiveAccount(accounts);
    final to = _effectiveToAccount(accounts, from);
    final selectedCategory = _effectiveCategory(categories);
    final isTransfer = _type == TransactionType.transfer;
    final lowConfidence = (_draft.confidence ?? 1.0) < 0.85;
    final needsReview =
        lowConfidence ||
        _draft.missingFields.isNotEmpty ||
        _draft.needsReview ||
        _draft.hasPossibleDuplicate;

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        body: AmbientGlassBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSourcePill(context),
                        const SizedBox(height: 16),
                        _buildMainCard(
                          context,
                          categories,
                          accounts,
                          from,
                          to,
                          selectedCategory,
                          isTransfer,
                        ),
                        if (needsReview) ...[
                          const SizedBox(height: 16),
                          _buildReviewWarning(context, lowConfidence),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildFooter(context, categories, accounts),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _sourceLabel => switch (_draft.source) {
    DraftSource.chat => 'Tin nhắn trò chuyện',
    DraftSource.voice => 'Giọng nói',
    DraftSource.receipt => 'Hóa đơn',
  };

  IconData get _sourceIcon => switch (_draft.source) {
    DraftSource.chat => LucideIcons.messageSquareText,
    DraftSource.voice => LucideIcons.mic,
    DraftSource.receipt => LucideIcons.receipt,
  };

  BoxDecoration _pillDecoration(BuildContext context) => BoxDecoration(
    color: AppColors.surfaceSubtle(context).withValues(alpha: 0.7),
    borderRadius: AppSpacing.roundedPill,
    border: Border.all(color: AppColors.glassBorder(context)),
  );

  BoxDecoration _glassDecoration(BuildContext context, double radius) =>
      BoxDecoration(
        color: AppColors.isDark(context)
            ? AppColors.glassFillDark
            : AppColors.glassFillLight,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.glassBorder(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryAction(context).withValues(alpha: 0.1),
            blurRadius: 25,
            spreadRadius: -5,
            offset: const Offset(0, 20),
          ),
        ],
      );

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          LiquidGlassIconButton(
            icon: LucideIcons.arrowLeft,
            tooltip: 'Quay lại',
            iconSize: 18,
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              'Xác nhận giao dịch AI',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyLarge(context).copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ),
          LiquidGlassIconButton(
            icon: LucideIcons.circleHelp,
            tooltip: 'Trợ giúp',
            iconSize: 18,
            onPressed: _showHelp,
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Về giao dịch này'),
        content: Text(
          'FinMate AI trích xuất thông tin từ ${_sourceLabel.toLowerCase()} của bạn. '
          'Bạn có thể sửa mọi thông tin; giao dịch chỉ được ghi vào sổ khi bạn bấm "Lưu vào sổ giao dịch".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcePill(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 7, 16, 7),
        decoration: _pillDecoration(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _sourceIcon,
                size: 12,
                color: AppColors.slateOn(context),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Nguồn: $_sourceLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard(
    BuildContext context,
    List<Category> categories,
    List<FinancialAccount> accounts,
    String? from,
    String? to,
    String? selectedCategory,
    bool isTransfer,
  ) {
    final secondary = AppColors.textSecondary(context);
    final categoryName = categories
        .where((c) => c.id == selectedCategory)
        .map((c) => c.name)
        .firstOrNull;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _glassDecoration(context, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAmountSection(context),
          if (_isSplit) ...[
            const SizedBox(height: 20),
            Text('CÁC NHÓM TRONG HÓA ĐƠN', style: _label(context)),
            const SizedBox(height: 8),
            for (final (i, g) in _groups.indexed) _groupCard(i, g, categories),
          ] else ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _typeChip(
                    'Chi tiêu',
                    TransactionType.expense,
                    AppColors.expense,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _typeChip(
                    'Thu nhập',
                    TransactionType.income,
                    AppColors.income,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _typeChip(
                    'Chuyển tiền',
                    TransactionType.transfer,
                    AppColors.slateOn(context),
                  ),
                ),
              ],
            ),
          ],
          if (!isTransfer)
            _detailRow(
              context,
              LucideIcons.fileText,
              'Tên giao dịch',
              TextField(
                controller: _merchant,
                textAlign: TextAlign.end,
                minLines: 1,
                maxLines: 2,
                style: AppTypography.bodyLarge(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
                decoration: _bareDecoration('Ví dụ: WinMart'),
              ),
            ),
          if (!isTransfer && !_isSplit)
            _detailRow(
              context,
              LucideIcons.layoutGrid,
              'Danh mục',
              Align(
                alignment: Alignment.centerRight,
                child: Material(
                  color: Colors.transparent,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.22),
                      borderRadius: AppSpacing.roundedPill,
                      border: Border.all(color: AppColors.glassBorder(context)),
                    ),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: categories.isEmpty
                          ? null
                          : () => _pickCategory(categories, selectedCategory),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                categoryIcon(
                                  categories
                                      .where((c) => c.id == selectedCategory)
                                      .map((c) => c.slug)
                                      .firstOrNull,
                                ),
                                size: 15,
                                color: AppColors.slateOn(context),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  categoryName ?? 'Chưa phân loại',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyMedium(
                                    context,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                LucideIcons.chevronDown,
                                size: 14,
                                color: secondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          _detailRow(
            context,
            LucideIcons.landmark,
            isTransfer ? 'TỪ TÀI KHOẢN' : 'Nguồn tiền',
            _accountDropdown(
              'from',
              accounts,
              from,
              (v) => setState(() => _accountId = v),
            ),
          ),
          if (isTransfer)
            _detailRow(
              context,
              LucideIcons.landmark,
              'ĐẾN TÀI KHOẢN',
              _accountDropdown(
                'to',
                accounts,
                to,
                (v) => setState(() => _toAccountId = v),
              ),
            ),
          _detailRow(
            context,
            LucideIcons.clock,
            'Thời gian',
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: _isSaving ? null : _pickDate,
                borderRadius: AppSpacing.roundedSmall,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: 1,
                    child: Text(
                      DateFormat('dd/MM/yyyy - HH:mm').format(_date),
                      style: AppTypography.tabular(
                        AppTypography.bodyLarge(context).copyWith(
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface(context).withValues(alpha: 0.45),
              borderRadius: AppSpacing.roundedMedium,
              border: Border.all(color: AppColors.glassBorder(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.fileText,
                      size: 13,
                      color: AppColors.textMuted(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _draft.source == DraftSource.chat
                          ? 'GHI CHÚ'
                          : 'GHI CHÚ TỰ ĐỘNG',
                      style: AppTypography.caption(context).copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.66,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: _note,
                  minLines: 1,
                  maxLines: 3,
                  style: AppTypography.body(context),
                  decoration: _bareDecoration('Nhập ghi chú giao dịch...'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _bareDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: false,
    isDense: true,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
  );

  /// Phần số tiền ở đầu thẻ: nhãn, số tiền cỡ lớn (sửa được), chú thích loại giao dịch
  Widget _buildAmountSection(BuildContext context) {
    final (IconData icon, String caption, Color color) = switch (_type) {
      TransactionType.income => (
        LucideIcons.arrowUp,
        'Thu nhập thực tế',
        AppColors.income,
      ),
      TransactionType.transfer => (
        LucideIcons.arrowLeftRight,
        'Chuyển tiền nội bộ',
        AppColors.slateOn(context),
      ),
      _ => (LucideIcons.arrowDown, 'Chi tiêu thực tế', AppColors.expense),
    };
    final amountStyle = AppTypography.tabular(
      AppTypography.h1(
        context,
      ).copyWith(fontSize: 32, height: 1.25, letterSpacing: -0.75),
    );
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.glassBorder(context)),
        ),
      ),
      child: Column(
        children: [
          Text(
            _isSplit ? 'TỔNG HÓA ĐƠN' : 'SỐ TIỀN TRÍCH XUẤT',
            style: AppTypography.caption(context).copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.55,
            ),
          ),
          const SizedBox(height: 4),
          if (_isSplit)
            Text(
              formatVnd(_draft.amountCents ?? BigInt.zero),
              style: amountStyle,
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: IntrinsicWidth(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 96),
                      child: TextField(
                        controller: _amount,
                        focusNode: _amountFocus,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [_ThousandsFormatter()],
                        style: amountStyle,
                        decoration: _bareDecoration('0').copyWith(
                          suffixText: ' ₫',
                          suffixStyle: amountStyle,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Chỉnh sửa số tiền',
                  onPressed: _isSaving ? null : _amountFocus.requestFocus,
                  style: IconButton.styleFrom(
                    fixedSize: const Size(44, 44),
                    backgroundColor: AppColors.surface(
                      context,
                    ).withValues(alpha: 0.6),
                  ),
                  icon: Icon(
                    LucideIcons.pencil,
                    size: 14,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                _isSplit ? 'Mỗi nhóm lưu thành một giao dịch' : caption,
                style: AppTypography.caption(context).copyWith(color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Một hàng chi tiết: icon + nhãn bên trái, giá trị bên phải
  Widget _detailRow(
    BuildContext context,
    IconData icon,
    String label,
    Widget value,
  ) {
    final secondary = AppColors.textSecondary(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Icon(icon, size: 15, color: secondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.body(context).copyWith(color: secondary),
          ),
          const SizedBox(width: 12),
          Expanded(child: value),
        ],
      ),
    );
  }

  Future<void> _pickCategory(List<Category> categories, String? current) async {
    final picked = await showModalBottomSheet<(Category?,)>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.circleHelp, size: 20),
              title: const Text('Chưa phân loại'),
              selected: current == null,
              onTap: () => Navigator.pop(ctx, (null,)),
            ),
            for (final c in categories)
              ListTile(
                leading: Icon(categoryIcon(c.slug), size: 20),
                title: Text(c.name),
                selected: c.id == current,
                onTap: () => Navigator.pop(ctx, (c,)),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _categoryTouched = true;
      _categoryId = picked.$1?.id;
    });
  }

  /// Cảnh báo AI cần người dùng kiểm tra lại (độ tin cậy thấp, thiếu trường, có thể trùng)
  Widget _buildReviewWarning(BuildContext context, bool lowConfidence) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: AppSpacing.roundedLarge,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.triangleAlert,
            color: AppColors.warning,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI cần bạn kiểm tra lại một số chi tiết',
                  style: AppTypography.bodyMedium(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
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
    );
  }

  Widget _buildFooter(
    BuildContext context,
    List<Category> categories,
    List<FinancialAccount> accounts,
  ) {
    final actionColor = AppColors.primaryAction(context);
    final onAction = AppColors.onPrimaryAction(context);
    final secondaryStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: const StadiumBorder(),
      backgroundColor: AppColors.surfaceSubtle(context).withValues(alpha: 0.7),
      side: BorderSide(color: AppColors.glassBorder(context)),
      foregroundColor: AppColors.textPrimary(context),
    );
    Widget secondaryLabel(IconData icon, String text) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTypography.caption(
                  context,
                ).copyWith(color: AppColors.danger, fontSize: 13),
              ),
            ),
          ElevatedButton(
            onPressed: _isSaving
                ? null
                : () => _isSplit
                      ? _saveSplit(categories, accounts)
                      : _save(categories, accounts),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
              backgroundColor: actionColor,
              foregroundColor: onAction,
              disabledBackgroundColor: actionColor.withValues(alpha: 0.5),
            ),
            child: _isSaving
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: onAction,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.circleCheck, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _isSplit
                              ? 'Lưu ${_keptGroups.where((g) => g.status != _GroupStatus.saved).length} giao dịch'
                              : 'Lưu vào sổ giao dịch',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (!_isSplit) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _amountFocus.requestFocus,
                    style: secondaryStyle,
                    child: secondaryLabel(
                      LucideIcons.squarePen,
                      'Chỉnh sửa thủ công',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: secondaryStyle,
                  child: secondaryLabel(LucideIcons.ban, 'Bỏ qua giao dịch'),
                ),
              ),
            ],
          ),
        ],
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
    final category = categories
        .where((c) => c.id == _groupCategory(g, categories))
        .firstOrNull;
    final locked = _isSaving || g.status == _GroupStatus.saved;
    final canSkip = !locked && (g.skipped || _keptGroups.length > 1);
    final items = g.group.items
        .map((i) => i.name)
        .where((n) => n.isNotEmpty)
        .join(', ');

    return Opacity(
      key: ValueKey('receipt-group-$index'),
      opacity: g.skipped ? 0.5 : 1,
      child: LiquidGlassCard(
        enableBlur: false,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        borderColor: g.status == _GroupStatus.failed ? AppColors.danger : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  categoryIcon(category?.slug ?? g.group.categorySlug),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category?.name ?? 'Chưa phân loại',
                    style: AppTypography.bodyMedium(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  formatVnd(g.group.amountCents),
                  style: AppTypography.tabular(
                    AppTypography.bodyMedium(
                      context,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                items,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(context),
              ),
            ],
            if (g.status == _GroupStatus.saving)
              _groupStatus(
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                'Đang lưu...',
                null,
              )
            else if (g.status == _GroupStatus.saved)
              _groupStatus(
                const Icon(
                  LucideIcons.circleCheck,
                  size: 16,
                  color: AppColors.safe,
                ),
                'Đã lưu',
                AppColors.safe,
              )
            else if (g.status == _GroupStatus.failed)
              _groupStatus(
                const Icon(
                  LucideIcons.circleAlert,
                  size: 16,
                  color: AppColors.danger,
                ),
                g.error ?? 'Lưu thất bại',
                AppColors.danger,
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: locked || g.skipped || categories.isEmpty
                      ? null
                      : () => _pickGroupCategory(g, categories),
                  icon: const Icon(LucideIcons.tag, size: 16),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Đổi danh mục', maxLines: 1)),
                ),
                TextButton.icon(
                  onPressed: canSkip
                      ? () => setState(() => g.skipped = !g.skipped)
                      : null,
                  icon: Icon(
                    g.skipped ? LucideIcons.undo2 : LucideIcons.ban,
                    size: 16,
                  ),
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(g.skipped ? 'Giữ lại' : 'Bỏ nhóm', maxLines: 1)),
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
    child: Row(
      children: [
        icon,
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTypography.caption(context).copyWith(color: color),
          ),
        ),
      ],
    ),
  );

  TextStyle _label(BuildContext context) => AppTypography.sectionLabel(context);

  Widget _accountDropdown(
    String role,
    List<FinancialAccount> accounts,
    String? value,
    ValueChanged<String> onChanged,
  ) {
    return Align(
      alignment: Alignment.centerRight,
      child: DropdownButtonFormField<String>(
        key: ValueKey('acc-$role-$value-${accounts.length}'),
        initialValue: value,
        isExpanded: true,
        alignment: AlignmentDirectional.centerEnd,
        style: AppTypography.bodyLarge(
          context,
        ).copyWith(fontWeight: FontWeight.w500, letterSpacing: -0.15),
        icon: const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Icon(LucideIcons.chevronDown, size: 16),
        ),
        decoration: InputDecoration(
          filled: false,
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 4, 12),
        ),
        items: accounts
            .map(
              (a) => DropdownMenuItem(
                value: a.id,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(
                        color: AppColors.safe,
                        shape: BoxShape.circle,
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(a.name, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _typeChip(String label, TransactionType type, Color color) {
    final selected = _type == type;
    // ChoiceChip chỉ rộng bằng chữ nên ra ba viên thuốc bé: ép nhãn giãn đủ bề rộng ô, cao 44 để dễ chạm và dễ nhìn
    return LayoutBuilder(
      builder: (context, constraints) => ChoiceChip(
        label: SizedBox(
          width: constraints.maxWidth.isFinite ? constraints.maxWidth - 2 : null,
          height: 44,
          child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label))),
        ),
        selected: selected,
        onSelected: (v) {
          if (v) setState(() => _type = type);
        },
        showCheckmark: false,
        labelPadding: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        selectedColor: color.withValues(alpha: 0.2),
        side: BorderSide(color: selected ? color : AppColors.glassBorder(context)),
        labelStyle: TextStyle(
          color: selected ? color : AppColors.textPrimary(context),
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}
