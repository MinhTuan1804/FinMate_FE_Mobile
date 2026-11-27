import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/group_funds_repository.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/groups/domain/group_fund.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// Chủ nhóm hoặc người có quyền ManageFunds mới sửa/lưu trữ quỹ và quản lý dòng của người khác (BE kiểm lại ở mọi thao tác).
bool canManageFunds(GroupEntity group) => group.isOwner || group.myPermissions.contains(GroupPermission.manageFunds);

/// Tải lại mọi thứ phụ thuộc quỹ sau một thay đổi.
void refreshFund(WidgetRef ref, String groupId, String fundId) {
  ref.invalidate(groupFundsProvider(groupId));
  ref.invalidate(groupPrimaryFundProvider(groupId));
  ref.invalidate(groupFundSummaryProvider((groupId, fundId)));
  ref.invalidate(groupFundEntriesProvider((groupId, fundId)));
}

void _snack(ScaffoldMessengerState messenger, String text, {bool error = false}) {
  messenger.showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? GlassColors.danger : null));
}

/// Đầu tab Quỹ chung: tên và ghi chú quỹ; người có quyền quản lý quỹ thấy thêm nút Sửa và Lưu trữ.
class GroupFundHeader extends ConsumerWidget {
  final String groupId;
  final GroupFundEntity fund;

  const GroupFundHeader({super.key, required this.groupId, required this.fund});

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final input = await showDialog<({String name, String note})>(context: context, builder: (_) => _EditFundDialog(fund: fund));
    if (input == null || !context.mounted) return;
    // BE: trường null là giữ nguyên, ghi chú rỗng là xóa ghi chú. Chỉ gửi phần người dùng đã đổi.
    final name = input.name == fund.name ? null : input.name;
    final note = input.note == (fund.note ?? '') ? null : input.note;
    if (name == null && note == null) return;
    try {
      await ref.read(groupFundsRepositoryProvider).updateFund(groupId: groupId, fundId: fund.id, name: name, note: note);
      refreshFund(ref, groupId, fund.id);
      _snack(messenger, 'Đã cập nhật quỹ.');
    } catch (e) {
      _snack(messenger, errorMessage(e), error: true);
    }
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Lưu trữ quỹ "${fund.name}"?'),
        content: Text(
          'Quỹ chỉ lưu trữ được khi số dư bằng 0 (hiện là ${formatVnd(fund.balanceCents)}). '
          'Quỹ đã lưu trữ chỉ để xem: không ghi, sửa hay xóa dòng được nữa, và không thể bỏ lưu trữ.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(key: const ValueKey('confirm-archive-fund'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu trữ')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(groupFundsRepositoryProvider).archiveFund(groupId: groupId, fundId: fund.id);
      refreshFund(ref, groupId, fund.id);
      ref.invalidate(groupDetailProvider(groupId));
      _snack(messenger, 'Đã lưu trữ quỹ "${fund.name}".');
    } catch (e) {
      // Ví dụ GROUP_FUND_NOT_SETTLED khi số dư khác 0: thông điệp của BE nói rõ.
      _snack(messenger, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupDetailProvider(groupId)).valueOrNull;
    final canManage = group != null && canManageFunds(group);
    final note = fund.note;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        key: const ValueKey('fund-header'),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fund.name, key: const ValueKey('fund-header-name'), style: GlassTypography.headlineSm()),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(note, key: const ValueKey('fund-header-note'), style: GlassTypography.bodySm()),
                  ],
                ],
              ),
            ),
            if (canManage) ...[
              IconButton(
                key: const ValueKey('edit-fund'),
                tooltip: 'Sửa quỹ',
                visualDensity: VisualDensity.compact,
                icon: Icon(LucideIcons.pencil, size: 18, color: GlassColors.slateAnchor),
                onPressed: () => _edit(context, ref),
              ),
              IconButton(
                key: const ValueKey('archive-fund'),
                tooltip: 'Lưu trữ quỹ',
                visualDensity: VisualDensity.compact,
                icon: Icon(LucideIcons.archive, size: 18, color: GlassColors.slateAnchor),
                onPressed: () => _archive(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditFundDialog extends StatefulWidget {
  final GroupFundEntity fund;
  const _EditFundDialog({required this.fund});

  @override
  State<_EditFundDialog> createState() => _EditFundDialogState();
}

class _EditFundDialogState extends State<_EditFundDialog> {
  late final _name = TextEditingController(text: widget.fund.name);
  late final _note = TextEditingController(text: widget.fund.note ?? '');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nhập tên quỹ.');
      return;
    }
    Navigator.pop(context, (name: name, note: _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sửa quỹ'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('fund-name'),
              controller: _name,
              decoration: InputDecoration(labelText: 'Tên quỹ', errorText: _error),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('fund-note'),
              controller: _note,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Ghi chú (để trống nếu không cần)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        TextButton(key: const ValueKey('save-fund'), onPressed: _submit, child: const Text('Lưu')),
      ],
    );
  }
}

/// Menu Sửa/Xóa trên một dòng quỹ. Chủ dòng sửa được số tiền, nơi nhận, ghi chú; người quản lý quỹ chỉ sửa ghi chú của dòng người
/// khác (BE trả 403 nếu đổi số tiền). Quỹ đã lưu trữ hoặc dòng đã khóa thì BE từ chối kèm thông điệp.
class GroupFundEntryMenu extends ConsumerWidget {
  final String groupId;
  final String fundId;
  final GroupFundEntryEntity entry;

  const GroupFundEntryMenu({super.key, required this.groupId, required this.fundId, required this.entry});

  Future<void> _edit(BuildContext context, WidgetRef ref, {required bool isOwner}) async {
    final messenger = ScaffoldMessenger.of(context);
    final input = await showDialog<({BigInt? amount, String note, String merchant})>(
      context: context,
      builder: (_) => _EditEntryDialog(entry: entry, isOwner: isOwner),
    );
    if (input == null || !context.mounted) return;
    final amount = input.amount == null || input.amount == entry.amountCents ? null : input.amount;
    final note = input.note == (entry.note ?? '') ? null : input.note;
    final merchant = input.merchant == (entry.merchantName ?? '') ? null : input.merchant;
    if (amount == null && note == null && merchant == null) return;
    try {
      await ref
          .read(groupFundsRepositoryProvider)
          .updateEntry(groupId: groupId, fundId: fundId, entryId: entry.id, amountCents: amount, note: note, merchantName: merchant);
      refreshFund(ref, groupId, fundId);
      _snack(messenger, 'Đã cập nhật dòng quỹ.');
    } catch (e) {
      _snack(messenger, errorMessage(e), error: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, {required bool isOwner}) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa dòng quỹ này?'),
        content: Text(
          isOwner
              ? 'Nếu dòng này có giao dịch cá nhân gắn kèm, giao dịch đó sẽ bị xóa và ví của bạn được hoàn lại.'
              : 'Chỉ xóa dòng khỏi sổ quỹ; giao dịch cá nhân của người ghi vẫn được giữ nguyên.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(key: const ValueKey('confirm-delete-entry'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(groupFundsRepositoryProvider).deleteEntry(groupId: groupId, fundId: fundId, entryId: entry.id);
      refreshFund(ref, groupId, fundId);
      _snack(messenger, 'Đã xóa dòng quỹ.');
    } catch (e) {
      _snack(messenger, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserIdProvider);
    final group = ref.watch(groupDetailProvider(groupId)).valueOrNull;
    final isOwner = me != null && entry.memberUserId == me;
    final canManage = group != null && canManageFunds(group);
    if (!isOwner && !canManage) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      key: ValueKey('entry-menu-${entry.id}'),
      tooltip: 'Tùy chọn dòng quỹ',
      icon: Icon(LucideIcons.ellipsisVertical, size: 18, color: GlassColors.textMuted),
      onSelected: (v) => v == 'edit' ? _edit(context, ref, isOwner: isOwner) : _delete(context, ref, isOwner: isOwner),
      itemBuilder: (_) => [
        PopupMenuItem(key: ValueKey('entry-edit-${entry.id}'), value: 'edit', child: Text(isOwner ? 'Sửa' : 'Sửa ghi chú')),
        PopupMenuItem(key: ValueKey('entry-delete-${entry.id}'), value: 'delete', child: const Text('Xóa')),
      ],
    );
  }
}

class _EditEntryDialog extends StatefulWidget {
  final GroupFundEntryEntity entry;
  final bool isOwner;
  const _EditEntryDialog({required this.entry, required this.isOwner});

  @override
  State<_EditEntryDialog> createState() => _EditEntryDialogState();
}

class _EditEntryDialogState extends State<_EditEntryDialog> {
  late final _amount = TextEditingController(text: formatAmountDigits(widget.entry.amountCents));
  late final _note = TextEditingController(text: widget.entry.note ?? '');
  late final _merchant = TextEditingController(text: widget.entry.merchantName ?? '');
  String? _error;

  /// Số tiền chỉ chủ dòng sửa được (BE từ chối dòng người khác, 403). Dòng điều chỉnh có dấu âm/dương nên không sửa số tiền ở đây.
  bool get _canEditAmount => widget.isOwner && widget.entry.kind != GroupFundEntryKind.adjustment;
  bool get _canEditMerchant => widget.isOwner && widget.entry.kind == GroupFundEntryKind.expense;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _merchant.dispose();
    super.dispose();
  }

  void _submit() {
    BigInt? amount;
    if (_canEditAmount) {
      amount = parseAmountInput(_amount.text);
      if (amount == null) {
        setState(() => _error = 'Nhập số tiền lớn hơn 0.');
        return;
      }
    }
    Navigator.pop(context, (amount: amount, note: _note.text.trim(), merchant: _merchant.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isOwner ? 'Sửa dòng quỹ' : 'Sửa ghi chú'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canEditAmount) ...[
              TextField(
                key: const ValueKey('entry-amount'),
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: InputDecoration(labelText: 'Số tiền', suffixText: '₫', errorText: _error),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 12),
            ],
            if (_canEditMerchant) ...[
              TextField(key: const ValueKey('entry-merchant'), controller: _merchant, decoration: const InputDecoration(labelText: 'Nơi nhận')),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const ValueKey('entry-note'),
              controller: _note,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        TextButton(key: const ValueKey('save-entry'), onPressed: _submit, child: const Text('Lưu')),
      ],
    );
  }
}
