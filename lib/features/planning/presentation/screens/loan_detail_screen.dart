import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/planning/data/loans_repository.dart';

/// Chi tiết một khoản vay: các dòng giải ngân/trả, thêm gốc, xóa một dòng, xóa nợ (GET /loans/{id}, POST principal,
/// DELETE entries, POST write-off). Số dư còn lại, lãi tạm tính, trạng thái đều do BE tính.
class LoanDetailScreen extends ConsumerStatefulWidget {
  final String loanId;

  const LoanDetailScreen({super.key, required this.loanId});

  @override
  ConsumerState<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _AddPrincipalInput {
  final BigInt amountCents;
  final String? accountId;
  const _AddPrincipalInput(this.amountCents, this.accountId);
}

class _LoanDetailScreenState extends ConsumerState<LoanDetailScreen> {
  void _toast(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? AppColors.danger : null));
  }

  /// Sau mỗi thay đổi: tải lại chi tiết, danh sách và thẻ tổng hợp ở màn danh sách.
  void _refreshAll() {
    ref.invalidate(loanDetailProvider(widget.loanId));
    ref.invalidate(loansProvider);
    ref.invalidate(loansSummaryProvider);
  }

  Future<void> _addPrincipal(LoanItem loan) async {
    final accounts = ref.read(accountsControllerProvider).valueOrNull ?? const <FinancialAccount>[];
    final input = await showDialog<_AddPrincipalInput>(
      context: context,
      builder: (_) => _AddPrincipalDialog(loan: loan, accounts: accounts),
    );
    if (input == null) return;
    try {
      await ref.read(loansRepositoryProvider).addPrincipal(loanId: loan.id, amountCents: input.amountCents, financialAccountId: input.accountId);
      _refreshAll();
      _toast(loan.type == LoanType.borrow ? 'Đã ghi nhận vay thêm.' : 'Đã ghi nhận cho mượn thêm.');
    } catch (e) {
      _toast(errorMessage(e), error: true);
    }
  }

  Future<void> _deleteEntry(LoanItem loan, LoanEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa dòng này?'),
        content: const Text(
          'Dòng sẽ được gỡ khỏi sổ vay; giao dịch ví đã gắn (nếu có) vẫn giữ nguyên. '
          'Nếu đây là dòng giải ngân cuối cùng, cả khoản vay sẽ bị xóa theo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(key: const ValueKey('confirm-delete-entry'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final after = await ref.read(loansRepositoryProvider).deleteEntry(loanId: loan.id, entryId: entry.id);
      _refreshAll();
      if (after == null) {
        // BE trả 204: khoản không còn dòng nào nên đã bị xóa, màn này không còn gì để hiện.
        _toast('Khoản vay không còn dòng nào nên đã được xóa.');
        if (mounted) context.pop();
      } else {
        _toast('Đã xóa dòng.');
      }
    } catch (e) {
      _toast(errorMessage(e), error: true);
    }
  }

  Future<void> _writeOff(LoanItem loan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa nợ khoản này?'),
        content: const Text(
          'Khoản vay sẽ được đóng và không còn tính là nợ. Việc này không tạo giao dịch và không đổi số dư ví của bạn.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(key: const ValueKey('confirm-write-off'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa nợ')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(loansRepositoryProvider).writeOff(loan.id);
      _refreshAll();
      _toast('Đã xóa nợ.');
    } catch (e) {
      _toast(errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(accountsControllerProvider); // giữ danh sách ví đã tải sẵn cho hộp thoại thêm gốc
    final async = ref.watch(loanDetailProvider(widget.loanId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết khoản vay'),
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft), onPressed: () => context.pop()),
      ),
      body: AmbientGlassBackground(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(errorMessage(e), textAlign: TextAlign.center, style: AppTypography.body(context)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: () => ref.invalidate(loanDetailProvider(widget.loanId)), child: const Text('Thử lại')),
                ],
              ),
            ),
          ),
          data: (detail) => RefreshIndicator(
            onRefresh: () async => ref.refresh(loanDetailProvider(widget.loanId).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              children: [
                _header(context, detail.loan),
                const SizedBox(height: 14),
                _actions(context, detail.loan),
                const SizedBox(height: 24),
                Text('LỊCH SỬ', style: AppTypography.sectionLabel(context)),
                const SizedBox(height: 12),
                if (detail.entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('Chưa có dòng nào.', textAlign: TextAlign.center, style: AppTypography.caption(context)),
                  )
                else
                  for (final e in _newestFirst(detail.entries)) _entryTile(context, detail.loan, e),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<LoanEntry> _newestFirst(List<LoanEntry> entries) {
    final sorted = [...entries];
    sorted.sort((a, b) => (b.at ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.at ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return sorted;
  }

  static String _statusLabel(String status) => switch (status) {
        'settled' => 'Đã tất toán',
        'written_off' => 'Đã xóa nợ',
        _ => 'Đang mở',
      };

  Widget _header(BuildContext context, LoanItem loan) {
    final borrow = loan.type == LoanType.borrow;
    final progress = loan.principalCents == BigInt.zero ? 0.0 : (loan.paidCents.toDouble() / loan.principalCents.toDouble()).clamp(0.0, 1.0);
    final accrued = loan.accruedInterestCents ?? BigInt.zero;
    return LiquidGlassCard(
      variant: LiquidGlassVariant.subtle,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(loan.title, style: AppTypography.h3(context))),
              Container(
                key: const ValueKey('loan-status'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (loan.isClosed ? AppColors.safe : AppColors.info).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(_statusLabel(loan.status), style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${borrow ? 'Tôi nợ' : 'Cho vay'}: ${loan.counterparty}', style: AppTypography.caption(context)),
          const SizedBox(height: 14),
          LiquidGlassProgressBar(value: progress, color: AppColors.secondary, height: 6),
          const SizedBox(height: 10),
          _row(context, 'Gốc', formatVnd(loan.principalCents)),
          _row(context, borrow ? 'Đã trả' : 'Đã thu hồi', formatVnd(loan.paidCents)),
          _row(
            context,
            'Còn lại',
            formatVnd(loan.remainingCents),
            valueColor: loan.isClosed ? AppColors.safe : AppColors.danger,
            valueKey: const ValueKey('loan-remaining'),
          ),
          if (accrued > BigInt.zero && !loan.isClosed) _row(context, 'Lãi tạm tính (${loan.interestRateYear}%/năm)', formatVnd(accrued)),
          _row(context, 'Hạn cuối', loan.dueDate == null ? 'Không đặt hạn' : DateFormat('dd/MM/yyyy').format(loan.dueDate!)),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {Color? valueColor, Key? valueKey}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(label, style: AppTypography.caption(context))),
            const SizedBox(width: 8),
            Text(
              value,
              key: valueKey,
              style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, color: valueColor),
            ),
          ],
        ),
      );

  Widget _actions(BuildContext context, LoanItem loan) {
    final borrow = loan.type == LoanType.borrow;
    return Row(
      children: [
        Expanded(
          child: AsyncActionBuilder(
            onPressed: () => _addPrincipal(loan),
            builder: (_, onTap, running) => OutlinedButton.icon(
              key: const ValueKey('add-principal'),
              icon: running ? const ButtonLoadingIndicator(size: 16) : const Icon(LucideIcons.plus, size: 16),
              label: FittedBox(fit: BoxFit.scaleDown, child: Text(borrow ? 'Vay thêm' : 'Cho mượn thêm', maxLines: 1)),
              onPressed: onTap,
            ),
          ),
        ),
        // Chỉ khoản đang mở mới xóa nợ được: khoản đã tất toán BE từ chối (LOAN_ALREADY_SETTLED), khoản đã xóa nợ thì không có gì để đổi.
        if (loan.status == 'open') ...[
          const SizedBox(width: 10),
          Expanded(
            child: AsyncActionBuilder(
              onPressed: () => _writeOff(loan),
              builder: (_, onTap, running) => OutlinedButton.icon(
                key: const ValueKey('write-off'),
                icon: running ? const ButtonLoadingIndicator(size: 16) : const Icon(LucideIcons.eraser, size: 16),
                label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Xóa nợ', maxLines: 1)),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: onTap,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _entryTile(BuildContext context, LoanItem loan, LoanEntry entry) {
    final borrow = loan.type == LoanType.borrow;
    final principal = entry.kind == LoanEntryKind.principal;
    final label = principal ? (borrow ? 'Vay / giải ngân' : 'Cho vay / giải ngân') : (borrow ? 'Trả nợ' : 'Thu hồi');
    final notes = [
      if (entry.transactionId != null) 'Đã gắn giao dịch ví' else 'Chỉ ghi sổ',
      if (entry.interestTransactionId != null) 'Kèm giao dịch lãi',
    ].join(' • ');
    return Padding(
      key: ValueKey('entry-${entry.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: LiquidGlassCard(
        variant: LiquidGlassVariant.subtle,
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(
          children: [
            Icon(principal ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft, size: 18, color: principal ? AppColors.danger : AppColors.safe),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    [if (entry.at != null) DateFormat('dd/MM/yyyy HH:mm').format(entry.at!.toLocal()), notes].join(' • '),
                    style: AppTypography.caption(context).copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(formatVnd(entry.amountCents), style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700)),
            IconButton(
              key: ValueKey('delete-entry-${entry.id}'),
              tooltip: 'Xóa dòng',
              visualDensity: VisualDensity.compact,
              icon: Icon(LucideIcons.trash2, size: 18, color: AppColors.textMuted(context)),
              onPressed: () => _deleteEntry(loan, entry),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hộp thoại "Vay thêm / Cho mượn thêm": số tiền và (tùy chọn) ví để BE ghi giao dịch tương ứng.
/// Mặc định "Chỉ ghi sổ": thêm gốc không tự động đụng tới tiền trong ví nếu người dùng chưa chọn.
class _AddPrincipalDialog extends StatefulWidget {
  final LoanItem loan;
  final List<FinancialAccount> accounts;
  const _AddPrincipalDialog({required this.loan, required this.accounts});

  @override
  State<_AddPrincipalDialog> createState() => _AddPrincipalDialogState();
}

class _AddPrincipalDialogState extends State<_AddPrincipalDialog> {
  final _amount = TextEditingController();
  String? _accountId;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = parseAmountInput(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Nhập số tiền lớn hơn 0.');
      return;
    }
    Navigator.pop(context, _AddPrincipalInput(amount, _accountId));
  }

  @override
  Widget build(BuildContext context) {
    final borrow = widget.loan.type == LoanType.borrow;
    return AlertDialog(
      title: Text(borrow ? 'Vay thêm' : 'Cho mượn thêm'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('principal-amount'),
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: InputDecoration(labelText: 'Số tiền', suffixText: '₫', errorText: _error),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              key: const ValueKey('principal-account'),
              initialValue: _accountId,
              isExpanded: true,
              decoration: InputDecoration(labelText: borrow ? 'Tiền vay nhận vào ví' : 'Tiền cho mượn trừ từ ví'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Chỉ ghi sổ')),
                for (final a in widget.accounts) DropdownMenuItem<String?>(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 8),
            Text(
              _accountId == null ? 'Chỉ ghi sổ, không đổi số dư ví.' : 'FinMate sẽ ghi giao dịch tương ứng vào ví đã chọn.',
              style: AppTypography.caption(context),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        TextButton(key: const ValueKey('principal-save'), onPressed: _submit, child: const Text('Xác nhận')),
      ],
    );
  }
}
