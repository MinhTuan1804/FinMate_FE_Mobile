import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/groups/data/group_debts_repository.dart';
import 'package:finmate/features/groups/domain/group_debts.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_buttons.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_dialog.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

/// Khoản chờ duyệt của nhóm. Chủ nhóm thấy của mọi người và duyệt/từ chối; người khác chỉ thấy yêu cầu của mình.
/// Khoản chờ chưa trừ quỹ, chưa vào ngân sách, báo cáo hay sổ nợ cho tới khi được duyệt.
class GroupApprovalsScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupApprovalsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupApprovalsScreen> createState() => _GroupApprovalsScreenState();
}

class _GroupApprovalsScreenState extends ConsumerState<GroupApprovalsScreen> {
  bool _showAll = false;
  String? _busyId;

  String _kindLabel(String kind) => kind == 'FundEntry' ? 'Chi/rút quỹ' : 'Hóa đơn chia';

  String _statusLabel(String s) => switch (s) {
        'Approved' => 'Đã duyệt',
        'Rejected' => 'Đã từ chối',
        _ => 'Chờ duyệt',
      };

  Future<void> _decide(GroupApprovalEntity a, {required bool approve}) async {
    String? reason;
    if (!approve) {
      final controller = TextEditingController();
      final ok = await GlassDialog.custom<bool>(
        context,
        title: 'Từ chối khoản này?',
        contentBuilder: (ctx, setState) => TextField(
          key: const ValueKey('reject-reason'),
          controller: controller,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Lý do (không bắt buộc)'),
        ),
        actionsBuilder: (ctx, setState) => Row(
          children: [
            Expanded(child: GlassGhostButton(onPressed: () => Navigator.pop(ctx, false), label: 'Hủy')),
            const SizedBox(width: 12),
            Expanded(child: GlassPrimaryButton(key: const ValueKey('reject-confirm'), label: 'Từ chối', onPressed: () => Navigator.pop(ctx, true))),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      reason = controller.text.trim();
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyId = a.id);
    try {
      final repo = ref.read(groupDebtsRepositoryProvider);
      if (approve) {
        await repo.approve(groupId: widget.groupId, approvalId: a.id);
      } else {
        await repo.reject(groupId: widget.groupId, approvalId: a.id, reason: reason);
      }
      ref.invalidate(groupApprovalsProvider(widget.groupId));
      ref.invalidate(groupBillsProvider(widget.groupId));
      ref.invalidate(groupBalancesProvider(widget.groupId));
      ref.invalidate(groupPrimaryFundProvider(widget.groupId));
      ref.read(groupsControllerProvider.notifier).load(silent: true);
      messenger.showSnackBar(SnackBar(content: Text(approve ? 'Đã duyệt khoản này' : 'Đã từ chối khoản này')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupDetailProvider(widget.groupId)).valueOrNull;
    final isOwner = group?.isOwner ?? false;
    final async = _showAll
        ? ref.watch(_allApprovalsProvider(widget.groupId))
        : ref.watch(groupApprovalsProvider(widget.groupId));
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Khoản chờ duyệt', style: GlassTypography.headlineSm()),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              SegmentedButton<bool>(
                key: const ValueKey('approvals-filter'),
                segments: const [
                  ButtonSegment(value: false, label: Text('Chờ duyệt')),
                  ButtonSegment(value: true, label: Text('Tất cả')),
                ],
                selected: {_showAll},
                onSelectionChanged: (s) => setState(() => _showAll = s.first),
              ),
              const SizedBox(height: 12),
              async.when(
                loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                error: (e, __) => Text(errorMessage(e), style: GlassTypography.bodySm(color: GlassColors.danger)),
                data: (list) {
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text(_showAll ? 'Chưa có khoản nào.' : 'Không có khoản nào đang chờ duyệt.', style: GlassTypography.bodyMd())),
                    );
                  }
                  return Column(
                    children: [
                      for (final a in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            key: ValueKey('approval-${a.id}'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(a.title, style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600))),
                                    Text(formatVnd(a.amountCents), style: GlassTypography.labelNumeric()),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    GlassBadge(text: _kindLabel(a.kind)),
                                    GlassBadge(
                                      text: _statusLabel(a.status),
                                      color: a.status == 'Approved' ? GlassColors.success : (a.status == 'Rejected' ? GlassColors.danger : null),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${a.requestedByName} gửi lúc ${DateFormat('dd/MM HH:mm').format(a.createdAt.toLocal())}',
                                  style: GlassTypography.bodySm(color: GlassColors.textMuted),
                                ),
                                if (a.decisionReason != null && a.decisionReason!.isNotEmpty)
                                  Text('Lý do: ${a.decisionReason}', style: GlassTypography.bodySm()),
                                if (isOwner && a.isPending) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: AsyncActionBuilder(
                                          onPressed: _busyId == null ? () => _decide(a, approve: false) : null,
                                          builder: (_, onTap, running) => OutlinedButton(
                                            key: ValueKey('reject-${a.id}'),
                                            onPressed: onTap,
                                            child: running ? const ButtonLoadingIndicator() : const Text('Từ chối'),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: AsyncActionBuilder(
                                          onPressed: _busyId == null ? () => _decide(a, approve: true) : null,
                                          builder: (_, onTap, running) => FilledButton(
                                            key: ValueKey('approve-${a.id}'),
                                            onPressed: onTap,
                                            style: FilledButton.styleFrom(backgroundColor: GlassColors.ink, foregroundColor: GlassColors.onInk),
                                            child: running ? const ButtonLoadingIndicator() : const Text('Duyệt'),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _allApprovalsProvider = FutureProvider.autoDispose.family<List<GroupApprovalEntity>, String>(
  (ref, groupId) => ref.watch(groupDebtsRepositoryProvider).getApprovals(groupId, status: 'All'),
);
