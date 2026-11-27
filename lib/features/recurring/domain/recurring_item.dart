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
  cancelled,

  /// Khoản trả góp đã trả đủ kỳ hoặc đã tất toán (BE Phase 92): không còn tính vào dự báo.
  completed;

  static RecurringStatus fromApi(String value) =>
      RecurringStatus.values.firstWhere((s) => s.name == value.toLowerCase(), orElse: () => RecurringStatus.active);

  String get label => switch (this) {
        RecurringStatus.suggested => 'Đề xuất - chờ xác nhận',
        RecurringStatus.active => 'Đang hoạt động',
        RecurringStatus.paused => 'Đã tạm dừng',
        RecurringStatus.rejected => 'Đã từ chối',
        RecurringStatus.cancelled => 'Đã hủy',
        RecurringStatus.completed => 'Đã trả xong',
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

  /// Trả góp (Phase 92): tổng số kỳ; null = định kỳ không có kỳ cuối.
  final int? totalOccurrences;
  final int paidOccurrences;
  final int? remainingOccurrences;

  /// Ước tính BE tính = số kỳ còn lại × số tiền mỗi kỳ.
  final BigInt? remainingAmountCents;
  final DateTime? finalDueDate;
  final bool settledEarly;

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
    this.totalOccurrences,
    this.paidOccurrences = 0,
    this.remainingOccurrences,
    this.remainingAmountCents,
    this.finalDueDate,
    this.settledEarly = false,
  });

  /// Có kỳ cuối (trả góp hoặc có ngày kết thúc): mới hiện tiến độ và nút tất toán.
  bool get hasFinal => totalOccurrences != null || finalDueDate != null;

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
        totalOccurrences: (json['totalOccurrences'] as num?)?.toInt(),
        paidOccurrences: (json['paidOccurrences'] as num?)?.toInt() ?? 0,
        remainingOccurrences: (json['remainingOccurrences'] as num?)?.toInt(),
        remainingAmountCents: json['remainingAmountCents'] == null ? null : parseCents(json['remainingAmountCents']),
        finalDueDate: DateTime.tryParse(json['finalDueDate'] as String? ?? ''),
        settledEarly: json['settledEarly'] == true,
      );

  String get formattedAmount => formatVnd(amountCents);
}
