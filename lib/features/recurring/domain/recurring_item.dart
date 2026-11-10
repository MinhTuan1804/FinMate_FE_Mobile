import 'package:finmate/core/format/money.dart';

/// Chiều tiền của khoản định kỳ: lương (vào) hay hóa đơn/thuê bao (ra)
enum RecurringDirection {
  inflow('Inflow', 'Thu nhập'),
  outflow('Outflow', 'Chi tiêu');

  final String apiValue;
  final String label;
  const RecurringDirection(this.apiValue, this.label);

  static RecurringDirection fromApi(String value) =>
      RecurringDirection.values.firstWhere((d) => d.apiValue.toLowerCase() == value.toLowerCase(), orElse: () => RecurringDirection.outflow);
}

enum RecurringCadence {
  weekly('Weekly', 'Hàng tuần'),
  monthly('Monthly', 'Hàng tháng'),
  yearly('Yearly', 'Hàng năm');

  final String apiValue;
  final String label;
  const RecurringCadence(this.apiValue, this.label);

  static RecurringCadence fromApi(String value) =>
      RecurringCadence.values.firstWhere((c) => c.apiValue.toLowerCase() == value.toLowerCase(), orElse: () => RecurringCadence.monthly);
}

/// Vòng đời: chỉ active được tính vào dự báo. suggested = hệ thống tự phát hiện, chờ người dùng xác nhận/từ chối.
enum RecurringStatus {
  suggested,
  active,
  paused,
  rejected,
  cancelled;

  static RecurringStatus fromApi(String value) =>
      RecurringStatus.values.firstWhere((s) => s.name == value.toLowerCase(), orElse: () => RecurringStatus.active);

  String get label => switch (this) {
        RecurringStatus.suggested => 'Đề xuất - chờ xác nhận',
        RecurringStatus.active => 'Đang hoạt động',
        RecurringStatus.paused => 'Đã tạm dừng',
        RecurringStatus.rejected => 'Đã từ chối',
        RecurringStatus.cancelled => 'Đã hủy',
      };
}

/// Khoản thu/chi định kỳ (GET /recurring-items): lương, tiền nhà, thuê bao...
class RecurringItemEntity {
  final String id;
  final RecurringDirection direction;
  final String name;
  final String? counterpartyKey;
  final String? categoryId;
  final String? financialAccountId;
  final BigInt amountCents;
  final RecurringCadence cadence;
  final DateTime nextDueDate;
  final RecurringStatus status;
  final String source;
  final int occurrences;

  const RecurringItemEntity({
    required this.id,
    required this.direction,
    required this.name,
    this.counterpartyKey,
    this.categoryId,
    this.financialAccountId,
    required this.amountCents,
    required this.cadence,
    required this.nextDueDate,
    required this.status,
    this.source = 'manual',
    this.occurrences = 0,
  });

  factory RecurringItemEntity.fromJson(Map<String, dynamic> json) => RecurringItemEntity(
        id: json['id'] as String,
        direction: RecurringDirection.fromApi(json['direction'] as String? ?? 'outflow'),
        name: json['name'] as String? ?? '',
        counterpartyKey: json['counterpartyKey'] as String?,
        categoryId: json['categoryId'] as String?,
        financialAccountId: json['financialAccountId'] as String?,
        amountCents: parseCents(json['amountCents']),
        cadence: RecurringCadence.fromApi(json['cadence'] as String? ?? 'monthly'),
        nextDueDate: DateTime.parse(json['nextDueDate'] as String),
        status: RecurringStatus.fromApi(json['status'] as String? ?? 'active'),
        source: (json['source'] as String? ?? 'manual').toLowerCase(),
        occurrences: json['occurrences'] as int? ?? 0,
      );

  String get formattedAmount => formatVnd(amountCents);
}
