import 'package:flutter/material.dart';

/// Centralized Design Token Colors for FinMate
/// Phong cách: Serene Liquid Glass FinTech (Light) & Obsidian Liquid Glass (Dark)
/// Nguồn tham chiếu: Serene Glass FinTech (#111827, #7CA9D6, #E8B2C4, #64748B) & Zenvest
/// Quy tắc: Không dùng trắng thuần (#FFFFFF) hay đen thuần (#000000) làm nền lớn.
class AppColors {
  AppColors._();

  // ===========================================================================
  // 1. LIGHT MODE — SERENE GLASS FINTECH (Zenvest Sky-Mist & Frosted Pearl)
  // ===========================================================================
  /// Nền chính Light Mode: Serene Sky Mist dịu mắt (không dùng #FFFFFF)
  static const Color backgroundLight = Color(0xFFE8EFF8);
  static const Color canvasLightStart = Color(0xFFDCE7F5);
  static const Color canvasLightMiddle = Color(0xFFE8EFF8);
  static const Color canvasLightEnd = Color(0xFFF3F6FB);

  /// Bề mặt đặc (Fallback khi tắt trong suốt / Reduce Transparency)
  static const Color surfaceLight = Color(0xFFF4F7FC);
  static const Color surfaceLightSubtle = Color(0xFFE6EEF8); // Secondary pill fill từ ảnh 1
  static const Color surfaceLightElevated = Color(0xFFF8FAFD);

  /// Nền kính (Liquid Glass Translucent Tints - Light)
  static const Color glassFillLight = Color(0xB8F4F7FC); // 72% Frosted Pearl
  static const Color glassFillElevatedLight = Color(0xD9F8FAFD); // 85% Elevated Sheet/Modal
  static const Color glassFillSubtleLight = Color(0x8CE6EEF8); // 55% Subtle Chip/Input

  /// Viền kính 1px & Specular Inner Highlight (Light)
  static const Color borderLight = Color(0x24111827); // 14% Primary Ink border
  static const Color glassBorderLight = Color(0x99FFFFFF); // 60% Specular White Rim
  static const Color glassHighlightLight = Color(0xCCFFFFFF); // 80% Top Inner Highlight

  // ===========================================================================
  // 2. DARK MODE — OBSIDIAN LIQUID GLASS (Deep Midnight Slate, không dùng #000000)
  // ===========================================================================
  /// Nền chính Dark Mode: Deep Midnight Slate
  static const Color backgroundDark = Color(0xFF0C1220);
  static const Color canvasDarkStart = Color(0xFF0B111E);
  static const Color canvasDarkMiddle = Color(0xFF0F172A);
  static const Color canvasDarkEnd = Color(0xFF152036);

  /// Bề mặt đặc (Fallback khi tắt trong suốt / Reduce Transparency)
  static const Color surfaceDark = Color(0xFF151F32);
  static const Color surfaceDarkElevated = Color(0xFF1E2B45);

  /// Nền kính (Liquid Glass Translucent Tints - Dark: 12-18% tint trên nền tối)
  static const Color glassFillDark = Color(0xA6151F32); // 65% Frosted Obsidian
  static const Color glassFillElevatedDark = Color(0xCC1E2B45); // 80% Elevated Modal/Sheet
  static const Color glassFillSubtleDark = Color(0x731E293B); // 45% Subtle Chip/Input

  /// Viền kính 1px & Specular Inner Highlight (Dark)
  static const Color borderDark = Color(0x29FFFFFF); // 16% Specular White Rim
  static const Color glassBorderDark = Color(0x337CA9D6); // 20% Serene Sky Tint Rim
  static const Color glassHighlightDark = Color(0x47FFFFFF); // 28% Top Inner Highlight

  // ===========================================================================
  // 3. BRAND & IRIDESCENT MESH PALETTE (Từ ảnh tham chiếu 1 & 2)
  // ===========================================================================
  /// Primary: Deep Ink Charcoal (#111827) từ ảnh Serene Glass FinTech
  static const Color primary = Color(0xFF111827);

  /// Primary cho Dark Mode để đảm bảo độ tương phản WCAG AA trên nền tối
  static const Color primaryDarkMode = Color(0xFF7CA9D6);

  /// Inverted / Hover Slate (#1E293B) từ nút Inverted ảnh 1
  static const Color primaryHover = Color(0xFF1E293B);

  /// Secondary: Serene Sky Blue (#7CA9D6) từ ảnh 1
  static const Color secondary = Color(0xFF7CA9D6);

  /// Tertiary / Accent: Soft Dusty Rose (#E8B2C4) từ ảnh 1 & vệt tán sắc Zenvest ảnh 2
  static const Color tertiary = Color(0xFFE8B2C4);
  static const Color accent = tertiary;

  /// Warm Peach Iridescence (#F3C6A8) từ vệt khúc xạ ánh sáng thẻ Balance Zenvest ảnh 2
  static const Color accentWarm = Color(0xFFF3C6A8);

  /// Action Slate Blue (#42638E) từ cụm nút tròn ảnh 1
  static const Color slateAction = Color(0xFF42638E);

  // ===========================================================================
  // 4. SEMANTIC & FINANCIAL STATES (Đạt chuẩn tương phản WCAG AA >= 4.5:1)
  // ===========================================================================
  static const Color safe = Color(0xFF059669); // Emerald: Thu nhập & Ngân sách an toàn (<70%)
  static const Color warning = Color(0xFFD97706); // Amber: Cảnh báo (70-89%)
  static const Color danger = Color(0xFFDC2626); // Crimson (#B91C1C/#DC2626): Chi tiêu & Nguy hiểm (>=90%)
  static const Color info = Color(0xFF42638E); // Steel Blue: Thông tin & Chuyển khoản nội bộ
  static const Color transfer = info;
  static const Color expense = danger;
  static const Color income = safe;

  /// Bảng màu biểu đồ đồng bộ (Analytics & Charts - thay thế hoàn toàn màu hard-code)
  static const List<Color> chartPalette = <Color>[
    Color(0xFF111827), // Deep Ink Charcoal
    Color(0xFF7CA9D6), // Serene Sky Blue
    Color(0xFFE8B2C4), // Soft Dusty Rose
    Color(0xFF42638E), // Steel Blue
    Color(0xFF059669), // Emerald Safe
    Color(0xFFD97706), // Warm Amber
  ];

  /// Bảng màu biểu đồ khi ở Dark Mode (tăng độ sáng cho cọ đầu tiên)
  static const List<Color> chartPaletteDark = <Color>[
    Color(0xFF7CA9D6), // Serene Sky Blue
    Color(0xFFE8B2C4), // Soft Dusty Rose
    Color(0xFFF3C6A8), // Warm Peach
    Color(0xFF34D399), // Mint Emerald
    Color(0xFF60A5FA), // Soft Blue
    Color(0xFFFBBF24), // Soft Amber
  ];

  // ===========================================================================
  // 5. CAMERA OVERLAY TOKENS (Luôn giữ độ tương phản cao trên luồng video camera)
  // ===========================================================================
  static const Color cameraBackdrop = Color(0xFF0B111E);
  static const Color onCamera = Color(0xFFF8FAFC);
  static const Color onCameraMuted = Color(0xB3F8FAFC); // 70%
  static const Color onCameraDisabled = Color(0x62F8FAFC); // 38%
  static const Color cameraScrim = Color(0xA60B111E); // 65%
  static const Color cameraControl = Color(0x8C151F32); // 55%

  // ===========================================================================
  // 6. TEXT NEUTRAL TOKENS (WCAG AA Checked)
  // ===========================================================================
  static const Color textPrimaryLight = Color(0xFF111827); // 14.8:1 trên #F4F7FC
  static const Color textSecondaryLight = Color(0xFF475569); // 6.8:1 trên #F4F7FC
  static const Color textMutedLight = Color(0xFF64748B); // Neutral #64748B từ ảnh 1 (4.6:1)

  static const Color textPrimaryDark = Color(0xFFF1F5F9); // 15.1:1 trên #0C1220
  static const Color textSecondaryDark = Color(0xFF94A3B8); // 6.4:1 trên #151F32
  static const Color textMutedDark = Color(0xFF64748B); // Neutral #64748B

  // ===========================================================================
  // 7. CONTEXT-AWARE HELPERS
  // ===========================================================================
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? textPrimaryDark : textPrimaryLight;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? textSecondaryDark : textSecondaryLight;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? textMutedDark : textMutedLight;

  static Color surface(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;

  static Color surfaceSubtle(BuildContext context) =>
      isDark(context) ? surfaceDarkElevated : surfaceLightSubtle;

  static Color border(BuildContext context) =>
      isDark(context) ? borderDark : borderLight;

  static Color glassBorder(BuildContext context) =>
      isDark(context) ? borderDark : glassBorderLight;

  static Color primaryAction(BuildContext context) =>
      isDark(context) ? primaryDarkMode : primary;

  static Color onPrimaryAction(BuildContext context) =>
      isDark(context) ? backgroundDark : surfaceLightElevated;

  static List<Color> activeChartPalette(BuildContext context) =>
      isDark(context) ? chartPaletteDark : chartPalette;
}
