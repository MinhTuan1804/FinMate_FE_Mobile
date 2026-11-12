import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_theme.dart';
import 'package:finmate/core/theme/app_typography.dart';

void main() {
  group('Design Tokens - AppColors Test', () {
    test('Xác thực bảng màu chuẩn Serene Liquid Glass FinTech (không dùng #FFF hay #000 làm nền)', () {
      // Dark Obsidian Glass palette
      expect(AppColors.backgroundDark, const Color(0xFF0C1220));
      expect(AppColors.surfaceDark, const Color(0xFF151F32));
      expect(AppColors.surfaceDarkElevated, const Color(0xFF1E2B45));
      expect(AppColors.backgroundDark, isNot(const Color(0xFF000000)));

      // Light Serene Glass palette
      expect(AppColors.backgroundLight, const Color(0xFFE8EFF8));
      expect(AppColors.surfaceLight, const Color(0xFFF4F7FC));
      expect(AppColors.backgroundLight, isNot(const Color(0xFFFFFFFF)));
      expect(AppColors.surfaceLight, isNot(const Color(0xFFFFFFFF)));

      // Semantic brand & financial colors từ ảnh tham chiếu 1 & 2
      expect(AppColors.primary, const Color(0xFF111827));
      expect(AppColors.secondary, const Color(0xFF7CA9D6));
      expect(AppColors.tertiary, const Color(0xFFE8B2C4));
      expect(AppColors.safe, const Color(0xFF059669)); // Income & Safe Budget (<70%)
      expect(AppColors.warning, const Color(0xFFD97706)); // Warning Budget (70-89%)
      expect(AppColors.danger, const Color(0xFFDC2626)); // Expense & Danger Budget (>=90%)
    });
  });

  group('Design Tokens - AppSpacing Test', () {
    test('Xác thực hệ thống spacing 8pt và Liquid Glass radius/blur', () {
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 12.0);
      expect(AppSpacing.lg, 16.0);
      expect(AppSpacing.xl, 24.0);
      expect(AppSpacing.xxl, 32.0);
      expect(AppSpacing.radiusMedium, 16.0);
      expect(AppSpacing.radiusLarge, 20.0);
      expect(AppSpacing.radiusXl, 28.0);
      expect(AppSpacing.blurCard, 24.0);
    });
  });

  group('Design Tokens - AppTypography & AppTheme Test', () {
    test('Đảm bảo DarkTheme có nền Obsidian Glass và LiquidGlassTheme extension', () {
      final darkTheme = AppTheme.darkTheme;
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.scaffoldBackgroundColor, AppColors.backgroundDark);
      expect(darkTheme.colorScheme.primary, AppColors.secondary);
      expect(darkTheme.colorScheme.surface, AppColors.surfaceDark);
      expect(darkTheme.extension<LiquidGlassTheme>()?.isDark, isTrue);
    });

    test('Đảm bảo LightTheme chuẩn Serene Glass FinTech và LiquidGlassTheme extension', () {
      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.scaffoldBackgroundColor, AppColors.backgroundLight);
      expect(lightTheme.colorScheme.primary, AppColors.primary);
      expect(lightTheme.colorScheme.surface, AppColors.surfaceLight);
      expect(lightTheme.extension<LiquidGlassTheme>()?.isDark, isFalse);
    });

    test('Đảm bảo font số tiền có tính năng Tabular Figures', () {
      final moneyStyle = AppTypography.moneyLarge;
      expect(moneyStyle.fontFeatures, isNotNull);
      expect(
        moneyStyle.fontFeatures!.any((f) => f.feature == 'tnum'),
        isTrue,
        reason: 'Font số tiền bắt buộc phải bật tabular figures để không nhảy layout khi thay đổi số',
      );
    });
  });
}
