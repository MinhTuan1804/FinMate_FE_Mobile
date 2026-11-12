import 'package:flutter/material.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';

/// Vòng tiến độ dạng donut (SVG-style) — dùng cho "Chi an toàn hôm nay" (B1, nhỏ) và
/// tổng quan ngân sách hũ (B6, lớn hơn với [center] chi tiết hơn).
class GlassCircularProgress extends StatelessWidget {
  final double percent;
  final double size;
  final Color? trackColor;
  final Color? progressColor;
  final Widget? center;
  final double strokeWidth;

  const GlassCircularProgress({
    super.key,
    required this.percent,
    this.size = 64,
    this.trackColor,
    this.progressColor,
    this.center,
    this.strokeWidth = 8,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(
          percent: percent.clamp(0, 100) / 100,
          trackColor: trackColor ?? GlassColors.secondarySurface,
          progressColor: progressColor ?? GlassColors.accentSkyBlue,
          strokeWidth: strokeWidth,
        ),
        child: center == null ? null : Center(child: center),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double percent;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _DonutPainter({
    required this.percent,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // -90°, bắt đầu từ đỉnh
      6.2832 * percent, // 2π * percent
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.percent != percent || oldDelegate.progressColor != progressColor || oldDelegate.trackColor != trackColor;
}
