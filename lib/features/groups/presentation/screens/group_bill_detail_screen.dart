import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/groups/domain/group_debts.dart';
import 'package:finmate/features/groups/presentation/controllers/groups_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// Chi tiết một hóa đơn chia của nhóm: ai trả, bao nhiêu, chia thế nào và phần của từng người
/// (GET /groups/{id}/bills/{billId}). Hóa đơn không sửa hay xóa được và không gắn ví: chỉ để xem.
class GroupBillDetailScreen extends ConsumerWidget {
  final String groupId;
  final String billId;

  const GroupBillDetailScreen({super.key, required this.groupId, required this.billId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupBillDetailProvider((groupId, billId)));
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
          title: Text('Chi tiết hóa đơn', style: GlassTypography.headlineSm()),
        ),
        body: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorMessage(e), textAlign: TextAlign.center, style: GlassTypography.bodyMd(color: GlassColors.danger)),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: () => ref.invalidate(groupBillDetailProvider((groupId, billId))), child: const Text('Thử lại')),
                  ],
                ),
              ),
            ),
            data: (bill) => _Body(bill: bill),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final GroupBillEntity bill;
  const _Body({required this.bill});

  @override
  Widget build(BuildContext context) {
    final equal = bill.splitMode == 'Equal';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        GlassCard(
          key: const ValueKey('bill-summary'),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bill.title, style: GlassTypography.headlineSm()),
              const SizedBox(height: 6),
              Text(formatVnd(bill.amountCents), key: const ValueKey('bill-amount'), style: GlassTypography.displayHero().copyWith(fontSize: 28)),
              const SizedBox(height: 10),
              Text('${bill.paidByName} trả', style: GlassTypography.bodyMd()),
              Text(
                '${DateFormat('dd/MM/yyyy HH:mm').format(bill.occurredAt.toLocal())} • ${equal ? 'Chia đều' : 'Chia tùy chỉnh'}',
                style: GlassTypography.bodySm(color: GlassColors.textMuted),
              ),
              if (bill.note != null && bill.note!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(bill.note!, key: const ValueKey('bill-note'), style: GlassTypography.bodyMd()),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('PHẦN CHIA CỦA TỪNG NGƯỜI', style: GlassTypography.labelCaps(color: GlassColors.textMuted)),
        const SizedBox(height: 10),
        if (bill.splits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Chưa có phần chia nào để hiển thị.', key: const ValueKey('bill-no-splits'), style: GlassTypography.bodySm()),
          )
        else
          for (final s in bill.splits)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                key: ValueKey('split-${s.userId}'),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.userId == bill.paidByUserId ? '${s.displayName} (người trả)' : s.displayName,
                        style: GlassTypography.bodyMd(color: GlassColors.textPrimary),
                      ),
                    ),
                    Text(formatVnd(s.shareCents), style: GlassTypography.labelNumeric()),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
