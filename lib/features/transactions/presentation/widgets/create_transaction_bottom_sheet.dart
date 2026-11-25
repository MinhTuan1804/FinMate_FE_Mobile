import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/categories/presentation/category_icons.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_dialog.dart';
import 'package:finmate/shared/widgets/glass/glass_loading_spinner.dart';
import 'package:finmate/shared/widgets/glass/glass_text_field.dart';

/// Bottom Sheet nhập liệu giao dịch (BR-21 -> BR-24) phong cách Glass (GlassCard level 3).
class CreateTransactionBottomSheet extends ConsumerStatefulWidget {
  final int initialTab;

  /// Điền sẵn từ nơi khác đã có số tiền/danh mục (ví dụ F5 "Kiểm tra mua sắm" — người dùng chọn
  /// "Vẫn mua và trừ vào ngân sách" thì mở sheet này với đúng số tiền/danh mục đã nhập, không bắt
  /// gõ lại).
  final BigInt? initialAmountCents;
  final String? initialDescription;
  final String? initialCategoryId;

  const CreateTransactionBottomSheet({
    super.key,
    this.initialTab = 0,
    this.initialAmountCents,
    this.initialDescription,
    this.initialCategoryId,
  });

  static Future<void> show(
    BuildContext context, {
    int initialTab = 0,
    BigInt? initialAmountCents,
    String? initialDescription,
    String? initialCategoryId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTransactionBottomSheet(
        initialTab: initialTab,
        initialAmountCents: initialAmountCents,
        initialDescription: initialDescription,
        initialCategoryId: initialCategoryId,
      ),
    );
  }

  @override
  ConsumerState<CreateTransactionBottomSheet> createState() =>
      _CreateTransactionBottomSheetState();
}

class _CreateTransactionBottomSheetState
    extends ConsumerState<CreateTransactionBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
    initialIndex: widget.initialTab,
  );

  static const _modes = [
    (LucideIcons.sparkles, 'AI Text'),
    (LucideIcons.mic, 'Giọng nói'),
    (LucideIcons.scanLine, 'Hóa đơn'),
    (LucideIcons.pencil, 'Thủ công'),
  ];

  // Thủ công
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String? _categoryId;
  String? _accountId;
  String? _toAccountId;
  DateTime _date = DateTime.now();
  bool _isSaving = false;
  String? _classicError;

  @override
  void initState() {
    super.initState();
    if (widget.initialAmountCents != null) _amountController.text = formatAmountDigits(widget.initialAmountCents!);
    if (widget.initialDescription != null) _descController.text = widget.initialDescription!;
    _categoryId = widget.initialCategoryId;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _effectiveId(
    String? selected,
    List<FinancialAccount> accounts, {
    int fallbackIndex = 0,
  }) {
    if (selected != null && accounts.any((a) => a.id == selected)) {
      return selected;
    }
    return accounts[math.min(fallbackIndex, accounts.length - 1)].id;
  }

  /// Cùng khoảng cho phép với màn Chuyển tiền nội bộ (transfer_screen.dart._pickDate),
  /// để đồng bộ quy tắc chọn ngày giao dịch trong toàn app.
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute, _date.second));
    }
  }

  Future<void> _handleClassicSave(List<FinancialAccount> accounts) async {
    if (_isSaving) return;
    final amount = parseAmountInput(_amountController.text);
    if (amount == null) {
      setState(() => _classicError = 'Vui lòng nhập số tiền hợp lệ');
      return;
    }

    final from = _effectiveId(_accountId, accounts);
    final to = _effectiveId(_toAccountId, accounts, fallbackIndex: 1);
    final isTransfer = _type == TransactionType.transfer;
    if (isTransfer && accounts.length < 2) {
      setState(() => _classicError = 'Cần ít nhất 2 tài khoản để chuyển tiền');
      return;
    }
    if (isTransfer && from == to) {
      setState(
        () => _classicError = 'Tài khoản nguồn và đích không được trùng nhau',
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(transactionControllerProvider.notifier);
    final description = _descController.text.trim();

    setState(() {
      _isSaving = true;
      _classicError = null;
    });
    try {
      if (isTransfer) {
        await controller.transferInternal(
          amountCents: amount,
          fromAccountId: from,
          toAccountId: to,
          description: description.isEmpty ? 'Chuyển tiền nội bộ' : description,
          date: _date,
        );
      } else {
        await controller.createTransaction(
          accountId: from,
          categoryId: _categoryId,
          amountCents: amount,
          type: _type,
          description: description,
          date: _date,
        );
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Đã thêm giao dịch thành công!'),
          backgroundColor: GlassColors.success,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _classicError = errorMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _createWallet() async {
    final balance = await showDialog<BigInt>(
      context: context,
      builder: (_) => const _CreateWalletDialog(),
    );
    if (balance == null || !mounted) return;

    try {
      await ref
          .read(accountsControllerProvider.notifier)
          .create(
            name: 'Ví tiền mặt',
            type: AccountType.cash,
            initialBalanceCents: balance,
          );
    } catch (e) {
      if (mounted) setState(() => _classicError = errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final height = math.min(
      media.size.height * 0.92,
      media.size.height - keyboard - media.padding.top - 16,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: GlassCard(
        level: 3,
        padding: EdgeInsets.zero,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(GlassRadius.cardLarge),
        ),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: GlassColors.textMuted.withValues(alpha: 0.45),
                    borderRadius: GlassRadius.roundedPill,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Đóng',
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: Icon(
                          LucideIcons.x,
                          size: 20,
                          color: GlassColors.textSecondary,
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Ghi chép giao dịch',
                              maxLines: 1,
                              style: GlassTypography.headlineSm(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: _buildModeBar(),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAssistantTab(),
                      _buildAssistantTab(
                        icon: LucideIcons.mic,
                        description:
                            'Nói tự nhiên, FinMate chuyển thành chữ để bạn kiểm tra rồi gửi cho trợ lý.',
                        button: 'Nói để ghi chép',
                        route: '/assistant?start=voice',
                      ),
                      _buildAssistantTab(
                        icon: LucideIcons.scanLine,
                        description:
                            'Chụp hoặc chọn ảnh hóa đơn, FinMate đọc số tiền và cửa hàng để bạn kiểm tra rồi lưu.',
                        button: 'Quét hóa đơn',
                        route: '/assistant?start=scan',
                      ),
                      _buildClassicTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Thanh chọn kiểu ghi chép (4 chế độ) dạng pill; dùng chung [_tabController] nên vuốt ngang vẫn đổi được.
  Widget _buildModeBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: GlassColors.fieldFill,
        borderRadius: GlassRadius.roundedPill,
        border: Border.all(color: GlassColors.fieldBorder),
      ),
      child: AnimatedBuilder(
        animation: _tabController.animation!,
        builder: (context, _) {
          final current = _tabController.animation!.value.round();
          return Row(
            children: [
              for (var i = 0; i < _modes.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == current,
                    child: InkWell(
                      borderRadius: GlassRadius.roundedPill,
                      onTap: () => _tabController.animateTo(i),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: i == current
                              ? GlassColors.ink
                              : Colors.transparent,
                          borderRadius: GlassRadius.roundedPill,
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _modes[i].$1,
                                size: 16,
                                color: i == current
                                    ? GlassColors.onInk
                                    : GlassColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _modes[i].$2,
                                maxLines: 1,
                                style: GlassTypography.bodyMd(
                                  color: i == current
                                      ? GlassColors.onInk
                                      : GlassColors.textSecondary,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _errorText(String message) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: GlassTypography.bodySm(color: GlassColors.danger),
    ),
  );

  Widget _iconBadge(IconData icon, {double size = 40}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: GlassColors.activeFill,
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: size * 0.45, color: GlassColors.activeFg),
  );

  Widget _buildAssistantTab({
    IconData icon = LucideIcons.sparkles,
    String description =
        'Nhắn tự nhiên như "ăn phở 45k", FinMate tự ghi chép hoặc trả lời câu hỏi chi tiêu của bạn.',
    String button = 'Mở trợ lý',
    String route = '/assistant',
  }) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _iconBadge(icon, size: 64)),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GlassTypography.bodyMd(),
          ),
          const SizedBox(height: 24),
          GlassPrimaryButton(
            label: button,
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.push(route);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClassicTab() {
    return ref
        .watch(accountsControllerProvider)
        .when(
          loading: () => const Center(child: GlassLoadingSpinner()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    errorMessage(e),
                    textAlign: TextAlign.center,
                    style: GlassTypography.bodyMd(color: GlassColors.danger),
                  ),
                  const SizedBox(height: 8),
                  GlassGhostButton(
                    label: 'Thử lại',
                    onPressed: () =>
                        ref.read(accountsControllerProvider.notifier).load(),
                  ),
                ],
              ),
            ),
          ),
          data: (accounts) => accounts.isEmpty
              ? _buildNoAccount()
              : _buildClassicForm(accounts),
        );
  }

  Widget _buildNoAccount() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconBadge(LucideIcons.wallet, size: 64),
            const SizedBox(height: 12),
            Text(
              'Bạn chưa có tài khoản nào',
              style: GlassTypography.bodyLg().copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tạo một ví để bắt đầu ghi chép giao dịch.',
              style: GlassTypography.bodySm(),
              textAlign: TextAlign.center,
            ),
            if (_classicError != null) _errorText(_classicError!),
            const SizedBox(height: 16),
            GlassPrimaryButton(
              label: 'Tạo ví tiền mặt',
              onPressed: _createWallet,
            ),
          ],
        ),
      ),
    );
  }

  /// Thẻ một trường nhập: ô tròn icon + nhãn nhỏ + nội dung (dropdown/ô gõ), kèm chữ phụ bên phải nhãn nếu có.
  Widget _fieldCard({
    required IconData icon,
    required String label,
    required Widget child,
    String? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GlassColors.fieldFill,
        borderRadius: GlassRadius.roundedInput,
        border: Border.all(color: GlassColors.fieldBorder),
      ),
      child: Row(
        children: [
          _iconBadge(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GlassTypography.bodySm(),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            trailing,
                            maxLines: 1,
                            style: GlassTypography.bodySm(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _valueStyle => GlassTypography.bodyMd(
    color: GlassColors.textPrimary,
  ).copyWith(fontWeight: FontWeight.w600);

  Widget _dropdown<T>({
    Key? key,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onChanged,
    required String semanticLabel,
  }) {
    return Semantics(
      label: semanticLabel,
      child: DropdownButtonHideUnderline(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: DropdownButton<T>(
            key: key,
            value: value,
            isExpanded: true,
            isDense: true,
            style: _valueStyle,
            dropdownColor: GlassColors.secondarySurface,
            icon: Icon(
              LucideIcons.chevronDown,
              size: 18,
              color: GlassColors.textSecondary,
            ),
            items: items,
            onChanged: (v) => onChanged(v as T),
          ),
        ),
      ),
    );
  }

  Widget _accountDropdown({
    required String label,
    required IconData icon,
    required List<FinancialAccount> accounts,
    required String value,
    required ValueChanged<String> onChanged,
    bool showBalance = false,
  }) {
    final selected = accounts.firstWhere((a) => a.id == value);
    return _fieldCard(
      icon: icon,
      label: label,
      trailing: showBalance
          ? 'Khả dụng ${formatVnd(selected.balanceCents)}'
          : null,
      child: _dropdown<String>(
        key: ValueKey('$label-$value'),
        value: value,
        semanticLabel: label,
        onChanged: onChanged,
        items: accounts
            .map(
              (a) => DropdownMenuItem(
                value: a.id,
                child: Text(
                  a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _addQuick(int delta) {
    final current = parseAmountInput(_amountController.text, allowZero: true);
    final next = (current ?? BigInt.zero) + BigInt.from(delta);
    if (next > maxAmountCents) return;
    final text = formatAmountDigits(next);
    setState(() {
      _classicError = null;
      _amountController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  Widget _buildAmountCard() {
    final amountColor = switch (_type) {
      TransactionType.expense => AppColors.expenseOn(context),
      TransactionType.income => AppColors.incomeOn(context),
      _ => GlassColors.textPrimary,
    };
    final amountStyle = GlassTypography.displayHero(
      color: amountColor,
    ).copyWith(fontSize: 26, height: 32 / 26);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      decoration: BoxDecoration(
        color: GlassColors.fieldFill,
        borderRadius: GlassRadius.roundedHero,
        border: Border.all(color: GlassColors.fieldBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SỐ TIỀN GIAO DỊCH',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GlassTypography.labelCaps(),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: GlassColors.activeFill,
                  borderRadius: GlassRadius.roundedPill,
                ),
                child: Text(
                  'VND (₫)',
                  maxLines: 1,
                  style: GlassTypography.labelCaps(color: GlassColors.activeFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Semantics(
            label: 'Số tiền (VNĐ)',
            child: TextField(
              key: const ValueKey('tx-amount-field'),
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              textAlign: TextAlign.center,
              onChanged: (_) {
                if (_classicError != null) setState(() => _classicError = null);
              },
              style: amountStyle,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: amountStyle.copyWith(
                  color: GlassColors.textMuted.withValues(alpha: 0.5),
                ),
                suffixText: ' ₫',
                suffixStyle: amountStyle,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final d in const [50000, 100000, 200000, 500000])
                  Semantics(
                    button: true,
                    label: 'Cộng thêm ${formatVnd(BigInt.from(d))}',
                    child: InkWell(
                      borderRadius: GlassRadius.roundedPill,
                      onTap: () => _addQuick(d),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: GlassColors.fieldFill,
                            borderRadius: GlassRadius.roundedPill,
                            border: Border.all(color: GlassColors.fieldBorder),
                          ),
                          child: Text(
                            '+${formatVnd(BigInt.from(d))}',
                            maxLines: 1,
                            style: GlassTypography.bodySm(
                              color: GlassColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: GlassColors.fieldFill,
        borderRadius: GlassRadius.roundedPill,
        border: Border.all(color: GlassColors.fieldBorder),
      ),
      child: Row(
        children: [
          for (final (label, type) in const [
            ('Chi tiêu', TransactionType.expense),
            ('Thu nhập', TransactionType.income),
            ('Chuyển tiền', TransactionType.transfer),
          ])
            Expanded(
              child: ChoiceChip(
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: const StadiumBorder(),
                side: BorderSide.none,
                backgroundColor: Colors.transparent,
                selectedColor: GlassColors.ink,
                label: SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: GlassTypography.bodyMd(
                        color: _type == type
                            ? GlassColors.onInk
                            : GlassColors.textSecondary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                selected: _type == type,
                onSelected: (v) {
                  if (v) setState(() => _type = type);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClassicForm(List<FinancialAccount> accounts) {
    final from = _effectiveId(_accountId, accounts);
    final to = _effectiveId(_toAccountId, accounts, fallbackIndex: 1);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final isTransfer = _type == TransactionType.transfer;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTypeBar(),
                const SizedBox(height: 10),
                _buildAmountCard(),
                const SizedBox(height: 10),
                if (isTransfer) ...[
                  _accountDropdown(
                    label: 'Từ tài khoản',
                    icon: LucideIcons.arrowUpRight,
                    accounts: accounts,
                    value: from,
                    showBalance: true,
                    onChanged: (v) => setState(() => _accountId = v),
                  ),
                  const SizedBox(height: 8),
                  _accountDropdown(
                    label: 'Đến tài khoản',
                    icon: LucideIcons.arrowDownLeft,
                    accounts: accounts,
                    value: to,
                    onChanged: (v) => setState(() => _toAccountId = v),
                  ),
                ] else ...[
                  _fieldCard(
                    icon: LucideIcons.tag,
                    label: 'Danh mục',
                    child: _dropdown<String?>(
                      key: ValueKey('cat-$_categoryId-${categories.length}'),
                      value: categories.any((c) => c.id == _categoryId)
                          ? _categoryId
                          : null,
                      semanticLabel: 'Danh mục',
                      onChanged: (v) => setState(() => _categoryId = v),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Chưa phân loại'),
                        ),
                        ...categories.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Row(
                              children: [
                                Icon(categoryIcon(c.slug), size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    c.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _accountDropdown(
                    label: 'Tài khoản',
                    icon: LucideIcons.wallet,
                    accounts: accounts,
                    value: from,
                    showBalance: true,
                    onChanged: (v) => setState(() => _accountId = v),
                  ),
                ],
                const SizedBox(height: 8),
                // Cùng khoảng cho phép với màn Chuyển tiền nội bộ (transfer_screen.dart._pickDate),
                // để đồng bộ quy tắc chọn ngày giao dịch trong toàn app.
                _fieldCard(
                  icon: LucideIcons.calendar,
                  label: 'Ngày giao dịch',
                  child: InkWell(
                    key: const ValueKey('classic-date'),
                    onTap: _pickDate,
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(_date),
                      style: _valueStyle,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _fieldCard(
                  icon: LucideIcons.fileText,
                  label: 'Ghi chú',
                  child: TextField(
                    controller: _descController,
                    style: _valueStyle,
                    decoration: InputDecoration(
                      hintText: 'Thêm ghi chú',
                      hintStyle: GlassTypography.bodyMd(
                        color: GlassColors.textMuted,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                if (_classicError != null) _errorText(_classicError!),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: SizedBox(
            width: double.infinity,
            child: GlassPrimaryButton(
              label: 'Lưu giao dịch',
              loading: _isSaving,
              onPressed: () => _handleClassicSave(accounts),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dialog tạo ví tiền mặt — TextEditingController do CHÍNH State của dialog sở hữu, chỉ dispose khi
/// State này bị gỡ khỏi cây widget (sau khi hiệu ứng đóng của AlertDialog chạy xong). Cùng pattern/
/// lý do với `_RenameAccountDialog` ở `financial_accounts_screen.dart` — xem comment ở đó để biết
/// đầy đủ lý do (crash "TextEditingController used after being disposed" nếu dispose ngay khi
/// `showDialog` trả về trong lúc dialog còn đang animate đóng).
class _CreateWalletDialog extends StatefulWidget {
  const _CreateWalletDialog();

  @override
  State<_CreateWalletDialog> createState() => _CreateWalletDialogState();
}

class _CreateWalletDialogState extends State<_CreateWalletDialog> {
  final TextEditingController _balanceController = TextEditingController(text: '0');

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialogShell(
      title: 'Tạo ví tiền mặt',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassTextField(
            controller: _balanceController,
            label: 'Số dư hiện có (VNĐ)',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GlassGhostButton(
                  label: 'Hủy',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassPrimaryButton(
                  label: 'Tạo ví',
                  onPressed: () {
                    final text = _balanceController.text.trim();
                    final value = text.isEmpty
                        ? BigInt.zero
                        : parseAmountInput(text, allowZero: true);
                    if (value != null) Navigator.pop(context, value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
