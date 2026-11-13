import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/features/qr_transfers/domain/qr_transfer.dart';
import 'package:finmate/features/qr_transfers/presentation/controllers/qr_transfer_controller.dart';
import 'package:finmate/shared/widgets/glass/glass_background.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_filter_chip.dart';

enum _HistoryPill { all, transfer, billPayment }

// §16.9: đổi chữ để đọc đúng là tiến trình khớp quét-QR, không phải một bản Draft/Confirmed
// thứ hai gây lẫn với D1 (Lịch sử giao dịch) — 2 màn cùng dữ liệu nhưng 2 câu hỏi khác nhau.
String _statusLabel(String value) => switch (value) {
      'Pending' => 'Chờ ngân hàng xác nhận',
      'Matched' => 'Đã khớp vào sổ giao dịch',
      'Cancelled' => 'Đã hủy ý định',
      _ => value,
    };

Color _statusColor(String value) => switch (value) {
      'Pending' => GlassColors.warning,
      'Matched' => GlassColors.success,
      'Cancelled' => GlassColors.danger,
      _ => GlassColors.textMuted,
    };

String _groupLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  if (day == today) return 'Hôm nay';
  if (day == today.subtract(const Duration(days: 1))) return 'Hôm qua';
  return DateFormat('dd/MM/yyyy').format(d);
}

/// C3 — Lịch sử quét QR. Tổng/tháng + số lượng tính từ [listTransfers] phía client, không có
/// endpoint tổng hợp riêng. BE không phân biệt "chuyển tiền" vs "thanh toán hoá đơn" (không có
/// trường loại giao dịch QR), nên pill "Thanh toán hóa đơn" luôn hiện 0 thay vì bịa số — mọi
/// giao dịch QR hiện có đều tính vào "Chuyển tiền". "Đã lưu người nhận" chỉ là nút điều hướng
/// sang C4, không lọc danh sách.
///
/// §16.9: không hiện chip danh mục tài chính trên mỗi dòng — đó là khái niệm của Transaction
/// (D1), không phải của QrTransferIntent (C3). Dòng đã khớp ("Đã khớp vào sổ giao dịch") bấm vào
/// để sang D1 (`/transactions`) — chưa có màn chi tiết 1 giao dịch riêng nên trỏ vào danh sách,
/// không bịa link; `QrTransferEntity.matchedTransactionId` đã có sẵn trên model, dùng được ngay
/// khi D1 có màn chi tiết riêng ở Luồng sau (không đụng D1 trong task này).
class C3HistoryScreen extends ConsumerStatefulWidget {
  const C3HistoryScreen({super.key});

  @override
  ConsumerState<C3HistoryScreen> createState() => _C3HistoryScreenState();
}

class _C3HistoryScreenState extends ConsumerState<C3HistoryScreen> {
  _HistoryPill _pill = _HistoryPill.all;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(qrTransfersControllerProvider);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Lịch sử quét QR', style: GlassTypography.headlineMd()),
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
                    TextButton(onPressed: () => ref.invalidate(qrTransfersControllerProvider), child: const Text('Thử lại')),
                  ],
                ),
              ),
            ),
            data: (transfers) => _buildContent(context, transfers),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<QrTransferEntity> transfers) {
    final now = DateTime.now();
    final monthTransfers = transfers.where((t) => t.scannedAt.year == now.year && t.scannedAt.month == now.month).toList();
    final monthTotal = monthTransfers.fold(BigInt.zero, (sum, t) => sum + t.amountCents);

    final grouped = <String, List<QrTransferEntity>>{};
    for (final t in transfers) {
      grouped.putIfAbsent(_groupLabel(t.scannedAt), () => []).add(t);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        GlassCard(
          level: 2,
          borderRadius: GlassRadius.roundedCardLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat('MMMM yyyy', 'vi_VN').format(now), style: GlassTypography.bodyMd()),
                  GlassBadge(text: '${monthTransfers.length} lần quét', color: GlassColors.success),
                ],
              ),
              const SizedBox(height: 8),
              Text('Tổng giao dịch QR tháng ${now.month}', style: GlassTypography.bodySm()),
              const SizedBox(height: 2),
              Text('${NumberFormat('#,###', 'vi_VN').format(monthTotal.toInt())} ₫', style: GlassTypography.displayHero()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GlassFilterChip(
                key: const ValueKey('c3-pill-all'),
                label: 'Tất cả',
                count: transfers.length,
                selected: _pill == _HistoryPill.all,
                onTap: () => setState(() => _pill = _HistoryPill.all),
              ),
              const SizedBox(width: 8),
              GlassFilterChip(
                key: const ValueKey('c3-pill-transfer'),
                label: 'Chuyển tiền',
                count: transfers.length,
                selected: _pill == _HistoryPill.transfer,
                onTap: () => setState(() => _pill = _HistoryPill.transfer),
              ),
              const SizedBox(width: 8),
              GlassFilterChip(
                key: const ValueKey('c3-pill-bill'),
                label: 'Thanh toán hóa đơn',
                count: 0,
                selected: _pill == _HistoryPill.billPayment,
                onTap: () => setState(() => _pill = _HistoryPill.billPayment),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                key: const ValueKey('c3-pill-saved-beneficiaries'),
                onTap: () => context.push('/qr-transfers/beneficiaries'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: GlassColors.glassFill,
                    borderRadius: GlassRadius.roundedPill,
                    border: Border.all(color: GlassColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.bookmark, size: 14, color: GlassColors.slateAnchor),
                      const SizedBox(width: 6),
                      Text('Đã lưu người nhận', style: GlassTypography.bodyMd(color: GlassColors.textSecondary).copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_pill == _HistoryPill.billPayment)
          GlassCard(child: Text('Chưa có giao dịch thanh toán hóa đơn qua QR.', style: GlassTypography.bodyMd()))
        else if (transfers.isEmpty)
          GlassCard(child: Text('Chưa có lần quét QR nào.', style: GlassTypography.bodyMd()))
        else
          for (final entry in grouped.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Text(entry.key.toUpperCase(), style: GlassTypography.labelCaps()),
                  ),
                  for (final t in entry.value)
                    Padding(
                      key: ValueKey('c3-transfer-${t.id}'),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        // Chỉ ý định ĐÃ khớp mới có giao dịch thật để dẫn tới — chưa khớp thì
                        // không có gì ở D1 để trỏ vào, không bịa đường dẫn (§16.9).
                        onTap: t.isMatched ? () => context.push('/transactions') : null,
                        child: GlassCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.receiverName ?? t.receiverAccountNumber,
                                      style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${t.receiverBankName} · ${DateFormat('HH:mm').format(t.scannedAt)}',
                                      style: GlassTypography.bodySm(),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('-${t.formattedAmount}', style: GlassTypography.labelNumeric(color: GlassColors.danger)),
                                  const SizedBox(height: 2),
                                  GlassBadge(text: _statusLabel(t.status), color: _statusColor(t.status)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}
