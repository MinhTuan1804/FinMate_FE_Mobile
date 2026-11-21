import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/group_debts_repository.dart';
import 'package:finmate/features/groups/domain/group.dart';
import 'package:finmate/features/groups/domain/group_debts.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// Chia tiền bill mới (I3 → "Chia tiền bill mới"). Chọn người trả, những người cùng chia và cách chia:
/// `Equal` server tự chia đều (dồn phần dư cho người trả), `Custom` nhập từng phần và tổng phải bằng số tiền.
/// Hóa đơn không gắn ví và không sửa/xóa được; FinMate chỉ ghi nhận số nợ, không chuyển tiền thật.
class CreateBillScreen extends ConsumerStatefulWidget {
  final String groupId;
  const CreateBillScreen({super.key, required this.groupId});

  @override
  ConsumerState<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends ConsumerState<CreateBillScreen> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final Map<String, TextEditingController> _shares = {};
  final Set<String> _selected = {};
  String? _paidBy;
  bool _custom = false;
  bool _initialized = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    for (final c in _shares.values) {
      c.dispose();
    }
    super.dispose();
  }

  BigInt get _total => BigInt.tryParse(_amount.text.trim()) ?? BigInt.zero;

  BigInt get _customSum =>
      _selected.fold(BigInt.zero, (sum, id) => sum + (BigInt.tryParse(_shares[id]?.text.trim() ?? '') ?? BigInt.zero));

  void _init(List<GroupMemberEntity> members) {
    if (_initialized) return;
    _initialized = true;
    final me = ref.read(currentUserIdProvider);
    final active = members.where((m) => m.isActive).toList();
    _paidBy = active.any((m) => m.userId == me) ? me : (active.isEmpty ? null : active.first.userId);
    _selected.addAll(active.map((m) => m.userId));
    for (final m in active) {
      _shares[m.userId] = TextEditingController();
    }
  }

  String? _validate() {
    if (_title.text.trim().isEmpty) return 'Vui lòng nhập nội dung hóa đơn.';
    if (_total <= BigInt.zero) return 'Số tiền phải lớn hơn 0.';
    if (_paidBy == null) return 'Hãy chọn người đã trả.';
    if (_selected.isEmpty) return 'Chọn ít nhất một người cùng chia.';
    if (_custom && _customSum != _total) {
      return 'Tổng các phần (${formatVnd(_customSum)}) phải bằng số tiền hóa đơn (${formatVnd(_total)}).';
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final result = await ref.read(groupDebtsRepositoryProvider).createBill(
            groupId: widget.groupId,
            title: _title.text.trim(),
            amountCents: _total,
            paidByUserId: _paidBy!,
            splitMode: _custom ? 'Custom' : 'Equal',
            splits: [
              for (final id in _selected)
                GroupBillSplitInput(userId: id, shareCents: _custom ? (BigInt.tryParse(_shares[id]!.text.trim()) ?? BigInt.zero) : BigInt.zero),
            ],
            note: _note.text.trim(),
          );
      ref.invalidate(groupBillsProvider(widget.groupId));
      ref.invalidate(groupBalancesProvider(widget.groupId));
      ref.invalidate(groupApprovalsProvider(widget.groupId));
      ref.invalidate(groupsSummaryProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(result.isPending ? 'Hóa đơn đã gửi, chờ chủ nhóm duyệt (chưa tính vào sổ nợ).' : 'Đã chia hóa đơn.'),
      ));
      if (mounted) setState(() => _submitting = false);
      if (router.canPop()) router.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Chia tiền bill mới', style: GlassTypography.headlineSm()),
        ),
        body: SafeArea(
          child: membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, __) => Center(child: Text(errorMessage(e), style: GlassTypography.bodyMd(color: GlassColors.danger))),
            data: (members) {
              _init(members);
              final active = members.where((m) => m.isActive).toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          key: const ValueKey('bill-title'),
                          controller: _title,
                          maxLength: 120,
                          decoration: const InputDecoration(labelText: 'Nội dung (vd. Tiền điện tháng 11)'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const ValueKey('bill-amount'),
                          controller: _amount,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Tổng số tiền', suffixText: '₫'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: const ValueKey('bill-paid-by'),
                          initialValue: _paidBy,
                          decoration: const InputDecoration(labelText: 'Người đã trả'),
                          items: [for (final m in active) DropdownMenuItem(value: m.userId, child: Text(m.displayName))],
                          onChanged: (v) => setState(() => _paidBy = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cách chia', style: GlassTypography.headlineSm()),
                        const SizedBox(height: 8),
                        SegmentedButton<bool>(
                          key: const ValueKey('bill-split-mode'),
                          segments: const [
                            ButtonSegment(value: false, label: Text('Chia đều')),
                            ButtonSegment(value: true, label: Text('Tùy chỉnh')),
                          ],
                          selected: {_custom},
                          onSelectionChanged: (s) => setState(() => _custom = s.first),
                        ),
                        const SizedBox(height: 8),
                        for (final m in active)
                          Row(
                            key: ValueKey('bill-member-${m.userId}'),
                            children: [
                              Checkbox(
                                value: _selected.contains(m.userId),
                                onChanged: (v) => setState(() => v == true ? _selected.add(m.userId) : _selected.remove(m.userId)),
                              ),
                              Expanded(child: Text(m.displayName, style: GlassTypography.bodyMd(color: GlassColors.textPrimary))),
                              if (_custom && _selected.contains(m.userId))
                                SizedBox(
                                  width: 120,
                                  child: TextField(
                                    key: ValueKey('bill-share-${m.userId}'),
                                    controller: _shares[m.userId],
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onChanged: (_) => setState(() {}),
                                    textAlign: TextAlign.end,
                                    decoration: const InputDecoration(isDense: true, suffixText: '₫'),
                                  ),
                                ),
                            ],
                          ),
                        if (!_custom && _selected.isNotEmpty && _total > BigInt.zero)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Mỗi người khoảng ${formatVnd(_total ~/ BigInt.from(_selected.length))}',
                              style: GlassTypography.bodySm(color: GlassColors.textMuted),
                            ),
                          ),
                        if (_custom)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Đã chia ${formatVnd(_customSum)} / ${formatVnd(_total)}',
                              key: const ValueKey('bill-custom-sum'),
                              style: GlassTypography.bodySm(color: _customSum == _total ? GlassColors.success : GlassColors.textMuted),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    child: TextField(
                      key: const ValueKey('bill-note'),
                      controller: _note,
                      maxLength: 200,
                      decoration: const InputDecoration(labelText: 'Ghi chú (không bắt buộc)'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(LucideIcons.circleAlert, size: 16, color: GlassColors.danger),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, key: const ValueKey('bill-error'), style: GlassTypography.bodySm(color: GlassColors.danger))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      key: const ValueKey('bill-submit'),
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlassColors.ink,
                        foregroundColor: GlassColors.onInk,
                        shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                      ),
                      child: _submitting
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: GlassColors.onInk))
                          : Text('Chia hóa đơn', style: GlassTypography.buttonText()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'FinMate chỉ ghi nhận ai nợ ai bao nhiêu, không chuyển tiền thật.',
                    textAlign: TextAlign.center,
                    style: GlassTypography.bodySm(color: GlassColors.textMuted),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
