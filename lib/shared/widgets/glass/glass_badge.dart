import 'package:flutter/material.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';

/// Nhãn pill nhỏ dùng cho %, trạng thái, số lượng — tránh lặp lại cùng kiểu Container+BorderRadius
/// ở nhiều màn (B2/B4/B5/B6).
class GlassBadge extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? background;

  const GlassBadge({super.key, required this.text, this.color, this.background});

  @override
  Widget build(BuildContext context) {
    final fg = color ?? GlassColors.slateAnchor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? fg.withValues(alpha: 0.12),
        borderRadius: GlassRadius.roundedPill,
      ),
      child: Text(text, style: GlassTypography.labelCaps(color: fg)),
    );
  }
}
