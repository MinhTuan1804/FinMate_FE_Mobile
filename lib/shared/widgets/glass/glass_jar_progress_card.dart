import 'package:flutter/material.dart';
import 'package:finmate/core/format/money.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/shared/widgets/glass/glass_badge.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';
import 'package:finmate/shared/widgets/glass/glass_progress_bar.dart';

String jarLevelLabel(String level) => switch (level) {
      'none' => 'Chưa có số',
      'ok' => 'Ổn',
      't1' => 'Nhắc nhẹ',
      't2' => 'Cảnh báo mạnh',
      'over' => 'Vượt hạn mức',
      _ => level,
    };

GlassProgressState jarLevelState(String level) => switch (level) {
      'over' => GlassProgressState.danger,
      't2' => GlassProgressState.danger,
      't1' => GlassProgressState.warning,
      'ok' => GlassProgressState.success,
      _ => GlassProgressState.normal,
    };

/// Thẻ một hũ (B5): icon + tên + % phân bổ + số tiền đã chi/được phân bổ + thanh tiến độ +
/// nhãn trạng thái. [compact] dùng cho biến thể bento nhỏ (lưới 3 cột) thay vì tạo widget riêng.
class GlassJarProgressCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final int allocationPct;
  final BigInt? allocatedCents;
  final BigInt spentCents;
  final String level;
  final bool compact;
  final VoidCallback? onTap;

  const GlassJarProgressCard({
    super.key,
    required this.label,
    required this.icon,
    required this.allocationPct,
    required this.allocatedCents,
    required this.spentCents,
    required this.level,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final percent = allocatedCents == null || allocatedCents == BigInt.zero
        ? 0.0
        : (spentCents.toDouble() / allocatedCents!.toDouble() * 100);
    final state = jarLevelState(level);

    final header = Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: GlassColors.accentSkyBlue.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: GlassColors.slateAnchor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
        ),
        GlassBadge(text: '$allocationPct%'),
      ],
    );

    final amounts = Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(formatVnd(spentCents), style: GlassTypography.labelNumeric()),
          Text(
            allocatedCents == null ? 'Chưa biết' : '/ ${formatVnd(allocatedCents!)}',
            style: GlassTypography.bodySm(),
          ),
        ],
      ),
    );

    final footer = Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(jarLevelLabel(level), style: GlassTypography.bodySm(color: _statusColor(state))),
    );

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: EdgeInsets.all(compact ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            amounts,
            GlassProgressBar(percent: percent, state: state),
            footer,
          ],
        ),
      ),
    );
  }

  Color _statusColor(GlassProgressState state) => switch (state) {
        GlassProgressState.danger => GlassColors.danger,
        GlassProgressState.warning => GlassColors.warning,
        GlassProgressState.success => GlassColors.success,
        GlassProgressState.normal => GlassColors.textMuted,
      };
}
