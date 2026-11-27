import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';
import 'package:finmate/features/recurring/presentation/controllers/recurring_items_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/transactions/data/transaction_links_repository.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finmate/features/transactions/domain/entities/transaction_links.dart';

/// Các thẻ "việc có thể làm tiếp" của một giao dịch, tất cả do BE gợi ý và quyết định (app không tự suy ra):
/// mục tiêu tiết kiệm, nghi trùng, gợi ý chuyển giữa các ví, khoản hoàn/đảo, dòng quỹ nhóm đã bị xóa.
///
/// [onChanged] chạy sau mỗi thay đổi tại chỗ (tải lại chi tiết và danh sách). [onGone] chạy khi giao dịch này không còn đứng một mình
/// (đã gộp vào giao dịch khác hoặc đã thành chuyển ví): màn chi tiết đóng lại.
/// Giao dịch người dùng đã trả lời "thu nhập thường" cho câu hỏi hoàn tiền: ẩn câu hỏi trong phiên này.
final _dismissedRefundSuggestions = StateProvider<Set<String>>((ref) => const {});

class TransactionLinksSection extends ConsumerWidget {
  final TransactionEntity tx;
  final Future<void> Function() onChanged;
  final VoidCallback onGone;

  const TransactionLinksSection({super.key, required this.tx, required this.onChanged, required this.onGone});

  TransactionLinks get _links => tx.links;

  static String sourceLabel(String source) => switch (source) {
        'Notification' => 'Thông báo ngân hàng',
        'Manual' => 'Bạn nhập tay',
        'Voice' => 'Nhập bằng giọng nói',
        'Receipt' => 'Quét hóa đơn',
        'Support' => 'Nhân viên hỗ trợ tạo hộ',
        _ => source,
      };

  static String transferKindLabel(String kind) => switch (kind) {
        'AtmWithdrawal' => 'Rút tiền ATM',
        'AtmDeposit' => 'Nạp tiền mặt tại ATM',
        'WalletTopup' => 'Nạp tiền vào ví điện tử',
        'WalletWithdrawal' => 'Rút tiền từ ví điện tử',
        'OwnAccount' => 'Chuyển giữa các tài khoản của bạn',
        _ => 'Chuyển tiền giữa các ví của bạn',
      };

  void _snack(BuildContext context, String text, {bool error = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? AppColors.danger : null, behavior: SnackBarBehavior.floating));
  }

  /// Chạy một thao tác; lỗi (kể cả 422 của BE) hiện nguyên thông điệp, không đóng màn.
  Future<T?> _guard<T>(BuildContext context, Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      _snack(context, errorMessage(e), error: true);
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = <Widget>[
      if (tx.type != TransactionType.transfer) _goalRow(context, ref),
      if (_recurringCard(context, ref) case final w?) w,
      if (_duplicateCard(context, ref) case final w?) w,
      if (_transferCard(context, ref) case final w?) w,
      if (_relatedCard(context, ref) case final w?) w,
      if (_refundInfo(context, ref) case final w?) w,
      if (_fundCard(context, ref) case final w?) w,
      if (_loanCard(context, ref) case final w?) w,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: c)],
    );
  }

  Widget _card(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required Color color,
    required String title,
    String? body,
    List<Widget> children = const [],
    List<Widget> actions = const [],
  }) {
    return LiquidGlassCard(
      key: key,
      variant: LiquidGlassVariant.subtle,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700))),
            ],
          ),
          if (body != null) ...[const SizedBox(height: 6), Text(body, style: AppTypography.caption(context))],
          ...children,
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 4, children: actions),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- mục tiêu

  Widget _goalRow(BuildContext context, WidgetRef ref) {
    final goalName = _links.goalName;
    return _card(
      context,
      key: const ValueKey('links-goal'),
      icon: LucideIcons.target,
      color: AppColors.secondary,
      title: goalName == null ? 'Chưa gắn mục tiêu tiết kiệm' : 'Mục tiêu: $goalName',
      body: goalName == null ? null : 'Chỉ là nhãn, không đổi số dư hay tiến độ mục tiêu.',
      actions: [
        if (goalName == null)
          OutlinedButton.icon(
            key: const ValueKey('attach-goal'),
            icon: const Icon(LucideIcons.plus, size: 14),
            label: const Text('Gắn mục tiêu'),
            onPressed: () => _attachGoal(context, ref),
          )
        else
          OutlinedButton.icon(
            key: const ValueKey('detach-goal'),
            icon: const Icon(LucideIcons.x, size: 14),
            label: const Text('Gỡ mục tiêu'),
            onPressed: () async {
              final done = await _guard(context, () => ref.read(transactionLinksRepositoryProvider).detachGoal(tx.id));
              if (done != null) await onChanged();
            },
          ),
      ],
    );
  }

  Future<void> _attachGoal(BuildContext context, WidgetRef ref) async {
    final goals = (ref.read(planningControllerProvider).valueOrNull?.savingsGoals ?? const []).where((g) => g.status == 'active').toList();
    if (goals.isEmpty) {
      _snack(context, 'Bạn chưa có mục tiêu tiết kiệm nào đang chạy.');
      return;
    }
    final goalId = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('Gắn vào mục tiêu nào?', style: TextStyle(fontWeight: FontWeight.w700))),
            for (final g in goals)
              ListTile(key: ValueKey('goal-option-${g.id}'), title: Text(g.title), onTap: () => Navigator.pop(ctx, g.id)),
          ],
        ),
      ),
    );
    if (goalId == null || !context.mounted) return;
    final done = await _guard(context, () => ref.read(transactionLinksRepositoryProvider).attachGoal(tx.id, goalId));
    if (done != null) await onChanged();
  }

  // ---------------------------------------------------------------- khoản định kỳ

  /// Chỉ giao dịch đã xác nhận, không phải chuyển ví và có tên nơi nhận hoặc mô tả mới tạo được khoản định kỳ (BE kiểm lại).
  Widget? _recurringCard(BuildContext context, WidgetRef ref) {
    final hasName = (tx.merchantName ?? '').trim().isNotEmpty || tx.description.trim().isNotEmpty;
    if (tx.status != TransactionStatus.confirmed || tx.type == TransactionType.transfer || !hasName) return null;
    return _card(
      context,
      key: const ValueKey('links-recurring'),
      icon: LucideIcons.repeat,
      color: AppColors.secondary,
      title: 'Lặp lại khoản này?',
      body: 'Tạo khoản định kỳ (tiền nhà, thuê bao, lương...) để FinMate đưa vào dự báo dòng tiền.',
      actions: [
        OutlinedButton.icon(
          key: const ValueKey('create-recurring'),
          icon: const Icon(LucideIcons.plus, size: 14),
          label: const Text('Tạo khoản định kỳ'),
          onPressed: () => _createRecurring(context, ref),
        ),
      ],
    );
  }

  Future<void> _createRecurring(BuildContext context, WidgetRef ref) async {
    final cadence = await showDialog<RecurringCadence>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Lặp lại bao lâu một lần?'),
        children: [
          for (final c in RecurringCadence.values)
            SimpleDialogOption(key: ValueKey('cadence-${c.name}'), onPressed: () => Navigator.pop(ctx, c), child: Text(c.label)),
        ],
      ),
    );
    if (cadence == null || !context.mounted) return;
    final item = await _guard(context, () => ref.read(transactionLinksRepositoryProvider).createRecurring(tx.id, cadence: cadence));
    if (item == null || !context.mounted) return;
    // Danh sách khoản định kỳ ở màn riêng: tải lại để khoản mới có mặt khi người dùng mở.
    ref.read(recurringItemsControllerProvider.notifier).load();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã tạo khoản định kỳ "${item.name}".'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Xem', onPressed: () => context.push('/recurring-items')),
      ),
    );
  }

  // ---------------------------------------------------------------- nghi trùng

  Widget? _duplicateCard(BuildContext context, WidgetRef ref) {
    final other = _links.duplicateCandidate;
    if (other == null) return null;
    final when = other.transactedAt == null ? '' : ' lúc ${DateFormat('dd/MM/yyyy HH:mm').format(other.transactedAt!)}';
    final who = [if ((other.merchantName ?? '').isNotEmpty) other.merchantName!, if ((other.accountName ?? '').isNotEmpty) other.accountName!].join(' • ');
    return _card(
      context,
      key: const ValueKey('links-duplicate'),
      icon: LucideIcons.copy,
      color: AppColors.warning,
      title: 'Có thể trùng với một giao dịch khác',
      body: '${sourceLabel(other.source)}: ${formatVnd(other.amountCents)}$when${who.isEmpty ? '' : '\n$who'}',
      actions: [
        OutlinedButton(
          key: const ValueKey('not-duplicate'),
          onPressed: () async {
            final done = await _guard(context, () => ref.read(transactionLinksRepositoryProvider).notDuplicate(tx.id));
            if (done != null) await onChanged();
          },
          child: const Text('Không trùng'),
        ),
        FilledButton(
          key: const ValueKey('merge-duplicate'),
          onPressed: () => _merge(context, ref, other),
          child: const Text('Xem và gộp'),
        ),
      ],
    );
  }

  Future<void> _merge(BuildContext context, WidgetRef ref, DuplicateSummary other) async {
    final repo = ref.read(transactionLinksRepositoryProvider);
    final preview = await _guard(context, () => repo.previewMerge(tx.id, other.id));
    if (preview == null || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gộp hai giao dịch?'),
        content: SingleChildScrollView(
          child: _PreviewBody(preview: preview, intro: 'Còn lại một giao dịch ${formatVnd(preview.survivor.amountCents)}. Số dư sau khi gộp:'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(key: const ValueKey('confirm-merge'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Gộp')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = await _guard(context, () => repo.merge(tx.id, other.id));
    if (done == null || !context.mounted) return;
    _snack(context, 'Đã gộp hai giao dịch.');
    await onChanged();
    onGone();
  }

  // ---------------------------------------------------------------- chuyển ví

  Widget? _transferCard(BuildContext context, WidgetRef ref) {
    final s = _links.transferSuggestion;
    if (s == null || tx.type == TransactionType.transfer) return null;
    final paired = s.paired;
    return _card(
      context,
      key: const ValueKey('links-transfer'),
      icon: LucideIcons.arrowLeftRight,
      color: AppColors.info,
      title: '${transferKindLabel(s.kind)}: có thể là chuyển giữa các ví của bạn',
      body: paired == null
          ? 'Nếu đúng, giao dịch này không tính là chi tiêu hay thu nhập.'
          : 'Khớp với giao dịch ${formatVnd(paired.amountCents)} ở ${paired.accountName ?? 'ví khác'}. '
              'Nếu đúng, hai giao dịch này gộp thành một lần chuyển và không tính là chi tiêu hay thu nhập.',
      actions: [
        OutlinedButton(
          key: const ValueKey('not-transfer'),
          onPressed: () async {
            final done = await _guard(context, () => ref.read(transactionLinksRepositoryProvider).notTransfer(tx.id));
            if (done != null) await onChanged();
          },
          child: const Text('Không phải'),
        ),
        FilledButton(key: const ValueKey('convert-transfer'), onPressed: () => _convert(context, ref, s), child: const Text('Đây là chuyển ví')),
      ],
    );
  }

  Future<void> _convert(BuildContext context, WidgetRef ref, TransferSuggestion s) async {
    final String? counterId;
    if (s.paired != null) {
      counterId = s.paired!.accountId;
    } else if (s.candidateAccounts.isEmpty) {
      // Ví dụ rút ATM mà chưa có ví Tiền mặt: BE không có ví nào để gợi ý.
      _snack(context, 'Bạn chưa có ví phù hợp để nhận khoản này. Hãy tạo ví (ví dụ Tiền mặt) trong Tài khoản & ví rồi thử lại.');
      return;
    } else {
      counterId = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(padding: EdgeInsets.all(16), child: Text('Chuyển với ví nào?', style: TextStyle(fontWeight: FontWeight.w700))),
              for (final a in s.candidateAccounts)
                ListTile(key: ValueKey('counter-${a.id}'), title: Text(a.name), onTap: () => Navigator.pop(ctx, a.id)),
            ],
          ),
        ),
      );
    }
    if (counterId == null || !context.mounted) return;

    final repo = ref.read(transactionLinksRepositoryProvider);
    final pairedId = s.paired?.id;
    final preview = await _guard(context, () => repo.previewConvertToTransfer(tx.id, counterId!, pairedTransactionId: pairedId));
    if (preview == null || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi thành chuyển ví?'),
        content: SingleChildScrollView(
          child: _PreviewBody(preview: preview, intro: 'Số dư các ví sau khi đổi:', feeLabel: 'Phí giao dịch sẽ được ghi riêng'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(key: const ValueKey('confirm-convert'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Đổi')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final requestId = const Uuid().v4();
    final done = await _guard(
      context,
      () => repo.convertToTransfer(tx.id, counterId!, pairedTransactionId: pairedId, clientRequestId: requestId),
    );
    if (done == null || !context.mounted) return;
    _snack(context, 'Đã đổi thành chuyển ví.');
    await onChanged();
    onGone();
  }

  // ---------------------------------------------------------------- hoàn / đảo

  Widget? _relatedCard(BuildContext context, WidgetRef ref) {
    if (_links.isRefundOrReversal) {
      final refund = _links.relation == 'Refund';
      return _card(
        context,
        key: const ValueKey('links-related'),
        icon: LucideIcons.undo2,
        color: AppColors.safe,
        title: refund ? 'Đây là khoản hoàn tiền của một khoản chi' : 'Đây là khoản đảo của một khoản chi',
        body: 'Không tính vào thu nhập; trừ vào chi tiêu của khoản gốc.',
        actions: [
          OutlinedButton(key: const ValueKey('unlink-related'), onPressed: () => _unlink(context, ref), child: const Text('Gỡ liên kết')),
        ],
      );
    }
    final suggestions = _links.suggestedRelated;
    if (suggestions.isEmpty || ref.watch(_dismissedRefundSuggestions).contains(tx.id)) return null;
    return _card(
      context,
      key: const ValueKey('links-related-suggest'),
      icon: LucideIcons.undo2,
      color: AppColors.info,
      title: 'Đây có phải tiền hoàn lại cho một khoản chi?',
      body: 'Chọn khoản chi gốc để không tính khoản này vào thu nhập.',
      children: [
        const SizedBox(height: 6),
        for (final s in suggestions)
          ListTile(
            key: ValueKey('related-option-${s.transactionId}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${s.merchantName ?? s.categoryName ?? 'Khoản chi'} • ${formatVnd(s.amountCents)}'),
            subtitle: s.transactedAt == null ? null : Text(DateFormat('dd/MM/yyyy').format(s.transactedAt!)),
            trailing: TextButton(onPressed: () => _link(context, ref, s), child: const Text('Chọn')),
          ),
      ],
      actions: [
        // Lựa chọn thứ ba: không phải hoàn tiền. Không gọi BE: khoản này vốn đã là thu nhập thường, chỉ ẩn câu hỏi.
        OutlinedButton(
          key: const ValueKey('related-dismiss'),
          onPressed: () => ref.read(_dismissedRefundSuggestions.notifier).update((s) => {...s, tx.id}),
          child: const Text('Thu nhập thường'),
        ),
      ],
    );
  }

  Future<void> _link(BuildContext context, WidgetRef ref, RefundSuggestion s) async {
    final relation = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Đây là gì của khoản chi này?'),
        children: [
          SimpleDialogOption(key: const ValueKey('relation-refund'), onPressed: () => Navigator.pop(ctx, 'Refund'), child: const Text('Hoàn tiền')),
          SimpleDialogOption(
            key: const ValueKey('relation-reversal'),
            onPressed: () => Navigator.pop(ctx, 'Reversal'),
            child: const Text('Đảo giao dịch (hủy giao dịch lỗi)'),
          ),
        ],
      ),
    );
    if (relation == null || !context.mounted) return;
    final done = await _guard(
      context,
      () => ref.read(transactionLinksRepositoryProvider).linkRelated(tx.id, relatedTransactionId: s.transactionId, relation: relation),
    );
    if (done != null) await onChanged();
  }

  Future<void> _unlink(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gỡ liên kết hoàn tiền?'),
        content: const Text('Khoản này sẽ trở lại thành thu nhập thường.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(key: const ValueKey('confirm-unlink'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Gỡ')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = await _guard(context, () => ref.read(transactionLinksRepositoryProvider).unlinkRelated(tx.id));
    if (done != null) await onChanged();
  }

  /// Khoản chi đã xác nhận: đã hoàn bao nhiêu (BE tính) và nút "Ghi hoàn tiền" khi còn hoàn được.
  Widget? _refundInfo(BuildContext context, WidgetRef ref) {
    final refunded = _links.refundedCents ?? BigInt.zero;
    if (_links.isReversed) {
      return _card(context, key: const ValueKey('links-reversed'), icon: LucideIcons.undo2, color: AppColors.safe, title: 'Khoản chi này đã bị đảo');
    }
    final remaining = _links.remainingRefundableCents;
    final canRefund = tx.type == TransactionType.expense && tx.status == TransactionStatus.confirmed && remaining != null && remaining > BigInt.zero;
    if (refunded <= BigInt.zero && !canRefund) return null;
    return _card(
      context,
      key: const ValueKey('links-refunded'),
      icon: LucideIcons.undo2,
      color: AppColors.safe,
      title: refunded > BigInt.zero ? 'Đã được hoàn ${formatVnd(refunded)}' : 'Được hoàn tiền cho khoản này?',
      body: remaining == null ? null : 'Còn có thể hoàn tối đa ${formatVnd(remaining)}.',
      actions: [
        if (canRefund)
          OutlinedButton(key: const ValueKey('record-refund'), onPressed: () => _recordRefund(context, ref, remaining), child: const Text('Ghi hoàn tiền')),
      ],
    );
  }

  Future<void> _recordRefund(BuildContext context, WidgetRef ref, BigInt remaining) async {
    final controller = TextEditingController(text: remaining.toString());
    final amount = await showDialog<BigInt>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ghi hoàn tiền'),
        content: TextField(
          key: const ValueKey('refund-amount'),
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Số tiền hoàn (đồng)', helperText: 'Tối đa ${formatVnd(remaining)}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            key: const ValueKey('confirm-refund'),
            onPressed: () => Navigator.pop(ctx, BigInt.tryParse(controller.text.replaceAll(RegExp(r'[^0-9]'), ''))),
            child: const Text('Ghi'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= BigInt.zero || !context.mounted) return;
    final done = await _guard(
      context,
      () => ref.read(transactionLinksRepositoryProvider).recordRefund(
            tx.id,
            amountCents: amount,
            transactedAt: DateTime.now(),
            financialAccountId: tx.accountId,
          ),
    );
    if (done == null || !context.mounted) return;
    _snack(context, 'Đã ghi hoàn ${formatVnd(amount)}.');
    await onChanged();
  }

  // ---------------------------------------------------------------- sổ vay

  Widget? _loanCard(BuildContext context, WidgetRef ref) {
    final link = _links.loanLink;
    if (link != null) {
      final kind = switch (link.kind) { 'principal' => 'Giải ngân', 'interest' => 'Tiền lãi', _ => 'Trả / thu nợ' };
      return _card(
        context,
        key: const ValueKey('links-loan'),
        icon: LucideIcons.handshake,
        color: AppColors.info,
        title: 'Thuộc khoản vay "${link.title}"',
        body: '$kind${link.counterparty == null ? '' : ' • ${link.counterparty}'}',
        actions: [
          OutlinedButton(key: const ValueKey('open-loan'), onPressed: () => context.push('/planning/loans/${link.loanId}'), child: const Text('Xem khoản vay')),
        ],
      );
    }
    final suggestions = _links.loanSuggestions;
    if (suggestions.isEmpty) return null;
    return _card(
      context,
      key: const ValueKey('links-loan-suggest'),
      icon: LucideIcons.handshake,
      color: AppColors.info,
      title: 'Đây có phải tiền trả nợ cho khoản vay?',
      body: 'Chọn khoản vay để ghi vào sổ vay. FinMate không tự gắn.',
      children: [
        const SizedBox(height: 6),
        for (final s in suggestions)
          ListTile(
            key: ValueKey('loan-option-${s.loanId}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${s.title}${s.counterparty == null ? '' : ' • ${s.counterparty}'}'),
            subtitle: Text([
              'Còn ${formatVnd(s.remainingCents)}',
              if (s.dueDate != null) 'hạn ${DateFormat('dd/MM/yyyy').format(s.dueDate!)}',
              if (s.interestCents > BigInt.zero) 'lãi ${formatVnd(s.interestCents)} tách riêng',
            ].join(' • ')),
            trailing: TextButton(onPressed: () => _linkLoan(context, ref, s), child: const Text('Gắn')),
          ),
      ],
    );
  }

  Future<void> _linkLoan(BuildContext context, WidgetRef ref, LoanSuggestion s) async {
    final repo = ref.read(transactionLinksRepositoryProvider);
    final done = await _guard(
      context,
      () async {
        if (tx.status == TransactionStatus.draft) {
          await repo.confirmWithLoan(tx.id, s.loanId);
        } else {
          await repo.linkToLoan(s.loanId, tx.id);
        }
        return true;
      },
    );
    if (done == null || !context.mounted) return;
    _snack(context, 'Đã ghi vào khoản vay "${s.title}".');
    await onChanged();
  }

  // ---------------------------------------------------------------- quỹ nhóm

  Widget? _fundCard(BuildContext context, WidgetRef ref) {
    final fund = _links.groupFundLink;
    if (fund == null) return null;
    if (!fund.entryDeleted) {
      return _card(
        context,
        key: const ValueKey('links-fund'),
        icon: LucideIcons.piggyBank,
        color: AppColors.info,
        title: 'Thuộc quỹ nhóm "${fund.fundName}"',
        body: 'Giao dịch này chỉ đổi được qua dòng quỹ của nhóm.',
      );
    }
    final canRestore = fund.kind == 'Expense';
    return _card(
      context,
      key: const ValueKey('links-fund-deleted'),
      icon: LucideIcons.piggyBank,
      color: AppColors.warning,
      title: 'Dòng quỹ "${fund.fundName}" đã bị người quản lý nhóm xóa',
      body: canRestore
          ? 'Giao dịch này vẫn ở sổ cá nhân của bạn dưới dạng chuyển. Bạn có thể khôi phục thành khoản chi với danh mục ban đầu.'
          : 'Giao dịch này vẫn ở sổ cá nhân của bạn. Bạn có thể xóa nó nếu không cần nữa.',
      actions: [
        if (canRestore)
          FilledButton(
            key: const ValueKey('restore-from-fund'),
            onPressed: () async {
              final done = await _guard(context, () => ref.read(transactionLinksRepositoryProvider).restoreFromFund(tx.id));
              if (done != null && context.mounted) {
                _snack(context, 'Đã khôi phục thành khoản chi.');
                await onChanged();
              }
            },
            child: const Text('Khôi phục khoản chi'),
          ),
      ],
    );
  }
}

/// Nội dung xem trước: số dư từng ví trước và sau, khoản phí (nếu có), cảnh báo của BE.
class _PreviewBody extends StatelessWidget {
  final TransactionPreview preview;
  final String intro;
  final String feeLabel;

  const _PreviewBody({required this.preview, required this.intro, this.feeLabel = 'Khoản phí'});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(intro),
        const SizedBox(height: 10),
        for (final b in preview.balanceChanges)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('${b.accountName}: ${formatVnd(b.beforeCents)} → ${formatVnd(b.afterCents)}', key: ValueKey('balance-${b.accountId}')),
          ),
        if (preview.fee != null) ...[
          const SizedBox(height: 8),
          Text('$feeLabel: ${formatVnd(preview.fee!.amountCents)}', key: const ValueKey('preview-fee')),
        ],
        for (final w in preview.warnings) ...[const SizedBox(height: 8), Text(w, style: TextStyle(color: AppColors.warning))],
      ],
    );
  }
}
