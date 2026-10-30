import 'package:flutter/painting.dart';

/// Cấu hình hệ thống do admin đặt, app tải từ `GET /api/v1/app-config`. Mọi trường đọc "khoan dung": thiếu hoặc sai kiểu thì dùng mặc định,
/// để một cấu hình hỏng ở server không bao giờ làm app không mở được.
class MaintenanceConfig {
  const MaintenanceConfig({
    this.enabled = false,
    this.title = 'FinMate đang bảo trì',
    this.message = 'Chúng tôi đang nâng cấp hệ thống để phục vụ bạn tốt hơn. Vui lòng quay lại sau ít phút.',
    this.estimatedEndAt,
  });

  final bool enabled;
  final String title;
  final String message;
  final DateTime? estimatedEndAt;

  factory MaintenanceConfig.fromJson(Map<String, dynamic> json) {
    const fallback = MaintenanceConfig();
    return MaintenanceConfig(
      enabled: json['enabled'] == true,
      title: _text(json['title']) ?? fallback.title,
      message: _text(json['message']) ?? fallback.message,
      estimatedEndAt: json['estimatedEndAt'] is String ? DateTime.tryParse(json['estimatedEndAt'] as String) : null,
    );
  }
}

class AppVersionConfig {
  const AppVersionConfig({this.minVersion = '1.0.0', this.latestVersion = '1.0.0', this.forceUpdate = false, this.storeUrl = ''});

  final String minVersion;
  final String latestVersion;

  /// Bật thì app cũ hơn [latestVersion] cũng bị chặn, không chỉ app dưới [minVersion].
  final bool forceUpdate;
  final String storeUrl;

  factory AppVersionConfig.fromJson(Map<String, dynamic> json) {
    const fallback = AppVersionConfig();
    return AppVersionConfig(
      minVersion: _text(json['minVersion']) ?? fallback.minVersion,
      latestVersion: _text(json['latestVersion']) ?? fallback.latestVersion,
      forceUpdate: json['forceUpdate'] == true,
      storeUrl: _text(json['storeUrl']) ?? '',
    );
  }
}

class FeatureConfig {
  const FeatureConfig({this.chatAi = true, this.voice = true, this.billScan = true, this.notificationReading = true});

  final bool chatAi;
  final bool voice;
  final bool billScan;
  final bool notificationReading;

  /// Tính năng chỉ tắt khi server nói rõ `false`: thiếu trường nghĩa là còn bật.
  factory FeatureConfig.fromJson(Map<String, dynamic> json) => FeatureConfig(
        chatAi: json['chatAi'] != false,
        voice: json['voice'] != false,
        billScan: json['billScan'] != false,
        notificationReading: json['notificationReading'] != false,
      );
}

/// Giao diện: `null` nghĩa là "giữ mặc định có sẵn trong app".
class ThemeConfig {
  const ThemeConfig({this.primaryColor, this.backgroundColor, this.navBarColor, this.fontFamily, this.textScale = 1.0, this.logoUrl});

  static const double minTextScale = 0.8;
  static const double maxTextScale = 1.5;

  final Color? primaryColor;
  final Color? backgroundColor;
  final Color? navBarColor;
  final String? fontFamily;
  final double textScale;
  final String? logoUrl;

  factory ThemeConfig.fromJson(Map<String, dynamic> json) {
    final scale = json['textScale'];
    final logo = _text(json['logoUrl']);
    return ThemeConfig(
      primaryColor: _color(json['primaryColor']),
      backgroundColor: _color(json['backgroundColor']),
      navBarColor: _color(json['navBarColor']),
      fontFamily: _text(json['fontFamily']),
      textScale: scale is num ? scale.toDouble().clamp(minTextScale, maxTextScale) : 1.0,
      logoUrl: logo != null && logo.startsWith('https://') ? logo : null,  // chỉ nhận https: không tải ảnh qua kết nối không mã hóa
    );
  }
}

class AppConfig {
  const AppConfig({
    this.version = 0,
    this.maintenance = const MaintenanceConfig(),
    this.appVersion = const AppVersionConfig(),
    this.features = const FeatureConfig(),
    this.theme = const ThemeConfig(),
  });

  /// Cấu hình khi chưa tải được gì (mới cài, mất mạng): không bảo trì, không buộc cập nhật, giao diện mặc định.
  static const AppConfig defaults = AppConfig();

  /// Số phiên bản của cấu hình trên server; tăng sau mỗi lần admin lưu nên đủ để biết có bản mới hay không.
  final int version;
  final MaintenanceConfig maintenance;
  final AppVersionConfig appVersion;
  final FeatureConfig features;
  final ThemeConfig theme;

  /// [data] là phần `data` của phản hồi: `{version, serverTime, config: {...}}`.
  factory AppConfig.fromJson(Map<String, dynamic> data) {
    final config = data['config'] is Map<String, dynamic> ? data['config'] as Map<String, dynamic> : const <String, dynamic>{};
    Map<String, dynamic> section(String key) => config[key] is Map<String, dynamic> ? config[key] as Map<String, dynamic> : const {};
    return AppConfig(
      version: data['version'] is int ? data['version'] as int : 0,
      maintenance: MaintenanceConfig.fromJson(section('maintenance')),
      appVersion: AppVersionConfig.fromJson(section('appVersion')),
      features: FeatureConfig.fromJson(section('features')),
      theme: ThemeConfig.fromJson(section('theme')),
    );
  }
}

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

final RegExp _hex = RegExp(r'^#[0-9A-Fa-f]{6}$');

Color? _color(Object? value) {
  if (value is! String || !_hex.hasMatch(value)) return null;
  return Color(0xFF000000 | int.parse(value.substring(1), radix: 16));
}
