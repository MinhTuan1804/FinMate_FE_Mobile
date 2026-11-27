/// Độ phủ dữ liệu: FinMate đọc được thông báo ngân hàng trong bao nhiêu phần trăm số ngày gần đây (GET /me/data-coverage).
/// BE tính hết (cửa sổ, ngưỡng, "im lặng bất thường"); app chỉ hiển thị, không tự suy ra gì.
enum CoverageLevel { good, partial, poor, unknown }

/// Tình trạng của một ví đang theo dõi thông báo.
enum AccountCoverageStatus {
  ok,

  /// Im lặng quá mức cho phép so với nhịp thông báo bình thường của chính ví đó.
  silent,

  /// Ít thông báo trong cửa sổ (ví ít dùng): im lặng là bình thường, không nên báo động.
  notEnoughData,

  /// Listener vẫn thấy thông báo của app này nhưng server không nhận được: mở app để đồng bộ.
  uploadGap,
  unknown,
}

enum DeviceCoverageStatus { ok, permissionLost, unknown }

CoverageLevel _level(String? v) => switch (v) {
      'good' => CoverageLevel.good,
      'partial' => CoverageLevel.partial,
      'poor' => CoverageLevel.poor,
      _ => CoverageLevel.unknown,
    };

AccountCoverageStatus _accountStatus(String? v) => switch (v) {
      'ok' => AccountCoverageStatus.ok,
      'silent' => AccountCoverageStatus.silent,
      'not_enough_data' => AccountCoverageStatus.notEnoughData,
      'upload_gap' => AccountCoverageStatus.uploadGap,
      _ => AccountCoverageStatus.unknown,
    };

DeviceCoverageStatus _deviceStatus(String? v) => switch (v) {
      'ok' => DeviceCoverageStatus.ok,
      'permission_lost' => DeviceCoverageStatus.permissionLost,
      _ => DeviceCoverageStatus.unknown,
    };

class AccountCoverage {
  final String accountId;
  final String accountName;
  final AccountCoverageStatus status;
  final DateTime? lastNotificationAt;
  final int silentDays;

  /// Có thiết bị báo thông báo của app này đang bị tắt trên máy.
  final bool notificationsOff;

  const AccountCoverage({
    required this.accountId,
    required this.accountName,
    required this.status,
    required this.lastNotificationAt,
    required this.silentDays,
    required this.notificationsOff,
  });

  factory AccountCoverage.fromJson(Map<String, dynamic> json) => AccountCoverage(
        accountId: json['accountId'] as String? ?? '',
        accountName: json['accountName'] as String? ?? '',
        status: _accountStatus(json['status'] as String?),
        lastNotificationAt: DateTime.tryParse(json['lastNotificationAt'] as String? ?? ''),
        silentDays: (json['silentDays'] as num?)?.toInt() ?? 0,
        notificationsOff: json['notificationsOff'] == true,
      );
}

class DeviceCoverage {
  final String installationId;
  final DeviceCoverageStatus status;
  final bool permissionGranted;
  final bool listenerConnected;
  final DateTime? lastReportedAt;
  final String? manufacturer;

  const DeviceCoverage({
    required this.installationId,
    required this.status,
    required this.permissionGranted,
    required this.listenerConnected,
    required this.lastReportedAt,
    required this.manufacturer,
  });

  factory DeviceCoverage.fromJson(Map<String, dynamic> json) => DeviceCoverage(
        installationId: json['installationId'] as String? ?? '',
        status: _deviceStatus(json['status'] as String?),
        permissionGranted: json['permissionGranted'] == true,
        listenerConnected: json['listenerConnected'] == true,
        lastReportedAt: DateTime.tryParse(json['lastReportedAt'] as String? ?? ''),
        manufacturer: json['manufacturer'] as String?,
      );
}

class DataCoverage {
  final int windowDays;

  /// null khi chưa thiết bị nào báo trạng thái: không bịa số.
  final int? coveragePercent;
  final CoverageLevel level;
  final List<AccountCoverage> accounts;
  final List<DeviceCoverage> devices;

  const DataCoverage({
    required this.windowDays,
    required this.coveragePercent,
    required this.level,
    required this.accounts,
    required this.devices,
  });

  factory DataCoverage.fromJson(Map<String, dynamic> json) => DataCoverage(
        windowDays: (json['windowDays'] as num?)?.toInt() ?? 30,
        coveragePercent: (json['coveragePercent'] as num?)?.toInt(),
        level: _level(json['level'] as String?),
        accounts: [for (final a in (json['accounts'] as List? ?? const [])) AccountCoverage.fromJson(a as Map<String, dynamic>)],
        devices: [for (final d in (json['devices'] as List? ?? const [])) DeviceCoverage.fromJson(d as Map<String, dynamic>)],
      );

  /// Tình trạng của một ví theo id; null nếu ví không nằm trong danh sách theo dõi.
  AccountCoverage? forAccount(String accountId) {
    for (final a in accounts) {
      if (a.accountId == accountId) return a;
    }
    return null;
  }

  /// Có thiết bị nào đã mất quyền đọc thông báo không.
  /// Hãng máy của thiết bị đã báo gần nhất (để mở đúng phần hướng dẫn tắt tối ưu pin); null nếu chưa máy nào báo.
  String? get manufacturer => devices.map((d) => d.manufacturer).whereType<String>().firstOrNull;

  bool get hasPermissionLost => devices.any((d) => d.status == DeviceCoverageStatus.permissionLost);
}
