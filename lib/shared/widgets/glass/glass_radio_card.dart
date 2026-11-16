import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';

/// Thẻ radio lớn, chọn được cả thẻ (B3 — khảo sát): nút tròn bên trái, viền xanh + vòng sáng khi được chọn.
class GlassRadioCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const GlassRadioCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = selected
        ? GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontSize: 15, height: 18.75 / 15, fontWeight: FontWeight.w600)
        : GlassTypography.bodyMd(color: GlassColors.textPrimary).copyWith(height: 19.25 / 14);

    return Semantics(
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: GlassRadius.roundedCard,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: selected
                  ? (GlassColors.dark ? GlassColors.glassFillModal : Colors.white.withValues(alpha: 0.88))
                  : GlassColors.glassFill,
              borderRadius: GlassRadius.roundedCard,
              border: Border.all(
                color: selected ? GlassColors.accentSkyBlue : GlassColors.glassBorder,
              ),
              boxShadow: [
                if (selected) BoxShadow(color: GlassColors.accentSkyBlue.withValues(alpha: 0.22), spreadRadius: 3),
                GlassColors.level1Shadow(),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? GlassColors.ink : Colors.transparent,
                      border: Border.all(
                        color: selected ? GlassColors.ink : GlassColors.textMuted.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                    child: selected ? Icon(LucideIcons.check, size: 14, color: GlassColors.onInk) : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: titleStyle),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(subtitle!, style: GlassTypography.bodySm()),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
