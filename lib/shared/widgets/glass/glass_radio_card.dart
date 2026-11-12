import 'package:flutter/material.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';

/// Thẻ radio lớn, chọn được cả thẻ (B3 — khảo sát): viền sáng + icon check khi được chọn.
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? GlassColors.accentSkyBlue.withValues(alpha: 0.14) : GlassColors.glassFill,
          borderRadius: GlassRadius.roundedCard,
          border: Border.all(
            color: selected ? GlassColors.accentSkyBlue : GlassColors.glassBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: GlassTypography.bodySm()),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? GlassColors.ink : Colors.transparent,
                border: Border.all(color: selected ? GlassColors.ink : GlassColors.textMuted, width: 1.5),
              ),
              child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}
