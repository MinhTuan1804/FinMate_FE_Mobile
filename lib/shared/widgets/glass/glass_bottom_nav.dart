import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';

/// Thanh điều hướng dưới cùng theo đúng thiết kế Stitch (B1 DESIGN.md): 5 mục, mục giữa
/// "Quét QR" nổi lên thành nút tròn riêng (không phải tab chọn được như 4 mục còn lại — bấm là
/// điều hướng thẳng sang /qr-transfers, không có trạng thái active).
class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({super.key, required this.currentIndex, required this.onDestinationSelected});

  /// Index trong 4 tab thường (không tính nút Quét QR giữa): 0=Trang chủ, 1=Giao dịch,
  /// 2=Kế hoạch, 3=Phân tích.
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _tabs = [
    (icon: LucideIcons.house, label: 'Trang chủ'),
    (icon: LucideIcons.receipt, label: 'Giao dịch'),
    (icon: LucideIcons.target, label: 'Kế hoạch'),
    (icon: LucideIcons.chartPie, label: 'Phân tích'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: GlassColors.glassFillModal,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: GlassColors.glassBorderModal),
            boxShadow: [GlassColors.level2Shadow()],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _tab(context, 0),
              _tab(context, 1),
              _scanButton(context),
              _tab(context, 2),
              _tab(context, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int index) {
    final tab = _tabs[index];
    final selected = index == currentIndex;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onDestinationSelected(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? GlassColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, size: 20, color: selected ? Colors.white : GlassColors.textMuted),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: GlassTypography.labelCaps(color: selected ? Colors.white : GlassColors.textMuted).copyWith(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanButton(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onDestinationSelected(-1),
      child: Transform.translate(
        offset: const Offset(0, -14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: GlassColors.ink,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 4),
                boxShadow: [GlassColors.level2Shadow()],
              ),
              child: const Icon(LucideIcons.scanLine, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 2),
            Text('Quét QR', style: GlassTypography.labelCaps(color: GlassColors.textPrimary).copyWith(fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
