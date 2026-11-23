import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:finmate/core/config/app_config.dart';
import 'package:finmate/core/theme/app_colors.dart';

/// Hệ chữ chung của FinMate (GlassTypography dùng chung lõi này).
/// - Font chữ: admin chọn (Cấu hình hệ thống › Giao diện), mặc định Be Vietnam Pro (dựng riêng cho dấu tiếng Việt).
/// - Số tiền: luôn Inter để các con số thẳng cột, không phụ thuộc font admin chọn.
/// - Cỡ chữ: theo thang thiết kế 11 (chỉ nhãn nav/badge) · 12 · 13 · 14 · 15 · 16 · 18 · 20 · 26 · 32; người dùng phóng
///   to/thu nhỏ trong Giao diện & Hiển thị (nhân với cỡ chữ hệ điều hành, xem main.dart), admin không chỉnh cỡ chữ.
/// Be Vietnam Pro và Inter đóng gói trong assets/fonts, không tải qua mạng.
class AppTypography {
  AppTypography._();

  /// Font chữ đóng gói sẵn (tên family trong pubspec.yaml), cũng là font mặc định của ThemeData.
  static const String fontFamily = 'BeVietnamPro';

  /// Font số đóng gói sẵn. Inter là font variable: phải đặt cả trục 'wght' thì độ đậm mới đổi.
  static const String moneyFontFamily = 'Inter';
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

  /// Tên admin nhập (theo Google Fonts) → font đóng gói sẵn: dùng bản trong app, không tải qua mạng.
  static const bundledFonts = {'be vietnam pro': fontFamily, 'bevietnampro': fontFamily, 'inter': moneyFontFamily};

  static String? _adminFont;

  /// FinMateApp gọi mỗi lần dựng lại theo cấu hình admin. Các hàm style là static (GlassTypography không có
  /// BuildContext) nên đọc font từ đây, giống cách GlassColors đọc chế độ sáng/tối.
  static void configure(ThemeConfig config) => _adminFont = config.fontFamily;

  /// Gắn font chữ hiện hành vào [base]. Font admin chọn không phải font đóng gói thì tải qua Google Fonts; tên sai
  /// hoặc không tải được thì về Be Vietnam Pro, không làm hỏng chữ.
  static TextStyle withFont(TextStyle base) {
    final name = _adminFont;
    if (name == null) return base.copyWith(fontFamily: fontFamily);
    final bundled = bundledFonts[name.toLowerCase()];
    if (bundled != null) return bundled == moneyFontFamily ? _inter(base) : base.copyWith(fontFamily: bundled);
    try {
      return GoogleFonts.getFont(name, textStyle: base);
    } on Object {
      return base.copyWith(fontFamily: fontFamily);
    }
  }

  static TextStyle _inter(TextStyle base) => base.copyWith(
        fontFamily: moneyFontFamily,
        fontVariations: [FontVariation('wght', (base.fontWeight ?? FontWeight.w400).value.toDouble())],
      );

  /// Kiểu chữ số tiền: Inter, số đều cột, đúng độ đậm (fontWeight + trục wght của font variable).
  static TextStyle money({required double size, required FontWeight weight, double? letterSpacing, double? height, Color? color}) =>
      _inter(TextStyle(
        fontSize: size,
        fontWeight: weight,
        fontFeatures: tabularFigures,
        letterSpacing: letterSpacing,
        height: height,
        color: color,
      ));

  static TextStyle tabular(TextStyle base) =>
      base.copyWith(fontFeatures: tabularFigures);

  /// Nhãn dưới icon của thanh điều hướng dưới: nhỏ nhưng luôn kèm icon, đậm hơn khi đang chọn.
  static TextStyle navLabel({required bool selected, required Color color}) => withFont(TextStyle(
        fontSize: 11,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        letterSpacing: -0.1,
        color: color,
      ));

  // Headings
  static TextStyle h1(BuildContext context) => withFont(TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.22,
        color: Theme.of(context).colorScheme.onSurface,
      ));

  static TextStyle h2(BuildContext context) => withFont(TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.25,
        color: Theme.of(context).colorScheme.onSurface,
      ));

  static TextStyle h3(BuildContext context) => withFont(TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        color: Theme.of(context).colorScheme.onSurface,
      ));

  static TextStyle sectionLabel(BuildContext context) => withFont(TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.textSecondary(context),
      ));

  // Body
  static TextStyle bodyLarge(BuildContext context) => withFont(TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: Theme.of(context).colorScheme.onSurface,
      ));

  static TextStyle body(BuildContext context) => withFont(TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: Theme.of(context).colorScheme.onSurface,
      ));

  static TextStyle bodyMedium(BuildContext context) => withFont(TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: Theme.of(context).colorScheme.onSurface,
      ));

  static TextStyle caption(BuildContext context) => withFont(TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: AppColors.textSecondary(context),
      ));

  // Money Typography (Tabular figures enabled - không nhảy giật hàng)
  static TextStyle displayBalance(BuildContext context) =>
      money(size: 32, weight: FontWeight.w700, letterSpacing: -0.8, color: Theme.of(context).colorScheme.onSurface);

  static TextStyle get moneyLarge => money(size: 32, weight: FontWeight.w700, letterSpacing: -0.6);

  static TextStyle get moneyMedium => money(size: 20, weight: FontWeight.w700, letterSpacing: -0.3);

  static TextStyle get moneySmall => money(size: 15, weight: FontWeight.w600);
}
