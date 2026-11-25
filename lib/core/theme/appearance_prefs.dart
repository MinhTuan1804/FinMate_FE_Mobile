import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:finmate/core/theme/app_theme.dart';

/// Tuỳ chỉnh giao diện của người dùng (sáng/tối, cỡ chữ, giảm độ trong suốt) lưu trên máy, để mở lại app vẫn giữ.
/// Đây là lựa chọn của riêng người dùng: admin không đổi màu hay cỡ chữ, nên không có gì ghi đè lên nó.
class AppearancePrefs {
  AppearancePrefs({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  static const _themeModeKey = 'finmate_appearance_theme_mode';
  static const _textScaleKey = 'finmate_appearance_text_scale';
  static const _reduceTransparencyKey = 'finmate_appearance_reduce_transparency';

  /// Các nấc cỡ chữ trong Giao diện & Hiển thị (Nhỏ / Chuẩn / Lớn).
  static const textScaleStops = [0.9, 1.0, 1.15];

  /// Đọc tuỳ chỉnh đã lưu thành overrides cho ProviderScope. Không đọc được (máy chưa lưu gì, kho bảo mật lỗi)
  /// thì trả rỗng: app dùng mặc định thay vì không mở được.
  Future<List<Override>> loadOverrides() async {
    try {
      final values = await Future.wait([
        _storage.read(key: _themeModeKey),
        _storage.read(key: _textScaleKey),
        _storage.read(key: _reduceTransparencyKey),
      ]);
      final mode = ThemeMode.values.where((m) => m.name == values[0]).firstOrNull;
      final scale = double.tryParse(values[1] ?? '');
      final reduce = values[2];
      return [
        if (mode != null) themeModeProvider.overrideWith((ref) => mode),
        if (scale != null && textScaleStops.contains(scale)) textScaleProvider.overrideWith((ref) => scale),
        if (reduce == 'true' || reduce == 'false') reduceTransparencyProvider.overrideWith((ref) => reduce == 'true'),
      ];
    } on Object {
      return const [];
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) => _write(_themeModeKey, mode.name);
  Future<void> saveTextScale(double scale) => _write(_textScaleKey, '$scale');
  Future<void> saveReduceTransparency(bool value) => _write(_reduceTransparencyKey, '$value');

  /// Lưu lỗi thì chỉ mất lựa chọn ở lần mở sau, không làm hỏng màn hình đang dùng.
  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on Object {
      // bỏ qua: lần sau người dùng chọn lại
    }
  }
}

final appearancePrefsProvider = Provider<AppearancePrefs>((ref) => AppearancePrefs());

/// Ghi lại mỗi lần người dùng đổi tuỳ chỉnh giao diện. Gọi trong build của widget gốc (FinMateApp).
void persistAppearanceChanges(WidgetRef ref) {
  final prefs = ref.read(appearancePrefsProvider);
  ref.listen<ThemeMode>(themeModeProvider, (_, mode) => prefs.saveThemeMode(mode));
  ref.listen<double>(textScaleProvider, (_, scale) => prefs.saveTextScale(scale));
  ref.listen<bool>(reduceTransparencyProvider, (_, value) => prefs.saveReduceTransparency(value));
}
