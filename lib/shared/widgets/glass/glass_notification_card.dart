import 'package:flutter/material.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// Thẻ thông báo (B2): icon theo loại, tiêu đề/nội dung, dòng meta, chấm chưa đọc.
class GlassNotificationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String metaText;
  final bool unread;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const GlassNotificationCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.metaText,
    this.unread = false,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                if (unread)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: GlassColors.danger, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(body, style: GlassTypography.bodyMd()),
                  const SizedBox(height: 8),
                  Text(metaText, style: GlassTypography.bodySm()),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: GlassColors.textMuted),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}
