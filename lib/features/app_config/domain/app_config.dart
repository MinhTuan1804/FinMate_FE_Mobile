/// Cấu hình công khai của app: bảo trì, phiên bản tối thiểu, công tắc tính năng, giao diện.
/// GET /api/v1/app-config — AllowAnonymous (màn đăng nhập cũng cần hiện popup bảo trì), không cần token.
/// BE giấu `monitoring`/`marketData`/`community` chi tiết (trả giá trị mặc định/rỗng) nên FE không map các nhóm đó;
/// những nhóm còn lại (`limits`/`sync`/`qrTransfer`/`financeMethods`/`forecast`/`groups`/`support`) là tham số
/// nghiệp vụ nội bộ BE tự dùng, FE không cần hiển thị nên giữ nguyên dạng JSON thô trong [raw] để debug khi cần.
class AppConfigEntity {
  final int version;
  final DateTime serverTime;
  final MaintenanceInfoEntity maintenance;
  final AppVersionInfoEntity appVersion;
  final FeatureFlagsEntity features;
  final ThemeInfoEntity theme;

  /// Toàn bộ `config` thô từ BE (gồm cả các nhóm không map riêng ở trên), để màn test hiển thị/so sánh khi cần.
  final Map<String, dynamic> raw;

  const AppConfigEntity({
    required this.version,
    required this.serverTime,
    required this.maintenance,
    required this.appVersion,
    required this.features,
    required this.theme,
    required this.raw,
  });

  factory AppConfigEntity.fromJson(Map<String, dynamic> json) {
    final config = (json['config'] as Map<String, dynamic>?) ?? const {};
    return AppConfigEntity(
      version: json['version'] as int,
      serverTime: DateTime.parse(json['serverTime'] as String).toLocal(),
      maintenance: MaintenanceInfoEntity.fromJson((config['maintenance'] as Map<String, dynamic>?) ?? const {}),
      appVersion: AppVersionInfoEntity.fromJson((config['appVersion'] as Map<String, dynamic>?) ?? const {}),
      features: FeatureFlagsEntity.fromJson((config['features'] as Map<String, dynamic>?) ?? const {}),
      theme: ThemeInfoEntity.fromJson((config['theme'] as Map<String, dynamic>?) ?? const {}),
      raw: config,
    );
  }
}

/// Trạng thái bảo trì. `enabled` thì app nên chặn thao tác và hiện [message].
class MaintenanceInfoEntity {
  final bool enabled;
  final String title;
  final String message;
  final DateTime? estimatedEndAt;

  const MaintenanceInfoEntity({
    required this.enabled,
    required this.title,
    required this.message,
    this.estimatedEndAt,
  });

  factory MaintenanceInfoEntity.fromJson(Map<String, dynamic> json) => MaintenanceInfoEntity(
        enabled: json['enabled'] as bool? ?? false,
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        estimatedEndAt:
            json['estimatedEndAt'] == null ? null : DateTime.parse(json['estimatedEndAt'] as String).toLocal(),
      );
}

/// Yêu cầu cập nhật phiên bản app. `forceUpdate` thì app thấp hơn [latestVersion] (không chỉ dưới [minVersion]) bị buộc cập nhật.
class AppVersionInfoEntity {
  final String minVersion;
  final String latestVersion;
  final bool forceUpdate;
  final String storeUrl;

  const AppVersionInfoEntity({
    required this.minVersion,
    required this.latestVersion,
    required this.forceUpdate,
    required this.storeUrl,
  });

  factory AppVersionInfoEntity.fromJson(Map<String, dynamic> json) => AppVersionInfoEntity(
        minVersion: json['minVersion'] as String? ?? '1.0.0',
        latestVersion: json['latestVersion'] as String? ?? '1.0.0',
        forceUpdate: json['forceUpdate'] as bool? ?? false,
        storeUrl: json['storeUrl'] as String? ?? '',
      );
}

/// Công tắc bật/tắt từng tính năng ở tầng hệ thống (khác với quyền/role của user).
class FeatureFlagsEntity {
  final bool chatAi;
  final bool voice;
  final bool billScan;
  final bool notificationReading;
  final bool groups;
  final bool support;
  final bool marketAlerts;
  final bool community;
  final bool subscriptions;

  const FeatureFlagsEntity({
    required this.chatAi,
    required this.voice,
    required this.billScan,
    required this.notificationReading,
    required this.groups,
    required this.support,
    required this.marketAlerts,
    required this.community,
    required this.subscriptions,
  });

  factory FeatureFlagsEntity.fromJson(Map<String, dynamic> json) => FeatureFlagsEntity(
        chatAi: json['chatAi'] as bool? ?? true,
        voice: json['voice'] as bool? ?? true,
        billScan: json['billScan'] as bool? ?? true,
        notificationReading: json['notificationReading'] as bool? ?? true,
        groups: json['groups'] as bool? ?? false,
        support: json['support'] as bool? ?? false,
        marketAlerts: json['marketAlerts'] as bool? ?? false,
        community: json['community'] as bool? ?? false,
        subscriptions: json['subscriptions'] as bool? ?? false,
      );
}

/// Giao diện app. `null` = dùng mặc định có sẵn trong app (không đổi gì trên máy người dùng).
class ThemeInfoEntity {
  final String? primaryColor;
  final String? backgroundColor;
  final String? navBarColor;
  final String? fontFamily;
  final double textScale;
  final String? logoUrl;

  const ThemeInfoEntity({
    this.primaryColor,
    this.backgroundColor,
    this.navBarColor,
    this.fontFamily,
    this.textScale = 1.0,
    this.logoUrl,
  });

  factory ThemeInfoEntity.fromJson(Map<String, dynamic> json) => ThemeInfoEntity(
        primaryColor: json['primaryColor'] as String?,
        backgroundColor: json['backgroundColor'] as String?,
        navBarColor: json['navBarColor'] as String?,
        fontFamily: json['fontFamily'] as String?,
        textScale: (json['textScale'] as num?)?.toDouble() ?? 1.0,
        logoUrl: json['logoUrl'] as String?,
      );
}
