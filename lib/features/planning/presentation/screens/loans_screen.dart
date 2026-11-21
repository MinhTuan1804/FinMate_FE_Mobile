import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_dialog.dart';
import 'package:finmate/shared/widgets/glass/glass_text_field.dart';
import 'package:finmate/features/planning/data/loans_repository.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

/// Màn G9 - G11: Quản lý Khoản vay & Nợ. Dữ liệu thật từ /loans; ghi trả có thể kèm ví để sinh giao dịch.
class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  int _selectedTab = 0; // 0: Đi vay (Nợ cần trả), 1: Cho vay (Cần thu hồi)

  void _toast(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? AppColors.danger : null));
  }

  Future<void> _run(Future<void> Function() action, String successText) async {
    try {
      await action();
      ref.invalidate(loansProvider);
      _toast(successText);
    } catch (e) {
      _toast(errorMessage(e), error: true);
    }
  }

  Future<void> _addLoan() async {
    final type = _selectedTab == 0 ? LoanType.borrow : LoanType.lend;
    final input = await showDialog<_LoanInput>(context: context, builder: (_) => _LoanFormDialog(type: type));
    if (input == null) return;
    await _run(
      () => ref.read(loansRepositoryProvider).createLoan(
            type: type,
            title: input.title,
            counterparty: input.counterparty,
            principalCents: input.principalCents,
            interestRateYear: input.interestRate,
            dueDate: input.dueDate,
            startDate: input.startDate,
          ),
      'Đã thêm khoản vay.',
    );
  }

  Future<void> _editLoan(LoanItem loan) async {
    final input = await showDialog<_LoanInput>(context: context, builder: (_) => _LoanFormDialog(type: loan.type, loan: loan));
    if (input == null) return;
    await _run(
      () => ref.read(loansRepositoryProvider).updateLoan(
            id: loan.id,
            type: loan.type,
            title: input.title,
            counterparty: input.counterparty,
            principalCents: input.principalCents,
            interestRateYear: input.interestRate,
            dueDate: input.dueDate,
            startDate: input.startDate,
          ),
      'Đã cập nhật khoản vay.',
    );
  }

  Future<void> _recordRepayment(LoanItem loan) async {
    final accounts = ref.read(accountsControllerProvider).valueOrNull ?? const <FinancialAccount>[];
    final input = await showModalBottomSheet<_RepayInput>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RepayDialog(loan: loan, accounts: accounts),
    );
    if (input == null) return;
    await _run(
      () => ref.read(loansRepositoryProvider).repay(loanId: loan.id, amountCents: input.amountCents, financialAccountId: input.accountId),
      'Đã ghi nhận thanh toán.',
    );
  }

  Future<void> _delete(LoanItem loan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa khoản vay?'),
        content: const Text('Khoản vay và các lần trả trong sổ sẽ bị xóa. Giao dịch đã ghi vào ví vẫn giữ nguyên.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => ref.read(loansRepositoryProvider).deleteLoan(loan.id), 'Đã xóa khoản vay.');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(loansProvider);
    ref.watch(accountsControllerProvider); // giữ danh sách ví đã tải sẵn cho sheet ghi trả
    final currentType = _selectedTab == 0 ? LoanType.borrow : LoanType.lend;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khoản vay & Nợ'),
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft), onPressed: () => context.pop()),
        actions: [
          IconButton(key: const ValueKey('add-loan'), tooltip: 'Thêm khoản vay', icon: const Icon(LucideIcons.plus), onPressed: _addLoan),
        ],
      ),
      body: AmbientGlassBackground(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(loansProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle(context).withValues(alpha: 0.7),
                  borderRadius: AppSpacing.roundedPill,
                  border: Border.all(color: AppColors.border(context), width: 1),
                ),
                child: Row(children: [_tabButton('Tôi đang nợ', 0), _tabButton('Người khác nợ tôi', 1)]),
              ),
              const SizedBox(height: 20),
              ...async.when(
                loading: () => [const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))],
                error: (e, _) => [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(children: [
                      Text(errorMessage(e), textAlign: TextAlign.center, style: AppTypography.body(context)),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: () => ref.invalidate(loansProvider), child: const Text('Thử lại')),
                    ]),
                  ),
                ],
                data: (loans) => _content(context, loans.where((l) => l.type == currentType).toList()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, List<LoanItem> filtered) {
    final total = filtered.fold(BigInt.zero, (sum, l) => sum + l.remainingCents);
    return [
      ZenvestHeroDeck(
        peekBadgeText: _selectedTab == 0 ? 'DEBT' : 'LOAN',
        child: LiquidGlassCard(
          variant: LiquidGlassVariant.iridescentHero,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedTab == 0 ? 'TỔNG DƯ NỢ CẦN TRẢ' : 'TỔNG TIỀN CẦN THU HỒI',
                style: AppTypography.caption(context).copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.4),
              ),
              const SizedBox(height: 6),
              Text(
                formatVnd(total),
                key: const ValueKey('loans-total'),
                style: AppTypography.displayBalance(context).copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _selectedTab == 0 ? AppColors.danger : AppColors.safe,
                ),
              ),
              const SizedBox(height: 10),
              Text('Theo dõi tiến độ trả nợ gốc. Lãi suất chỉ để ghi nhớ, chưa tự tính vào số còn lại.', style: AppTypography.caption(context)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text('DANH SÁCH KHOẢN VAY', style: AppTypography.sectionLabel(context)),
      const SizedBox(height: 12),
      if (filtered.isEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(LucideIcons.handCoins, size: 48, color: AppColors.textMuted(context)),
                const SizedBox(height: 12),
                Text(
                  _selectedTab == 0 ? 'Bạn không có khoản nợ nào! Bấm + để thêm.' : 'Không có khoản cho vay nào. Bấm + để thêm.',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(context),
                ),
              ],
            ),
          ),
        )
      else
        ...filtered.map((loan) => _loanCard(context, loan)),
    ];
  }

  Widget _loanCard(BuildContext context, LoanItem loan) {
    final progress = loan.principalCents == BigInt.zero ? 0.0 : (loan.paidCents.toDouble() / loan.principalCents.toDouble()).clamp(0.0, 1.0);
    final done = loan.remainingCents == BigInt.zero;
    return Padding(
      key: ValueKey('loan-${loan.id}'),
      padding: const EdgeInsets.only(bottom: 14),
      child: LiquidGlassCard(
        variant: LiquidGlassVariant.subtle, // dòng trong list: không blur từng item
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Icon(LucideIcons.landmark, size: 18, color: AppColors.slateOn(context)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loan.title, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(
                        'Đối tác: ${loan.counterparty} • Lãi: ${loan.interestRateYear}%/năm',
                        style: AppTypography.caption(context).copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('edit-loan-${loan.id}'),
                  tooltip: 'Sửa khoản vay',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(LucideIcons.pencil, size: 18, color: AppColors.textMuted(context)),
                  onPressed: () => _editLoan(loan),
                ),
                IconButton(
                  key: ValueKey('delete-loan-${loan.id}'),
                  tooltip: 'Xóa khoản vay',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(LucideIcons.trash2, size: 18, color: AppColors.textMuted(context)),
                  onPressed: () => _delete(loan),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LiquidGlassProgressBar(value: progress, color: AppColors.secondary, height: 6),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text('Đã trả: ${formatVnd(loan.paidCents)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(context).copyWith(fontSize: 12))),
                const SizedBox(width: 8),
                Flexible(child: Text(
                  'Còn lại: ${formatVnd(loan.remainingCents)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(context).copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: done ? AppColors.safe : AppColors.danger,
                  ),
                )),
              ],
            ),
            if ((loan.accruedInterestCents ?? BigInt.zero) > BigInt.zero && !done) ...[
              const SizedBox(height: 6),
              Text(
                'Lãi tạm tính: ${formatVnd(loan.accruedInterestCents!)} • Cả gốc và lãi: ${formatVnd(loan.totalDueCents)}',
                key: ValueKey('loan-interest-${loan.id}'),
                style: AppTypography.caption(context).copyWith(fontSize: 11.5),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(
                  loan.dueDate == null ? 'Không đặt hạn' : 'Hạn cuối: ${DateFormat('dd/MM/yyyy').format(loan.dueDate!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(context).copyWith(fontSize: 11.5),
                )),
                if (!done)
                  AsyncActionBuilder(
                    onPressed: () => _recordRepayment(loan),
                    builder: (_, onTap, running) => OutlinedButton.icon(
                      key: ValueKey('repay-loan-${loan.id}'),
                      icon: running ? const ButtonLoadingIndicator(size: 16) : const Icon(LucideIcons.check, size: 14),
                      label: FittedBox(fit: BoxFit.scaleDown, child: Text(loan.type == LoanType.borrow ? 'Ghi nhận trả' : 'Ghi nhận thu hồi', maxLines: 1)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: const StadiumBorder()),
                      onPressed: onTap,
                    ),
                  )
                else
                  Text('Đã tất toán', style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700, color: AppColors.safe)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.activeFill(context) : Colors.transparent,
            borderRadius: AppSpacing.roundedPill,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppColors.activeFg(context) : AppColors.textPrimary(context),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoanInput {
  final String title;
  final String counterparty;
  final BigInt principalCents;
  final double interestRate;
  final DateTime? dueDate;
  final DateTime? startDate;
  const _LoanInput(this.title, this.counterparty, this.principalCents, this.interestRate, this.dueDate, this.startDate);
}

class _LoanFormDialog extends StatefulWidget {
  final LoanType type;
  final LoanItem? loan; // có = sửa
  const _LoanFormDialog({required this.type, this.loan});

  @override
  State<_LoanFormDialog> createState() => _LoanFormDialogState();
}

class _LoanFormDialogState extends State<_LoanFormDialog> {
  late final _title = TextEditingController(text: widget.loan?.title);
  late final _who = TextEditingController(text: widget.loan?.counterparty);
  late final _amount = TextEditingController(text: widget.loan == null ? '' : formatAmountDigits(widget.loan!.principalCents));
  late final _rate = TextEditingController(text: widget.loan == null || widget.loan!.interestRateYear == 0 ? '' : widget.loan!.interestRateYear.toString());
  late DateTime? _due = widget.loan?.dueDate;
  late DateTime? _start = widget.loan?.startDate;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _who.dispose();
    _amount.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _due ?? now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 50));
    if (picked != null) setState(() => _due = picked);
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _start ?? now, firstDate: DateTime(now.year - 30), lastDate: now);
    if (picked != null) setState(() => _start = picked);
  }

  void _submit() {
    final amount = parseAmountInput(_amount.text);
    final rate = _rate.text.trim().isEmpty ? 0.0 : double.tryParse(_rate.text.trim().replaceAll(',', '.'));
    if (_title.text.trim().isEmpty || _who.text.trim().isEmpty) {
      setState(() => _error = 'Nhập tên khoản vay và đối tác.');
    } else if (amount == null) {
      setState(() => _error = 'Nhập số tiền gốc lớn hơn 0.');
    } else if (rate == null || rate < 0 || rate > 100) {
      setState(() => _error = 'Lãi suất phải từ 0 đến 100 %/năm.');
    } else {
      Navigator.pop(context, _LoanInput(_title.text.trim(), _who.text.trim(), amount, rate, _due, _start));
    }
  }

  @override
  Widget build(BuildContext context) {
    final borrow = widget.type == LoanType.borrow;
    return GlassDialogShell(
      title: widget.loan != null ? 'Sửa khoản vay' : (borrow ? 'Thêm khoản đi vay' : 'Thêm khoản cho vay'),
      child: Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassTextField(key: const ValueKey('loan-title'), controller: _title, label: 'Tên khoản vay', hintText: 'Ví dụ: Vay mua xe', prefixIcon: LucideIcons.fileText),
              const SizedBox(height: 14),
              GlassTextField(
                key: const ValueKey('loan-counterparty'),
                controller: _who,
                label: borrow ? 'Vay của ai / ngân hàng nào' : 'Cho ai vay',
                hintText: borrow ? 'Ví dụ: Vietcombank' : 'Ví dụ: Nguyễn Văn Nam',
                prefixIcon: borrow ? LucideIcons.landmark : LucideIcons.user,
              ),
              const SizedBox(height: 14),
              // Số tiền và lãi suất cùng một hàng cho form gọn hơn; không đặt icon đầu ô để đủ chỗ cho số.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: GlassTextField(
                      key: const ValueKey('loan-amount'),
                      controller: _amount,
                      label: 'Số tiền gốc (₫)',
                      hintText: '0',
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: GlassTextField(
                      key: const ValueKey('loan-rate'),
                      controller: _rate,
                      label: 'Lãi %/năm',
                      hintText: '0',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Hai ngày cùng một hàng, mỗi ô một dòng (nhãn ngắn phía trên, giá trị bên trong).
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DateField(
                      key: const ValueKey('loan-start'),
                      label: 'Ngày vay',
                      icon: LucideIcons.calendarDays,
                      value: _start == null ? 'Hôm nay' : DateFormat('dd/MM/yyyy').format(_start!),
                      onTap: _pickStart,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateField(
                      key: const ValueKey('loan-due'),
                      label: 'Hạn cuối',
                      icon: LucideIcons.calendar,
                      value: _due == null ? 'Không bắt buộc' : DateFormat('dd/MM/yyyy').format(_due!),
                      muted: _due == null,
                      onTap: _pickDue,
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: GlassColors.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.circleAlert, size: 16, color: GlassColors.danger),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: GlassTypography.bodySm(color: GlassColors.danger))),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: GlassGhostButton(label: 'Hủy', onPressed: () => Navigator.pop(context))),
                  const SizedBox(width: 12),
                  Expanded(child: GlassPrimaryButton(key: const ValueKey('loan-save'), label: 'Lưu', onPressed: _submit)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ô chọn ngày dạng trường nhập kính: nhãn ngắn phía trên (cùng kiểu nhãn GlassTextField), giá trị một dòng bên trong.
class _DateField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final bool muted;
  final VoidCallback onTap;
  const _DateField({super.key, required this.label, required this.icon, required this.value, required this.onTap, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: '$label: $value',
          child: InkWell(
            onTap: onTap,
            borderRadius: GlassRadius.roundedInput,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: GlassColors.fieldFill,
                borderRadius: GlassRadius.roundedInput,
                border: Border.all(color: GlassColors.fieldBorder, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: GlassColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value, maxLines: 1, style: GlassTypography.bodyMd(color: muted ? GlassColors.textMuted : GlassColors.textPrimary)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RepayInput {
  final BigInt amountCents;
  final String? accountId;
  const _RepayInput(this.amountCents, this.accountId);
}

/// Bottom sheet kính "Ghi nhận trả nợ / thu hồi". Chỉ hiện phần có dữ liệu thật (khoản vay, ví);
/// phần Figma về kỳ trả, phân loại/hũ, đồng bộ lịch nợ chưa có API nên không dựng.
class _RepayDialog extends StatefulWidget {
  final LoanItem loan;
  final List<FinancialAccount> accounts;
  const _RepayDialog({required this.loan, required this.accounts});

  @override
  State<_RepayDialog> createState() => _RepayDialogState();
}

class _RepayDialogState extends State<_RepayDialog> {
  final _amount = TextEditingController();
  String? _accountId; // null: chỉ ghi sổ, không đụng ví
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.accounts.isNotEmpty) _accountId = widget.accounts.first.id;
    _amount.addListener(() => setState(() {})); // cập nhật nhãn nút xác nhận
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _setAmount(BigInt v) {
    _amount.text = formatAmountDigits(v);
    _amount.selection = TextSelection.collapsed(offset: _amount.text.length);
    setState(() => _error = null);
  }

  void _submit() {
    final amount = parseAmountInput(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Nhập số tiền lớn hơn 0.');
    } else if (amount > widget.loan.remainingCents) {
      setState(() => _error = 'Vượt quá số còn lại (${formatVnd(widget.loan.remainingCents)}).');
    } else {
      Navigator.pop(context, _RepayInput(amount, _accountId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final borrow = loan.type == LoanType.borrow;
    final amount = parseAmountInput(_amount.text);
    final half = loan.remainingCents ~/ BigInt.two;
    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          width: double.infinity,
          child: GlassCard(
            level: 3,
            padding: const EdgeInsets.all(17),
            borderRadius: GlassRadius.roundedCardLarge,
            child: Material(
              type: MaterialType.transparency,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(borrow ? LucideIcons.landmark : LucideIcons.handCoins, size: 16, color: GlassColors.ink),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(loan.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GlassTypography.bodySm(color: GlassColors.ink)),
                        ),
                        IconButton(
                          tooltip: 'Đóng',
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          icon: Icon(LucideIcons.x, size: 20, color: GlassColors.textSecondary),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                    Semantics(header: true, child: Text(borrow ? 'Ghi nhận trả nợ' : 'Ghi nhận thu hồi', style: GlassTypography.headlineSm())),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoCard(loan),
                            const SizedBox(height: 16),
                            Text('SỐ TIỀN THỰC ${borrow ? 'TRẢ' : 'THU'}', style: GlassTypography.labelCaps(color: GlassColors.textMuted)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: GlassColors.fieldFill,
                                borderRadius: GlassRadius.roundedInput,
                                border: Border.all(color: GlassColors.fieldBorder, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      key: const ValueKey('repay-amount'),
                                      controller: _amount,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                                      style: GlassTypography.headlineLg(color: GlassColors.textPrimary),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: '0',
                                        hintStyle: GlassTypography.headlineLg(color: GlassColors.textMuted),
                                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                    ),
                                  ),
                                  Text('₫', style: GlassTypography.bodyLg(color: GlassColors.textSecondary)),
                                ],
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Text(_error!, style: GlassTypography.bodySm(color: GlassColors.danger)),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: _chip('repay-chip-all', LucideIcons.circleCheck, 'Trả hết còn lại', loan.remainingCents, selected: amount == loan.remainingCents)),
                                if (half > BigInt.zero) ...[
                                  const SizedBox(width: 8),
                                  Expanded(child: _chip('repay-chip-half', LucideIcons.divide, 'Một nửa', half, selected: amount == half)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(borrow ? 'TRẢ TỪ VÍ' : 'NHẬN VÀO VÍ', style: GlassTypography.labelCaps(color: GlassColors.textMuted)),
                            const SizedBox(height: 8),
                            for (final a in widget.accounts) ...[
                              _accountCard(
                                key: ValueKey('repay-account-${a.id}'),
                                icon: LucideIcons.wallet,
                                title: a.name,
                                subtitle: 'Số dư ${formatVnd(a.balanceCents)}',
                                selected: _accountId == a.id,
                                onTap: () => setState(() => _accountId = a.id),
                              ),
                              const SizedBox(height: 8),
                            ],
                            _accountCard(
                              key: const ValueKey('repay-account'),
                              icon: LucideIcons.bookOpen,
                              title: 'Chỉ ghi sổ',
                              subtitle: null,
                              selected: _accountId == null,
                              onTap: () => setState(() => _accountId = null),
                            ),
                            if (_accountId == null) ...[
                              const SizedBox(height: 8),
                              Text('Chỉ ghi sổ, không đổi số dư ví.', style: GlassTypography.bodySm(color: GlassColors.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPrimaryButton(
                      key: const ValueKey('repay-save'),
                      icon: LucideIcons.circleCheck,
                      label: amount == null ? 'Xác nhận' : 'Xác nhận ${formatVnd(amount)}',
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: GlassGhostButton(label: 'Hủy', onPressed: () => Navigator.pop(context)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoCard(LoanItem loan) {
    final due = loan.dueDate;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GlassColors.glassFill,
        borderRadius: GlassRadius.roundedCard,
        border: Border.all(color: GlassColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  loan.counterparty.isEmpty ? loan.title : loan.counterparty,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (due != null) ...[
                const SizedBox(width: 8),
                Icon(LucideIcons.calendar, size: 14, color: GlassColors.textSecondary),
                const SizedBox(width: 4),
                Text('Hạn ${DateFormat('dd/MM/yyyy').format(due)}', style: GlassTypography.bodySm(color: GlassColors.textSecondary)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text('Số còn lại', style: GlassTypography.bodySm(color: GlassColors.textSecondary)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatVnd(loan.remainingCents), maxLines: 1, style: GlassTypography.headlineMd(color: GlassColors.textPrimary)),
          ),
          const SizedBox(height: 8),
          Text(
            'Gốc ${formatVnd(loan.principalCents)} · Đã trả ${formatVnd(loan.paidCents)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GlassTypography.bodySm(color: GlassColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _chip(String key, IconData icon, String label, BigInt value, {required bool selected}) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, ${formatVnd(value)}',
      child: ExcludeSemantics(
        child: Material(
          color: selected ? GlassColors.activeFill : GlassColors.fieldFill,
          shape: StadiumBorder(side: BorderSide(color: selected ? GlassColors.activeBorder : GlassColors.fieldBorder)),
          child: InkWell(
            key: ValueKey(key),
            customBorder: const StadiumBorder(),
            onTap: () => _setAmount(value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 16, color: selected ? GlassColors.activeFg : GlassColors.textSecondary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label, maxLines: 1, style: GlassTypography.bodyMd(color: selected ? GlassColors.activeFg : GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _accountCard({
    required Key key,
    required IconData icon,
    required String title,
    required String? subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? GlassColors.activeFill : GlassColors.fieldFill,
          borderRadius: GlassRadius.roundedInput,
          child: InkWell(
            key: key,
            borderRadius: GlassRadius.roundedInput,
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: GlassRadius.roundedInput,
                border: Border.all(color: selected ? GlassColors.activeBorder : GlassColors.fieldBorder, width: selected ? 1.5 : 1),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: selected ? GlassColors.activeFg : GlassColors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                        if (subtitle != null) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: GlassTypography.bodySm(color: GlassColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (selected) Icon(LucideIcons.check, size: 18, color: GlassColors.activeFg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
