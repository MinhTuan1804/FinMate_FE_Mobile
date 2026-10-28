import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_theme.dart';
import 'package:finmate/core/theme/app_typography.dart';

void main() {
  group('Design Tokens - AppColors Test', () {
    test('Xác thực bảng màu chuẩn Neo-Fintech chống AI Slop', () {
      // Dark OLED palette
      expect(AppColors.backgroundDark, const Color(0xFF0B0F19));
      expect(AppColors.surfaceDark, const Color(0xFF131C2E));
      expect(AppColors.surfaceDarkElevated, const Color(0xFF1E293B));

      // Light Clean Paper palette
      expect(AppColors.backgroundLight, const Color(0xFFF8FAFC));
      expect(AppColors.surfaceLight, const Color(0xFFFFFFFF));

      // Semantic brand & financial colors
      expect(AppColors.primary, const Color(0xFF2563EB));
      expect(AppColors.safe, const Color(0xFF10B981)); // Income & Safe Budget (<70%)
      expect(AppColors.warning, const Color(0xFFF59E0B)); // Warning Budget (70-89%)
      expect(AppColors.danger, const Color(0xFFEF4444)); // Expense & Danger Budget (>=90%)
    });
  });

  group('Design Tokens - AppSpacing Test', () {
    test('Xác thực hệ thống spacing chuẩn', () {
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 12.0);
      expect(AppSpacing.lg, 16.0);
      expect(AppSpacing.xl, 24.0);
      expect(AppSpacing.xxl, 32.0);
    });
  });

  group('Design Tokens - AppTypography & AppTheme Test', () {
    test('Đảm bảo DarkTheme có nền OLED và độ tương phản cao', () {
      final darkTheme = AppTheme.darkTheme;
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.scaffoldBackgroundColor, AppColors.backgroundDark);
      expect(darkTheme.colorScheme.primary, AppColors.primary);
      expect(darkTheme.colorScheme.surface, AppColors.surfaceDark);
    });

    test('Đảm bảo LightTheme chuẩn Clean Paper', () {
      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.scaffoldBackgroundColor, AppColors.backgroundLight);
      expect(lightTheme.colorScheme.surface, AppColors.surfaceLight);
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
