import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/theme/app_theme.dart';
import 'package:finmate/core/theme/appearance_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('chưa lưu gì: dùng mặc định', () async {
    final container = ProviderContainer(overrides: await AppearancePrefs().loadOverrides());
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(container.read(textScaleProvider), 1.0);
    expect(container.read(reduceTransparencyProvider), isFalse);
  });

  test('lưu rồi mở lại app: giữ đúng sáng/tối, cỡ chữ, giảm trong suốt', () async {
    final prefs = AppearancePrefs();
    await prefs.saveThemeMode(ThemeMode.dark);
    await prefs.saveTextScale(1.15);
    await prefs.saveReduceTransparency(true);

    final container = ProviderContainer(overrides: await AppearancePrefs().loadOverrides());
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(container.read(textScaleProvider), 1.15);
    expect(container.read(reduceTransparencyProvider), isTrue);
  });

  test('giá trị lạ trong kho (không phải nấc Nhỏ/Chuẩn/Lớn) thì bỏ qua', () async {
    FlutterSecureStorage.setMockInitialValues({
      'finmate_appearance_theme_mode': 'tím',
      'finmate_appearance_text_scale': '3.0',
      'finmate_appearance_reduce_transparency': 'có',
    });
    final container = ProviderContainer(overrides: await AppearancePrefs().loadOverrides());
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(container.read(textScaleProvider), 1.0);
    expect(container.read(reduceTransparencyProvider), isFalse);
  });
}
