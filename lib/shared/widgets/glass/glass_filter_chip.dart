import 'package:flutter/material.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';

/// Chip lọc có số lượng (B2: Tất cả/Biến động/Cảnh báo AI).
class GlassFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const GlassFilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? GlassColors.ink : GlassColors.glassFill,
          borderRadius: GlassRadius.roundedPill,
          border: Border.all(color: selected ? GlassColors.ink : GlassColors.glassBorder),
        ),
        child: Text(
          '$label ($count)',
          style: GlassTypography.bodyMd(color: selected ? Colors.white : GlassColors.textSecondary)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
