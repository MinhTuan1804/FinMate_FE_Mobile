import 'package:flutter/material.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/core/theme/glass/glass_radius.dart';

/// Trạng thái màu của [GlassProgressBar], ứng với mức độ dùng ngân sách/hũ.
enum GlassProgressState { normal, success, warning, danger }

/// Thanh tiến độ mỏng, màu theo trạng thái — dùng cho phân bổ hũ (B4/B5), bước khảo sát (B3).
class GlassProgressBar extends StatelessWidget {
  final double percent;
  final GlassProgressState state;
  final double height;

  const GlassProgressBar({
    super.key,
    required this.percent,
    this.state = GlassProgressState.normal,
    this.height = 6,
  });

  Color get _color => switch (state) {
        GlassProgressState.success => GlassColors.success,
        GlassProgressState.warning => GlassColors.warning,
        GlassProgressState.danger => GlassColors.danger,
        GlassProgressState.normal => GlassColors.accentSkyBlue,
      };

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Container(
              height: height,
              width: constraints.maxWidth,
              color: GlassColors.secondarySurface,
            ),
            Container(
              height: height,
              width: constraints.maxWidth * (percent.clamp(0, 100) / 100),
              decoration: BoxDecoration(color: _color, borderRadius: GlassRadius.roundedPill),
            ),
          ],
        ),
      ),
    );
  }
}
