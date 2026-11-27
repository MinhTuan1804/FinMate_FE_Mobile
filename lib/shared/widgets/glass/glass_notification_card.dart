import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';
import 'package:finmate/shared/widgets/glass/glass_card.dart';

/// Thẻ thông báo (B2): dải màu + icon theo loại, tiêu đề đậm, nội dung tối đa 2 dòng, dòng meta kèm "Xem", chấm chưa đọc cạnh tiêu đề.
class GlassNotificationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String metaText;
  final bool unread;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  /// Tầng kính của GlassCard: 1 cho thẻ trong danh sách, 3 (modal: đục hơn + blur nền) khi thẻ nổi trên nội dung khác.
  final int level;

  const GlassNotificationCard({
    this.level = 1,
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
        level: level,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dải màu theo loại: nhìn lướt là biết loại thông báo
                Container(width: 5, color: iconColor.withValues(alpha: unread ? 1 : 0.45)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 6, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                          child: Icon(icon, size: 20, color: iconColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GlassTypography.bodyLg(color: GlassColors.textPrimary).copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w600),
                                    ),
                                  ),
                                  if (unread)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(color: GlassColors.danger, shape: BoxShape.circle),
                                    ),
                                ],
                              ),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: GlassTypography.bodyMd()),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: Text(metaText, maxLines: 1, overflow: TextOverflow.ellipsis, style: GlassTypography.bodySm())),
                                  if (onTap != null) ...[
                                    Text('Xem', style: GlassTypography.bodySm(color: iconColor).copyWith(fontWeight: FontWeight.w600)),
                                    Icon(LucideIcons.chevronRight, size: 14, color: iconColor),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (onDismiss != null)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.close, size: 18, color: GlassColors.textMuted),
                            onPressed: onDismiss,
                          ),
                      ],
                    ),
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
