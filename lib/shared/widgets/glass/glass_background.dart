import 'package:flutter/material.dart';
import 'package:finmate/core/theme/app_theme.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';

/// Nền khí quyển chung cho các màn Auth/Onboarding (và nhiều màn khác đã dùng theo — Trang chủ,
/// QR, Khảo sát...): gradient chéo mờ sương, không bao giờ render nền trắng phẳng (DESIGN.md,
/// mục Elevation & Depth).
///
/// Luôn SÁNG, bất kể app đang chạy `ThemeMode.dark` toàn cục (`main.dart`) — chữ/widget nào
/// không tự đặt màu (TextField mặc định, AppBar, Divider, SnackBar, Dialog...) sẽ kế thừa màu
/// của Theme xung quanh; trước đây không có Theme riêng ở đây nên chúng kế thừa theme TỐI toàn
/// cục (chữ trắng) trong khi nền ở đây luôn sáng — chữ trắng trên nền sáng gần như vô hình. Bọc
/// lại bằng `AppTheme.lightTheme` để mọi widget không tự đặt màu cũng ra đúng màu sáng.
class GlassBackground extends StatelessWidget {
  final Widget child;

  /// Thêm quầng sáng ngũ sắc phía sau nội dung (dùng cho hero/welcome).
  final bool showAurora;

  const GlassBackground({super.key, required this.child, this.showAurora = false});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: GlassColors.canvasGradient),
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
