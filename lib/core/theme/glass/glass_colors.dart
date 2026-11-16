import 'package:flutter/material.dart';

/// Màu "Serene Liquid Glass" cho Trang chủ, Auth/Onboarding và nhóm màn Kế hoạch/Thông báo (design_reference/DESIGN.md, mục Colors).
///
/// Bộ màu có hai bản sáng/tối. [dark] được `GlassThemeSync` (xem `glass_theme_sync.dart`) cập nhật theo chế độ giao diện hiện tại
/// và ép dựng lại cây widget khi đổi, nên các màn dùng màu này tự đổi theo mà không cần truyền `context` vào từng chỗ.
class GlassColors {
  GlassColors._();

  /// true khi đang ở giao diện tối. Chỉ `GlassThemeSync` được ghi.
  static bool dark = false;

  // Nền khí quyển: gradient chéo, không bao giờ render nền trắng phẳng
  static Color get canvasStart => dark ? const Color(0xFF0B111E) : const Color(0xFFDCE7F5);
  static Color get canvasMid => dark ? const Color(0xFF0F172A) : const Color(0xFFE8EFF8);
  static Color get canvasEnd => dark ? const Color(0xFF152036) : const Color(0xFFF3F6FB);

  static LinearGradient get canvasGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [canvasStart, canvasMid, canvasEnd],
      );

  /// Màu nhấn chính dùng làm nền nút/chip đang chọn (xanh slate ở sáng, xanh nhạt ở tối). Chữ/icon trên nền này dùng [onInk].
  static Color get ink => dark ? const Color(0xFF7CA9D6) : const Color(0xFF42638E);

  /// Màu chữ/icon đặt trên nền [ink].
  static Color get onInk => dark ? const Color(0xFF0C1220) : Colors.white;

  /// Mục ĐANG CHỌN (tab, chip lọc): nền xanh trời dịu + chữ/icon [activeFg]. Nút hành động chính vẫn dùng [ink].
  static Color get activeFill => accentSkyBlue.withValues(alpha: dark ? 0.25 : 0.28);
  static Color get activeBorder => accentSkyBlue.withValues(alpha: 0.5);
  static Color get activeFg => slateAnchor;

  // Mặt kính (Level 1 - thẻ/feed)
  static Color get glassFill => dark ? const Color(0xA6151F32) : const Color(0xB8F4F7FC);
  static Color get glassBorder => dark ? const Color(0x29FFFFFF) : const Color(0xA6FFFFFF);
  static Color get glassInnerHighlight => dark ? const Color(0x47FFFFFF) : const Color(0xCCFFFFFF);

  // Mặt kính Level 3 (modal/sheet nổi)
  static Color get glassFillModal => dark ? const Color(0xE01E2B45) : const Color(0xE0F4F7FC);
  static Color get glassBorderModal => dark ? const Color(0x40FFFFFF) : const Color(0xD9FFFFFF);

  // Bề mặt phụ / nền hành động
  static Color get secondarySurface => dark ? const Color(0xFF1E293B) : const Color(0xFFE6EEF8);

  /// Nền ô nhập liệu / vòng OTP và viền của chúng.
  static Color get fieldFill => dark ? Colors.white.withValues(alpha: 0.07) : Colors.white.withValues(alpha: 0.45);
  static Color get fieldBorder => dark ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.75);

  // Điểm nhấn ngũ sắc (hero balance, nền động)
  static const Color accentSkyBlue = Color(0xFF7CA9D6);
  static const Color accentDustyRose = Color(0xFFE8B2C4);
  static const Color accentWarmPeach = Color(0xFFF3C6A8);

  // Neo slate (icon chuyên biệt, segmented control)
  static Color get slateAnchor => dark ? const Color(0xFF7CA9D6) : const Color(0xFF42638E);

  // Trạng thái tài chính (bản tối sáng hơn để đủ tương phản trên nền tối)
  static Color get success => dark ? const Color(0xFF34D399) : const Color(0xFF059669);
  static Color get warning => dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  static Color get danger => dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);

  // Lớp chữ
  static Color get textPrimary => dark ? const Color(0xFFE6EDF7) : const Color(0xFF111827);
  static Color get textSecondary => dark ? const Color(0xFFB4C0D4) : const Color(0xFF475569);
  static Color get textMuted => dark ? const Color(0xFF8A99B1) : const Color(0xFF64748B);

  // Bóng đổ dịu (ambient, không dùng dropshadow đục)
  static Color get ambientShadow => dark ? Colors.black : const Color(0xFF42638E);

  static BoxShadow level1Shadow() => BoxShadow(
        color: ambientShadow.withValues(alpha: dark ? 0.3 : 0.08),
        blurRadius: 32,
        offset: const Offset(0, 12),
        spreadRadius: -8,
      );

  static BoxShadow level2Shadow() => BoxShadow(
        color: ambientShadow.withValues(alpha: dark ? 0.4 : 0.12),
        blurRadius: 40,
        offset: const Offset(0, 18),
        spreadRadius: -10,
      );

  static BoxShadow level3Shadow() => BoxShadow(
        color: (dark ? Colors.black : const Color(0xFF111827)).withValues(alpha: dark ? 0.5 : 0.14),
        blurRadius: 48,
        offset: const Offset(0, 24),
        spreadRadius: -12,
      );
}
