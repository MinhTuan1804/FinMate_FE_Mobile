import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';

/// Kiểu chữ "Serene Liquid Glass" (design_reference/DESIGN.md, mục typography) — chỉ dùng cho
/// Auth/Onboarding. Be Vietnam Pro cho nội dung/tiêu đề, Inter cho số liệu/nhãn (tabular figures).
class GlassTypography {
  GlassTypography._();

  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle displayHero({Color color = GlassColors.textPrimary}) => GoogleFonts.inter(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 38 / 30,
        letterSpacing: -0.02 * 30,
        color: color,
        fontFeatures: _tabular,
      );

  static TextStyle headlineLg({Color color = GlassColors.textPrimary}) => GoogleFonts.beVietnamPro(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 34 / 26,
        letterSpacing: -0.015 * 26,
        color: color,
      );

  static TextStyle headlineMd({Color color = GlassColors.textPrimary}) => GoogleFonts.beVietnamPro(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        letterSpacing: -0.01 * 20,
        color: color,
      );

  static TextStyle headlineSm({Color color = GlassColors.textPrimary}) => GoogleFonts.beVietnamPro(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 24 / 17,
        color: color,
      );

  static TextStyle bodyLg({Color color = GlassColors.textPrimary}) => GoogleFonts.beVietnamPro(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: color,
      );

  static TextStyle bodyMd({Color color = GlassColors.textSecondary}) => GoogleFonts.beVietnamPro(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: color,
      );

  static TextStyle bodySm({Color color = GlassColors.textMuted}) => GoogleFonts.beVietnamPro(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: color,
      );

  static TextStyle labelNumeric({Color color = GlassColors.textPrimary}) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 20 / 15,
        letterSpacing: -0.01 * 15,
        color: color,
        fontFeatures: _tabular,
      );

  static TextStyle labelCaps({Color color = GlassColors.textMuted}) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 14 / 11,
        letterSpacing: 0.06 * 11,
        color: color,
      );

  static TextStyle buttonText({Color color = Colors.white}) => GoogleFonts.beVietnamPro(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 20 / 15,
        color: color,
      );
}
