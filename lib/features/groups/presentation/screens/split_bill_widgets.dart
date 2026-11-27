import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/group_debts_repository.dart';
import 'package:finmate/features/groups/domain/group_debts.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_dialog.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';
import 'package:finmate/core/widgets/cursor_pager.dart';

void _refreshDebts(WidgetRef ref, String groupId) {
  ref.invalidate(groupBalancesProvider(groupId));
  ref.invalidate(groupBillsProvider(groupId));
  ref.invalidate(groupsSummaryProvider);
}

/// Gợi ý cấn trừ nợ ở đầu I3: các lượt chuyển tối giản từ `GET /balances`. Bấm "Đã trả" để ghi nhận một lượt
/// (`POST /settlements`) — FinMate chỉ ghi sổ, không chuyển tiền thật. Nhóm chọn cấn trừ thủ công không có gợi ý.
class GroupDebtSuggestionsCard extends ConsumerWidget {
  final String groupId;
  final bool isOwner;
  const GroupDebtSuggestionsCard({super.key, required this.groupId, required this.isOwner});

  Future<void> _settle(BuildContext context, WidgetRef ref, GroupDebtTransferEntity t, String fromName, String toName) async {
    final confirmed = await GlassDialog.confirm(
      context,
      title: 'Ghi nhận đã trả',
      message: '$fromName đã trả $toName ${formatVnd(t.amountCents)}? FinMate chỉ ghi sổ, không chuyển tiền thật.',
      confirmLabel: 'Đã trả',
      cancelLabel: 'Chưa',
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupDebtsRepositoryProvider).settle(
            groupId: groupId,
            fromUserId: t.fromUserId,
            toUserId: t.toUserId,
            amountCents: t.amountCents,
          );
      _refreshDebts(ref, groupId);
      messenger.showSnackBar(const SnackBar(content: Text('Đã ghi nhận khoản trả nợ')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e)), backgroundColor: GlassColors.danger));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserIdProvider);
    final balances = ref.watch(groupBalancesProvider(groupId)).valueOrNull;
    final transfers = balances?.transfers ?? const <GroupDebtTransferEntity>[];
    if (balances == null || transfers.isEmpty) return const SizedBox.shrink();
    String nameOf(String id) => id == me ? 'Bạn' : balances.members.firstWhere((m) => m.userId == id, orElse: () => GroupMemberBalanceEntity(userId: id, displayName: 'Thành viên', isActive: true, netCents: BigInt.zero)).displayName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        key: const ValueKey('debt-suggestions'),
        level: 2,
        borderRadius: GlassRadius.roundedCardLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.wandSparkles, size: 16, color: GlassColors.accentSkyBlue),
                const SizedBox(width: 6),
                Text('GỢI Ý CẤN TRỪ NỢ', style: GlassTypography.labelCaps(color: GlassColors.accentSkyBlue)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Chỉ cần ${transfers.length} lượt chuyển để cân bằng mọi khoản nợ:', style: GlassTypography.bodySm()),
            const SizedBox(height: 8),
            for (final t in transfers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: GlassTypography.bodyMd(color: GlassColors.textPrimary),
                          children: [
                            TextSpan(text: nameOf(t.fromUserId), style: const TextStyle(fontWeight: FontWeight.w700)),
                            const TextSpan(text: ' trả '),
                            TextSpan(text: nameOf(t.toUserId), style: const TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(text: ' ${formatVnd(t.amountCents)}'),
                          ],
                        ),
                      ),
                    ),
                    if (t.fromUserId == me || t.toUserId == me || isOwner)
                      AsyncActionBuilder(
                        onPressed: () => _settle(context, ref, t, nameOf(t.fromUserId), nameOf(t.toUserId)),
                        builder: (_, onTap, running) => TextButton(
                          key: ValueKey('settle-${t.fromUserId}-${t.toUserId}'),
                          onPressed: onTap,
                          child: running ? const ButtonLoadingIndicator() : const Text('Đã trả'),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Banner "N yêu cầu chờ duyệt" (hoặc của mình đang chờ) dẫn tới màn duyệt.
class GroupApprovalsBanner extends ConsumerWidget {
  final String groupId;
  const GroupApprovalsBanner({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(groupApprovalsProvider(groupId)).valueOrNull ?? const <GroupApprovalEntity>[];
    if (pending.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        key: const ValueKey('approvals-banner'),
        borderRadius: GlassRadius.roundedCard,
        onTap: () => context.push('/group-approvals', extra: groupId),
        child: GlassCard(
          child: Row(
            children: [
              Icon(LucideIcons.clockAlert, size: 20, color: GlassColors.warning),
              const SizedBox(width: 12),
              Expanded(child: Text('${pending.length} khoản đang chờ duyệt', style: GlassTypography.bodyMd(color: GlassColors.textPrimary))),
              Icon(LucideIcons.chevronRight, size: 18, color: GlassColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tab "Chia tiền" của I3: nút tạo bill mới + danh sách hóa đơn đã chia.
class GroupBillsTab extends ConsumerWidget {
  final String groupId;
  final bool canShare;
  const GroupBillsTab({super.key, required this.groupId, required this.canShare});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupBillsProvider(groupId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canShare)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                key: const ValueKey('new-bill'),
                onPressed: () => context.push('/group-bill-new', extra: groupId),
                icon: const Icon(LucideIcons.receiptText, size: 18),
                label: const Text('Chia tiền bill mới'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassColors.ink,
                  foregroundColor: GlassColors.onInk,
                  shape: RoundedRectangleBorder(borderRadius: GlassRadius.roundedPill),
                ),
              ),
            ),
          ),
        async.when(
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (e, __) => Row(
            children: [
              Expanded(child: Text(errorMessage(e), style: GlassTypography.bodySm(color: GlassColors.danger))),
              TextButton(onPressed: () => ref.invalidate(groupBillsProvider(groupId)), child: const Text('Thử lại')),
            ],
          ),
          data: (bills) {
            if (bills.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Chưa có hóa đơn nào được chia.', style: GlassTypography.bodyMd())),
              );
            }
            return Column(children: [
              for (final b in bills) _BillTile(bill: b, groupId: groupId),
              CursorPagerFooter(pager: ref.read(groupBillsProvider(groupId).notifier), auto: false),
            ]);
          },
        ),
      ],
    );
  }
}

class _BillTile extends StatelessWidget {
  final GroupBillEntity bill;
  final String groupId;
  const _BillTile({required this.bill, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/groups/$groupId/bills/${bill.id}'),
        child: GlassCard(
        key: ValueKey('bill-${bill.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(bill.title, style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600))),
                Text(formatVnd(bill.amountCents), style: GlassTypography.labelNumeric()),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${bill.paidByName} trả • chia ${bill.splitCount} người${bill.splitMode == "Equal" ? " đều" : ""} • ${DateFormat('dd/MM').format(bill.occurredAt.toLocal())}',
              style: GlassTypography.bodySm(color: GlassColors.textMuted),
            ),
            if (bill.note != null && bill.note!.isNotEmpty) Text(bill.note!, style: GlassTypography.bodySm()),
          ],
        ),
        ),
      ),
    );
  }
}

/// Dải "Đã góp" của từng thành viên ở cuối I3 (từ `GET /funds/{fundId}/summary` → `contributionsByMember`).
class GroupContributionsStrip extends ConsumerWidget {
  final String groupId;
  const GroupContributionsStrip({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fundId = ref.watch(groupPrimaryFundProvider(groupId)).valueOrNull?.id;
    if (fundId == null) return const SizedBox.shrink();
    final list = ref.watch(groupFundSummaryProvider((groupId, fundId))).valueOrNull?.contributionsByMember ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        key: const ValueKey('contributions-strip'),
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final c = list[i];
            return SizedBox(
              width: 150,
              child: GlassCard(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(c.memberName, style: GlassTypography.bodySm(), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('Đã góp: ${c.formattedAmount}', style: GlassTypography.labelNumeric(), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
