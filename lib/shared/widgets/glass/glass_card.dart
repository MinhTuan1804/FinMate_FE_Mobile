import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';

/// Thẻ kính mờ (frosted glass) dùng chung cho Auth/Onboarding.
/// [level] theo Depth Architecture của DESIGN.md: 1 = thẻ/feed thường, 2 = bề mặt hero
/// (thêm quầng ngũ sắc), 3 = modal/sheet nổi (mờ đậm hơn, viền sáng hơn).
class GlassCard extends StatelessWidget {
  final Widget child;
  final int level;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.level = 1,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? GlassRadius.roundedCard;
    final isModal = level == 3;
    final fill = isModal ? GlassColors.glassFillModal : GlassColors.glassFill;
    final border = isModal ? GlassColors.glassBorderModal : GlassColors.glassBorder;
    final shadow = switch (level) {
      3 => GlassColors.level3Shadow(),
      2 => GlassColors.level2Shadow(),
      _ => GlassColors.level1Shadow(),
    };

    return Container(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: [shadow]),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: isModal ? 14 : 10, sigmaY: isModal ? 14 : 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: radius,
              border: Border.all(color: border, width: 1),
              gradient: level == 2
                  ? RadialGradient(
                      colors: [
                        GlassColors.accentSkyBlue.withValues(alpha: 0.25),
                        GlassColors.accentDustyRose.withValues(alpha: 0.0),
                      ],
                      center: Alignment.topLeft,
                      radius: 1.2,
                    )
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
