import 'package:flutter/material.dart';
import 'package:finmate/core/theme/app_colors.dart';

/// Centralized Typography System for FinMate
/// Sử dụng Plus Jakarta Sans chuẩn Fintech kết hợp Tabular Figures cho số tiền
class AppTypography {
  AppTypography._();

  /// Tên font mặc định cho ThemeData. Các kiểu chữ bên dưới KHÔNG ghi đè font: chúng thừa hưởng font của theme, nên font admin đặt (AppTheme.applyConfig) áp dụng cho mọi chữ.
  static const String fontFamily = 'PlusJakartaSans';
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

  static TextStyle tabular(TextStyle base) => base.copyWith(fontFeatures: tabularFigures);

  /// Nhãn dưới icon của thanh điều hướng dưới: nhỏ nhưng luôn kèm icon, đậm hơn khi đang chọn.
  static TextStyle navLabel({required bool selected, required Color color}) =>
      TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color);

  // Headings
  static TextStyle h1(BuildContext context) => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle h2(BuildContext context) => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle h3(BuildContext context) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      );

  // Body
  static TextStyle bodyLarge(BuildContext context) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle body(BuildContext context) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle bodyMedium(BuildContext context) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle caption(BuildContext context) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
      );

  // Money Typography (Tabular figures enabled - không nhảy giật hàng)
  static TextStyle get moneyLarge => const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        fontFeatures: tabularFigures,
      );

  static TextStyle get moneyMedium => const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFeatures: tabularFigures,
      );

  static TextStyle get moneySmall => const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        fontFeatures: tabularFigures,
      );
}
