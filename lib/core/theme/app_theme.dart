import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:finmate/core/config/app_config.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';

/// Chế độ giao diện toàn cục: mặc định Light (Serene Glass FinTech / Zenvest), hỗ trợ chuyển Dark / System.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

/// Tùy chọn trợ năng "Giảm độ trong suốt" (Reduce Transparency fallback sang bề mặt đặc cùng tông).
final reduceTransparencyProvider = StateProvider<bool>((ref) => false);

/// ThemeExtension chứa toàn bộ thông số Liquid Glass cho Light (Serene Glass) và Dark (Obsidian Glass)
@immutable
class LiquidGlassTheme extends ThemeExtension<LiquidGlassTheme> {
  const LiquidGlassTheme({
    required this.isDark,
    required this.reduceTransparency,
    required this.glassFill,
    required this.glassElevatedFill,
    required this.glassSubtleFill,
    required this.solidFallbackFill,
    required this.solidElevatedFallbackFill,
    required this.glassBorder,
    required this.glassHighlight,
    required this.canvasGradient,
    required this.heroIridescentGradient,
    required this.cardShadows,
    required this.floatingShadows,
  });

  final bool isDark;
  final bool reduceTransparency;
  final Color glassFill;
  final Color glassElevatedFill;
  final Color glassSubtleFill;
  final Color solidFallbackFill;
  final Color solidElevatedFallbackFill;
  final Color glassBorder;
  final Color glassHighlight;
  final LinearGradient canvasGradient;
  final LinearGradient heroIridescentGradient;
  final List<BoxShadow> cardShadows;
  final List<BoxShadow> floatingShadows;

  static const LiquidGlassTheme light = LiquidGlassTheme(
    isDark: false,
    reduceTransparency: false,
    glassFill: AppColors.glassFillLight,
    glassElevatedFill: AppColors.glassFillElevatedLight,
    glassSubtleFill: AppColors.glassFillSubtleLight,
    solidFallbackFill: AppColors.surfaceLight,
    solidElevatedFallbackFill: AppColors.surfaceLightElevated,
    glassBorder: AppColors.glassBorderLight,
    glassHighlight: AppColors.glassHighlightLight,
    canvasGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        AppColors.canvasLightStart,
        AppColors.canvasLightMiddle,
        AppColors.canvasLightEnd,
      ],
      stops: <double>[0.0, 0.52, 1.0],
    ),
    heroIridescentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xE6F8FAFD),
        Color(0xCCE6EEF8),
        Color(0x59E8B2C4), // Soft Dusty Rose (#E8B2C4)
        Color(0x4DF3C6A8), // Warm Peach (#F3C6A8)
      ],
      stops: <double>[0.0, 0.45, 0.78, 1.0],
    ),
    cardShadows: <BoxShadow>[
      BoxShadow(
        color: Color(0x0D111827), // 5% soft ink ambient
        blurRadius: 24,
        offset: Offset(0, 10),
      ),
      BoxShadow(
        color: Color(0x147CA9D6), // 8% serene sky tint glow
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
    floatingShadows: <BoxShadow>[
      BoxShadow(
        color: Color(0x1A111827), // 10% elevated ambient
        blurRadius: 32,
        offset: Offset(0, 14),
      ),
      BoxShadow(
        color: Color(0x1F7CA9D6), // 12% sky refraction
        blurRadius: 14,
        offset: Offset(0, 4),
      ),
    ],
  );

  static const LiquidGlassTheme dark = LiquidGlassTheme(
    isDark: true,
    reduceTransparency: false,
    glassFill: AppColors.glassFillDark,
    glassElevatedFill: AppColors.glassFillElevatedDark,
    glassSubtleFill: AppColors.glassFillSubtleDark,
    solidFallbackFill: AppColors.surfaceDark,
    solidElevatedFallbackFill: AppColors.surfaceDarkElevated,
    glassBorder: AppColors.borderDark,
    glassHighlight: AppColors.glassHighlightDark,
    canvasGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        AppColors.canvasDarkStart,
        AppColors.canvasDarkMiddle,
        AppColors.canvasDarkEnd,
      ],
      stops: <double>[0.0, 0.55, 1.0],
    ),
    heroIridescentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xD918243A),
        Color(0xB31E2D4A),
        Color(0x387CA9D6), // Serene Sky Blue refraction
        Color(0x2EE8B2C4), // Soft Dusty Rose refraction
      ],
      stops: <double>[0.0, 0.48, 0.78, 1.0],
    ),
    cardShadows: <BoxShadow>[
      BoxShadow(
        color: Color(0x40060913),
        blurRadius: 24,
        offset: Offset(0, 10),
      ),
      BoxShadow(
        color: Color(0x147CA9D6),
        blurRadius: 12,
        offset: Offset(0, 3),
      ),
    ],
    floatingShadows: <BoxShadow>[
      BoxShadow(
        color: Color(0x59060913),
        blurRadius: 34,
        offset: Offset(0, 14),
      ),
      BoxShadow(
        color: Color(0x1F7CA9D6),
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
    ],
  );

  static LiquidGlassTheme of(BuildContext context) {
    return Theme.of(context).extension<LiquidGlassTheme>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  @override
  LiquidGlassTheme copyWith({
    bool? isDark,
    bool? reduceTransparency,
    Color? glassFill,
    Color? glassElevatedFill,
    Color? glassSubtleFill,
    Color? solidFallbackFill,
    Color? solidElevatedFallbackFill,
    Color? glassBorder,
    Color? glassHighlight,
    LinearGradient? canvasGradient,
    LinearGradient? heroIridescentGradient,
    List<BoxShadow>? cardShadows,
    List<BoxShadow>? floatingShadows,
  }) {
    return LiquidGlassTheme(
      isDark: isDark ?? this.isDark,
      reduceTransparency: reduceTransparency ?? this.reduceTransparency,
      glassFill: glassFill ?? this.glassFill,
      glassElevatedFill: glassElevatedFill ?? this.glassElevatedFill,
      glassSubtleFill: glassSubtleFill ?? this.glassSubtleFill,
      solidFallbackFill: solidFallbackFill ?? this.solidFallbackFill,
      solidElevatedFallbackFill:
          solidElevatedFallbackFill ?? this.solidElevatedFallbackFill,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      canvasGradient: canvasGradient ?? this.canvasGradient,
      heroIridescentGradient:
          heroIridescentGradient ?? this.heroIridescentGradient,
      cardShadows: cardShadows ?? this.cardShadows,
      floatingShadows: floatingShadows ?? this.floatingShadows,
    );
  }

  @override
  LiquidGlassTheme lerp(ThemeExtension<LiquidGlassTheme>? other, double t) {
    if (other is! LiquidGlassTheme) return this;
    return LiquidGlassTheme(
      isDark: t < 0.5 ? isDark : other.isDark,
      reduceTransparency:
          t < 0.5 ? reduceTransparency : other.reduceTransparency,
      glassFill: Color.lerp(glassFill, other.glassFill, t) ?? glassFill,
      glassElevatedFill:
          Color.lerp(glassElevatedFill, other.glassElevatedFill, t) ??
              glassElevatedFill,
      glassSubtleFill:
          Color.lerp(glassSubtleFill, other.glassSubtleFill, t) ??
              glassSubtleFill,
      solidFallbackFill:
          Color.lerp(solidFallbackFill, other.solidFallbackFill, t) ??
              solidFallbackFill,
      solidElevatedFallbackFill: Color.lerp(
            solidElevatedFallbackFill,
            other.solidElevatedFallbackFill,
            t,
          ) ??
          solidElevatedFallbackFill,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
      glassHighlight:
          Color.lerp(glassHighlight, other.glassHighlight, t) ?? glassHighlight,
      canvasGradient:
          LinearGradient.lerp(canvasGradient, other.canvasGradient, t) ??
              canvasGradient,
      heroIridescentGradient: LinearGradient.lerp(
            heroIridescentGradient,
            other.heroIridescentGradient,
            t,
          ) ??
          heroIridescentGradient,
      cardShadows:
          BoxShadow.lerpList(cardShadows, other.cardShadows, t) ?? cardShadows,
      floatingShadows:
          BoxShadow.lerpList(floatingShadows, other.floatingShadows, t) ??
              floatingShadows,
    );
  }
}

/// Centralized Theme Configurations for Liquid Glass Light & Dark Mode
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    const fontFamily = AppTypography.fontFamily;
    final baseTextTheme =
        ThemeData.light().textTheme.apply(fontFamily: fontFamily);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      fontFamily: fontFamily,
      extensions: const <ThemeExtension<dynamic>>[LiquidGlassTheme.light],
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary, // #111827 Deep Ink Charcoal
        onPrimary: AppColors.surfaceLightElevated,
        secondary: AppColors.secondary, // #7CA9D6 Serene Sky Blue
        onSecondary: AppColors.primary,
        tertiary: AppColors.tertiary, // #E8B2C4 Soft Dusty Rose
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimaryLight,
        surfaceContainerHighest: AppColors.surfaceLightSubtle,
        onSurfaceVariant: AppColors.textSecondaryLight,
        outline: AppColors.borderLight,
        error: AppColors.danger,
        onError: AppColors.surfaceLightElevated,
      ),
      textTheme: baseTextTheme,
      cardTheme: CardThemeData(
        color: AppColors.glassFillLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.roundedLarge,
          side: const BorderSide(color: AppColors.glassBorderLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimaryLight),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: AppColors.textPrimaryLight,
        ),
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
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLightSubtle,
        selectedColor: AppColors.primary,
        disabledColor: AppColors.surfaceLightSubtle.withValues(alpha: 0.5),
        secondarySelectedColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.glassBorderLight, width: 1),
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryLight,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.surfaceLightElevated,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surfaceLightElevated,
          disabledBackgroundColor: AppColors.textMutedLight.withValues(alpha: 0.25),
          disabledForegroundColor: AppColors.textMutedLight,
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surfaceLightElevated,
          disabledBackgroundColor: AppColors.textMutedLight.withValues(alpha: 0.25),
          disabledForegroundColor: AppColors.textMutedLight,
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryLight,
          backgroundColor: AppColors.glassFillSubtleLight,
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(44, 44),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLightElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.roundedXl,
          side: const BorderSide(color: AppColors.glassBorderLight, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLightElevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surfaceLightElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.roundedTopSheet,
          side: BorderSide(color: AppColors.glassBorderLight, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.surfaceLightElevated,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.roundedMedium),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLightSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.glassBorderLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textMutedLight, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 14),
      ),
    );
  }

  static ThemeData get darkTheme {
    const fontFamily = AppTypography.fontFamily;
    final baseTextTheme =
        ThemeData.dark().textTheme.apply(fontFamily: fontFamily);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      fontFamily: fontFamily,
      extensions: const <ThemeExtension<dynamic>>[LiquidGlassTheme.dark],
      colorScheme: const ColorScheme.dark(
        primary: AppColors.secondary, // #7CA9D6 Serene Sky Blue nổi bật trên nền tối
        onPrimary: AppColors.primary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.primary,
        tertiary: AppColors.tertiary,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimaryDark,
        surfaceContainerHighest: AppColors.surfaceDarkElevated,
        onSurfaceVariant: AppColors.textSecondaryDark,
        outline: AppColors.borderDark,
        error: AppColors.danger,
        onError: AppColors.textPrimaryDark,
      ),
      textTheme: baseTextTheme,
      cardTheme: CardThemeData(
        color: AppColors.glassFillDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.roundedLarge,
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimaryDark),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: AppColors.textPrimaryDark,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.secondary,
        unselectedItemColor: AppColors.textMutedDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceDarkElevated,
        selectedColor: AppColors.secondary,
        disabledColor: AppColors.surfaceDarkElevated.withValues(alpha: 0.4),
        secondarySelectedColor: AppColors.secondary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.borderDark, width: 1),
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryDark,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.textMutedDark.withValues(alpha: 0.25),
          disabledForegroundColor: AppColors.textMutedDark,
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.textMutedDark.withValues(alpha: 0.25),
          disabledForegroundColor: AppColors.textMutedDark,
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryDark,
          backgroundColor: AppColors.glassFillSubtleDark,
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: AppColors.borderDark, width: 1),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondary,
          minimumSize: const Size(44, 44),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDarkElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.roundedXl,
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDarkElevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surfaceDarkElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.roundedTopSheet,
          side: BorderSide(color: AppColors.borderDark, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceDarkElevated,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textPrimaryDark,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.roundedMedium),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDarkElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.roundedMedium,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textMutedDark, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
      ),
    );
  }

  /// Áp cấu hình giao diện do admin đặt lên một theme có sẵn và tùy chọn Reduce Transparency.
  static ThemeData applyConfig(
    ThemeData base,
    ThemeConfig config, {
    bool reduceTransparency = false,
  }) {
    var theme = base;
    final glassExt = theme.extension<LiquidGlassTheme>();
    if (glassExt != null && glassExt.reduceTransparency != reduceTransparency) {
      theme = theme.copyWith(
        extensions: <ThemeExtension<dynamic>>[
          glassExt.copyWith(reduceTransparency: reduceTransparency),
        ],
      );
    }
    final primary = config.primaryColor;
    if (primary != null) {
      theme = theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: primary,
          onPrimary: _onColor(primary),
        ),
        bottomNavigationBarTheme: theme.bottomNavigationBarTheme.copyWith(
          selectedItemColor: primary,
        ),
      );
    }
    final background = config.backgroundColor;
    if (background != null) {
      theme = theme.copyWith(
        scaffoldBackgroundColor: background,
        appBarTheme: theme.appBarTheme.copyWith(backgroundColor: background),
      );
    }
    final navBar = config.navBarColor;
    if (navBar != null) {
      theme = theme.copyWith(
        bottomNavigationBarTheme: theme.bottomNavigationBarTheme.copyWith(
          backgroundColor: navBar,
        ),
      );
    }
    final font = config.fontFamily;
    if (font != null) {
      try {
        theme = theme.copyWith(
          textTheme: GoogleFonts.getTextTheme(font, theme.textTheme),
        );
      } on Object {
        // tên không phải font Google hoặc không tải được: giữ font hiện tại thay vì làm hỏng cả theme
      }
    }
    return theme;
  }

  /// Chữ trên nền [color]: trắng trên nền tối, đen trên nền sáng, để màu admin chọn luôn đọc được.
  static Color _onColor(Color color) =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark
          ? Colors.white
          : Colors.black;
}
