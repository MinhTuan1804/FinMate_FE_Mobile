import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/qr_transfers/domain/qr_transfer.dart';
import 'package:finmate/features/qr_transfers/presentation/controllers/qr_transfer_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

String _maskAccount(String account) => account.length <= 4 ? account : '•${account.substring(account.length - 4)}';

/// C4 — Người nhận đã lưu. Chỉ dữ liệu [CounterpartyOverrideEntity] thật sự có: ngân hàng, số
/// tài khoản, tên hiển thị, danh mục đã nhớ. KHÔNG có biệt danh riêng/yêu thích/thêm người nhận
/// tay/2 toggle (ghim chuyển nhanh, nhắc hạn mức) — API không hỗ trợ (chỉ sinh ra khi quét QR +
/// PATCH categoryId). Nút "Chuyển tiền" mở thẳng C2 với ngân hàng + số tài khoản điền sẵn.
class C4SavedBeneficiariesScreen extends ConsumerWidget {
  const C4SavedBeneficiariesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(counterpartyOverridesControllerProvider);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Người nhận đã lưu', style: GlassTypography.headlineMd()),
        ),
        body: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, __) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorMessage(e), style: GlassTypography.bodyMd(color: GlassColors.danger), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    TextButton(onPressed: () => ref.invalidate(counterpartyOverridesControllerProvider), child: const Text('Thử lại')),
                  ],
                ),
              ),
            ),
            data: (overrides) {
              if (overrides.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Chưa có người nhận nào được nhớ. Quét QR và chọn danh mục để lưu lại.',
                      style: GlassTypography.bodyMd(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  for (final o in overrides)
                    Padding(
                      key: ValueKey('c4-beneficiary-${o.id}'),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BeneficiaryCard(counterparty: o),
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

class _BeneficiaryCard extends StatelessWidget {
  final CounterpartyOverrideEntity counterparty;

  const _BeneficiaryCard({required this.counterparty});

  @override
  Widget build(BuildContext context) {
    final name = counterparty.displayName ?? counterparty.accountNumber;
    return GestureDetector(
      onTap: () => context.push('/qr-transfers/beneficiaries/edit', extra: counterparty),
      child: GlassCard(
        borderRadius: GlassRadius.roundedCardLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: GlassColors.secondarySurface, borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: Text(_initials(name), style: GlassTypography.bodyLg(color: GlassColors.slateAnchor).copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${counterparty.bankName} · ${_maskAccount(counterparty.accountNumber)}', style: GlassTypography.bodySm()),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: GlassColors.secondarySurface, borderRadius: GlassRadius.roundedPill),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.tag, size: 13, color: GlassColors.slateAnchor),
                      const SizedBox(width: 4),
                      Text(counterparty.categoryName, style: GlassTypography.bodySm(color: GlassColors.slateAnchor)),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  key: ValueKey('c4-transfer-${counterparty.id}'),
                  onPressed: () => context.push(
                    '/qr-transfers/confirm',
                    extra: {
                      'receiverBankBin': counterparty.bankBin,
                      'receiverAccountNumber': counterparty.accountNumber,
                      'receiverName': counterparty.displayName,
                    },
                  ),
                  icon: const Icon(LucideIcons.send, size: 15),
                  label: const Text('Chuyển tiền'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
