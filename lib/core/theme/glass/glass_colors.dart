import 'package:flutter/material.dart';

/// Màu "Serene Liquid Glass" — chỉ dùng cho các màn Auth/Onboarding (design_reference/DESIGN.md,
/// mục Colors). KHÔNG dùng cho phần còn lại của app (xem [AppColors] cho theme chính).
class GlassColors {
  GlassColors._();

  // Nền khí quyển: gradient chéo, không bao giờ render nền trắng phẳng
  static const Color canvasStart = Color(0xFFDCE7F5);
  static const Color canvasMid = Color(0xFFE8EFF8);
  static const Color canvasEnd = Color(0xFFF3F6FB);

  static const canvasGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [canvasStart, canvasMid, canvasEnd],
  );

  // Mực nền chính (chữ, nút)
  static const Color ink = Color(0xFF111827);

  // Mặt kính (Level 1 - thẻ/feed)
  static const Color glassFill = Color(0xB8F4F7FC); // rgba(244,247,252,0.72)
  static const Color glassBorder = Color(0xA6FFFFFF); // rgba(255,255,255,0.65)
  static const Color glassInnerHighlight = Color(0xCCFFFFFF); // rgba(255,255,255,0.8)

  // Mặt kính Level 3 (modal/sheet nổi)
  static const Color glassFillModal = Color(0xE0F4F7FC); // rgba(244,247,252,0.88)
  static const Color glassBorderModal = Color(0xD9FFFFFF); // rgba(255,255,255,0.85)

  // Bề mặt phụ / nền hành động
  static const Color secondarySurface = Color(0xFFE6EEF8);

  // Điểm nhấn ngũ sắc (hero balance, nền động)
  static const Color accentSkyBlue = Color(0xFF7CA9D6);
  static const Color accentDustyRose = Color(0xFFE8B2C4);
  static const Color accentWarmPeach = Color(0xFFF3C6A8);

  // Neo slate (icon chuyên biệt, segmented control)
  static const Color slateAnchor = Color(0xFF42638E);

  // Trạng thái tài chính
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);

  // Lớp chữ
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);

  // Bóng đổ dịu (ambient, không dùng dropshadow đục)
  static const Color ambientShadow = Color(0xFF42638E);

  static BoxShadow level1Shadow() => BoxShadow(
        color: ambientShadow.withValues(alpha: 0.08),
        blurRadius: 32,
        offset: const Offset(0, 12),
        spreadRadius: -8,
      );

  static BoxShadow level2Shadow() => BoxShadow(
        color: ambientShadow.withValues(alpha: 0.12),
        blurRadius: 40,
        offset: const Offset(0, 18),
        spreadRadius: -10,
      );

  static BoxShadow level3Shadow() => BoxShadow(
        color: ink.withValues(alpha: 0.14),
        blurRadius: 48,
        offset: const Offset(0, 24),
        spreadRadius: -12,
      );
}
