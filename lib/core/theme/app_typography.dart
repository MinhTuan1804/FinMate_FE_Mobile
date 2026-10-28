import 'package:flutter/material.dart';
import 'package:finmate/core/theme/app_colors.dart';

/// Centralized Typography System for FinMate
/// Sử dụng Plus Jakarta Sans chuẩn Fintech kết hợp Tabular Figures cho số tiền
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'PlusJakartaSans';
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

  static TextStyle tabular(TextStyle base) => base.copyWith(fontFeatures: tabularFigures);

  // Headings
  static TextStyle h1(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle h2(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle h3(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      );

  // Body
  static TextStyle bodyLarge(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle body(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle bodyMedium(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle caption(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
      );

  // Money Typography (Tabular figures enabled - không nhảy giật hàng)
  static TextStyle get moneyLarge => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        fontFeatures: tabularFigures,
      );

  static TextStyle get moneyMedium => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFeatures: tabularFigures,
      );

  static TextStyle get moneySmall => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        fontFeatures: tabularFigures,
      );
}
