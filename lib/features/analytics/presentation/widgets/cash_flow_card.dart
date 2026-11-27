import 'package:flutter/material.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/features/analytics/domain/report_models.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// "Số dư thay đổi" của kỳ (cashFlow.netCents, có thể âm). Bấm để xem vì sao nó khác thu − chi: vay nợ, quỹ nhóm, chuyển ví...
/// Mọi số lấy nguyên từ BE; app không tự cộng trừ.
class CashFlowCard extends StatefulWidget {
  final CashFlow cashFlow;
  final BigInt incomeCents;
  final BigInt spentCents;

  const CashFlowCard({super.key, required this.cashFlow, required this.incomeCents, required this.spentCents});

  @override
  State<CashFlowCard> createState() => _CashFlowCardState();
}

class _CashFlowCardState extends State<CashFlowCard> {
  bool _open = false;

  static String _signed(BigInt v) => v < BigInt.zero ? '-${formatVnd(-v)}' : '+${formatVnd(v)}';

  @override
  Widget build(BuildContext context) {
    final net = widget.cashFlow.netCents;
    final parts = widget.cashFlow.otherParts;
    Widget row(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(label, style: GlassTypography.bodySm())),
            Text(value, style: GlassTypography.bodySm(color: color)),
          ]),
        );

    return GlassCard(
      child: InkWell(
        key: const ValueKey('cash-flow-card'),
        onTap: () => setState(() => _open = !_open),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('Số dư thay đổi', style: GlassTypography.bodyMd())),
              Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18),
            ]),
            const SizedBox(height: 8),
            Text(
              _signed(net),
              style: GlassTypography.displayHero().copyWith(
                fontSize: 20,
                color: net < BigInt.zero ? GlassColors.danger : GlassColors.success,
              ),
            ),
            if (!_open && parts.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Gồm cả ${parts.map((p) => p.$1.toLowerCase()).join(', ')}. Bấm để xem.', style: GlassTypography.bodySm()),
            ],
            if (_open) ...[
              const SizedBox(height: 8),
              row('Thu nhập', '+${formatVnd(widget.incomeCents)}', color: GlassColors.success),
              row('Chi tiêu', '-${formatVnd(widget.spentCents)}', color: GlassColors.danger),
              for (final p in parts) row(p.$1, _signed(p.$2)),
              const Divider(),
              row('Số dư thay đổi', _signed(net)),
            ],
          ],
        ),
      ),
    );
  }
}
