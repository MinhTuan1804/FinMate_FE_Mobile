import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:finmate/core/config/app_config.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';

/// Centralized Theme Configurations for Dark (OLED) and Light Mode
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    const fontFamily = AppTypography.fontFamily;
    final baseTextTheme = ThemeData.dark().textTheme.apply(fontFamily: fontFamily);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      fontFamily: fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.secondary,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimaryDark,
        error: AppColors.danger,
        onError: Colors.white,
      ),
      textTheme: baseTextTheme,
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.roundedLarge,
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimaryDark),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMutedDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDarkElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        hintStyle: const TextStyle(color: AppColors.textMutedDark, fontSize: 14),
      ),
    );
  }

  static ThemeData get lightTheme {
    const fontFamily = AppTypography.fontFamily;
    final baseTextTheme = ThemeData.light().textTheme.apply(fontFamily: fontFamily);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      fontFamily: fontFamily,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.secondary,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimaryLight,
        error: AppColors.danger,
        onError: Colors.white,
      ),
      textTheme: baseTextTheme,
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.roundedLarge,
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimaryLight),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMutedLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLightSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        hintStyle: const TextStyle(color: AppColors.textMutedLight, fontSize: 14),
      ),
    );
  }

  /// Áp cấu hình giao diện do admin đặt lên một theme có sẵn. Trường `null` giữ nguyên mặc định. Phạm vi: màu chủ đạo, nền, thanh điều hướng và font của THEME;
  /// widget nào dùng thẳng hằng `AppColors.*` (khoảng 100 chỗ trong app) vẫn giữ màu thương hiệu mặc định cho tới khi được chuyển sang đọc từ theme.
  static ThemeData applyConfig(ThemeData base, ThemeConfig config) {
    var theme = base;
    final primary = config.primaryColor;
    if (primary != null) {
      theme = theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(primary: primary, onPrimary: _onColor(primary)),
        bottomNavigationBarTheme: theme.bottomNavigationBarTheme.copyWith(selectedItemColor: primary),
      );
    }
    final background = config.backgroundColor;
    if (background != null) {
      theme = theme.copyWith(scaffoldBackgroundColor: background, appBarTheme: theme.appBarTheme.copyWith(backgroundColor: background));
    }
    final navBar = config.navBarColor;
    if (navBar != null) {
      theme = theme.copyWith(bottomNavigationBarTheme: theme.bottomNavigationBarTheme.copyWith(backgroundColor: navBar));
    }
    final font = config.fontFamily;
    if (font != null) {
      try {
        theme = theme.copyWith(textTheme: GoogleFonts.getTextTheme(font, theme.textTheme));
      } on Object {
        // tên không phải font Google hoặc không tải được: giữ font hiện tại thay vì làm hỏng cả theme
      }
    }
    return theme;
  }

  /// Chữ trên nền [color]: trắng trên nền tối, đen trên nền sáng, để màu admin chọn luôn đọc được.
  static Color _onColor(Color color) => ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;
}
