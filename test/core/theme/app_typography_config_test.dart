import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/config/app_config.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/theme/glass/glass_typography.dart';

void main() {
  tearDown(() => AppTypography.configure(const ThemeConfig()));

  test('mặc định: Be Vietnam Pro cho chữ, Inter cho số, đúng cỡ thiết kế', () {
    final heading = GlassTypography.headlineLg();
    expect(heading.fontFamily, AppTypography.fontFamily);
    expect(heading.fontSize, 26);
    expect(GlassTypography.bodyMd().fontFamily, AppTypography.fontFamily);
    final money = AppTypography.moneyLarge;
    expect(money.fontFamily, AppTypography.moneyFontFamily);
    expect(money.fontVariations, [const FontVariation('wght', 700)]);
  });

  test('font admin chọn áp cho mọi chữ, số tiền vẫn là Inter để thẳng cột', () {
    AppTypography.configure(const ThemeConfig(fontFamily: 'Inter'));
    expect(GlassTypography.bodyMd().fontFamily, 'Inter');
    expect(GlassTypography.bodyMd().fontVariations, [const FontVariation('wght', 400)]);
    expect(AppTypography.moneyLarge.fontFamily, AppTypography.moneyFontFamily);
  });

  test('admin không chỉnh cỡ chữ: cỡ giữ đúng thang thiết kế', () {
    AppTypography.configure(const ThemeConfig(fontFamily: 'Be Vietnam Pro'));
    expect(GlassTypography.headlineSm().fontSize, 18);
    expect(GlassTypography.bodySm().fontSize, 12);
    expect(AppTypography.navLabel(selected: true, color: Colors.black).fontSize, 11);
  });
}
