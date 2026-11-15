import 'package:flutter/material.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';

/// Nền khí quyển chung cho các màn Auth/Onboarding (và nhiều màn khác đã dùng theo — Trang chủ,
/// QR, Khảo sát...): gradient chéo mờ sương, không bao giờ render nền trắng phẳng (DESIGN.md,
/// mục Elevation & Depth).
///
/// Theo giao diện đang áp dụng (mặc định theo hệ thống, xem `themeModeProvider`): màu nền lấy từ
/// [GlassColors], được `GlassThemeSync` đồng bộ sáng/tối; widget không tự đặt màu (TextField, AppBar,
/// Divider, SnackBar, Dialog...) kế thừa Theme xung quanh nên cũng đổi sáng/tối cùng nền.
class GlassBackground extends StatelessWidget {
  final Widget child;

  /// Thêm quầng sáng ngũ sắc phía sau nội dung (dùng cho hero/welcome).
  final bool showAurora;

  const GlassBackground({super.key, required this.child, this.showAurora = false});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: GlassColors.canvasGradient),
      child: Stack(
        children: [
          if (showAurora) ...[
            Positioned(
              top: -60,
              right: -40,
              child: _blob(GlassColors.accentSkyBlue, 220),
            ),
            Positioned(
              top: 160,
              left: -60,
              child: _blob(GlassColors.accentDustyRose, 200),
            ),
            Positioned(
              bottom: -40,
              right: -20,
              child: _blob(GlassColors.accentWarmPeach, 180),
            ),
          ],
          child,
        ],
      ),
    );
  }

  Widget _blob(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
          ),
        ),
      );
}
