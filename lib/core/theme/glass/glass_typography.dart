import 'package:flutter/material.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';

/// Kiểu chữ "Serene Liquid Glass" (design_reference/DESIGN.md, mục typography). Đi qua AppTypography.withFont nên
/// cùng font admin chọn và cùng thang cỡ với AppTypography; số liệu qua AppTypography.money (Inter).
class GlassTypography {
  GlassTypography._();

  static TextStyle displayHero({Color? color}) =>
      AppTypography.money(size: 32, weight: FontWeight.w700, height: 40 / 32, letterSpacing: -0.02 * 32, color: color ?? GlassColors.textPrimary);

  static TextStyle headlineLg({Color? color}) => AppTypography.withFont(
        TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          height: 34 / 26,
          letterSpacing: -0.015 * 26,
          color: color ?? GlassColors.textPrimary,
        ),
      );

  static TextStyle headlineMd({Color? color}) => AppTypography.withFont(
        TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 28 / 20,
          letterSpacing: -0.01 * 20,
          color: color ?? GlassColors.textPrimary,
        ),
      );

  static TextStyle headlineSm({Color? color}) => AppTypography.withFont(
        TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 24 / 18,
          color: color ?? GlassColors.textPrimary,
        ),
      );

  static TextStyle bodyLg({Color? color}) => AppTypography.withFont(
        TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 24 / 16,
          color: color ?? GlassColors.textPrimary,
        ),
      );

  static TextStyle bodyMd({Color? color}) => AppTypography.withFont(
        TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 20 / 14,
          color: color ?? GlassColors.textSecondary,
        ),
      );

  static TextStyle bodySm({Color? color}) => AppTypography.withFont(
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 16 / 12,
          color: color ?? GlassColors.textMuted,
        ),
      );

  static TextStyle labelNumeric({Color? color}) =>
      AppTypography.money(size: 15, weight: FontWeight.w600, height: 20 / 15, letterSpacing: -0.01 * 15, color: color ?? GlassColors.textPrimary);

  static TextStyle labelCaps({Color? color}) => AppTypography.withFont(
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 16 / 12,
          letterSpacing: 0.06 * 12,
          color: color ?? GlassColors.textMuted,
        ),
      );

  static TextStyle buttonText({Color? color}) => AppTypography.withFont(
        TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 20 / 15,
          color: color ?? GlassColors.onInk,
        ),
      );
}
