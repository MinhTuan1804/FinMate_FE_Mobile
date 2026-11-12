/// Gói đăng ký phía app. Việc mua diễn ra trên website (SePay): app chỉ xin liên kết [WebSessionLinkEntity]
/// rồi mở bằng trình duyệt, không có luồng thanh toán trong app. `cycle`/`status` ở đây là PascalCase nguyên văn
/// (enum C# qua JsonStringEnumConverter toàn cục, không qua mapper lowercase nào) — ví dụ "Monthly"/"Yearly",
/// "Pending"/"Paid"/"Cancelled"/"Expired"/"Voided"/"NeedsReview".
library;

class SubscriptionPlanFeatureEntity {
  final String key;
  final String name;
  final String description;
  final bool enabled;
  final int? monthlyLimit;

  const SubscriptionPlanFeatureEntity({
    required this.key,
    required this.name,
    required this.description,
    required this.enabled,
    this.monthlyLimit,
  });

  factory SubscriptionPlanFeatureEntity.fromJson(Map<String, dynamic> json) => SubscriptionPlanFeatureEntity(
        key: json['key'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? false,
        monthlyLimit: json['monthlyLimit'] as int?,
      );
}

class SubscriptionPlanEntity {
  final String id;
  final String code;
  final String name;
  final String? description;
  final BigInt? monthlyPriceCents;
  final BigInt? yearlyPriceCents;
  final bool isFree;
  final List<SubscriptionPlanFeatureEntity> features;

  const SubscriptionPlanEntity({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.monthlyPriceCents,
    this.yearlyPriceCents,
    required this.isFree,
    required this.features,
  });

  factory SubscriptionPlanEntity.fromJson(Map<String, dynamic> json) => SubscriptionPlanEntity(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        monthlyPriceCents:
            json['monthlyPriceCents'] == null ? null : BigInt.from(json['monthlyPriceCents'] as int),
        yearlyPriceCents: json['yearlyPriceCents'] == null ? null : BigInt.from(json['yearlyPriceCents'] as int),
        isFree: json['isFree'] as bool? ?? false,
        features: (json['features'] as List? ?? const [])
            .map((e) => SubscriptionPlanFeatureEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SubscriptionPeriodEntity {
  final String planCode;
  final String planName;
  final DateTime startsAt;
  final DateTime endsAt;

  const SubscriptionPeriodEntity({
    required this.planCode,
    required this.planName,
    required this.startsAt,
    required this.endsAt,
  });

  factory SubscriptionPeriodEntity.fromJson(Map<String, dynamic> json) => SubscriptionPeriodEntity(
        planCode: json['planCode'] as String,
        planName: json['planName'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
        endsAt: DateTime.parse(json['endsAt'] as String).toLocal(),
      );
}

class FeatureUsageEntity {
  final String key;
  final String name;
  final bool enabled;
  final int? monthlyLimit;
  final int used;

  const FeatureUsageEntity({
    required this.key,
    required this.name,
    required this.enabled,
    this.monthlyLimit,
    required this.used,
  });

  factory FeatureUsageEntity.fromJson(Map<String, dynamic> json) => FeatureUsageEntity(
        key: json['key'] as String,
        name: json['name'] as String,
        enabled: json['enabled'] as bool? ?? false,
        monthlyLimit: json['monthlyLimit'] as int?,
        used: json['used'] as int? ?? 0,
      );
}

/// Gói hiện tại của user + lịch sử gói sắp tới (mua trước khi gói hiện tại hết hạn vẫn xếp hàng, không mất tiền) + lượt dùng từng chức năng tháng này.
class MySubscriptionEntity {
  final bool enabled;
  final String planCode;
  final String planName;
  final bool isFree;
  final DateTime? expiresAt;
  final DateTime nextPurchaseStartsAt;
  final List<SubscriptionPeriodEntity> upcoming;
  final List<FeatureUsageEntity> features;

  const MySubscriptionEntity({
    required this.enabled,
    required this.planCode,
    required this.planName,
    required this.isFree,
    this.expiresAt,
    required this.nextPurchaseStartsAt,
    required this.upcoming,
    required this.features,
  });

  factory MySubscriptionEntity.fromJson(Map<String, dynamic> json) => MySubscriptionEntity(
        enabled: json['enabled'] as bool? ?? false,
        planCode: json['planCode'] as String,
        planName: json['planName'] as String,
        isFree: json['isFree'] as bool? ?? false,
        expiresAt: json['expiresAt'] == null ? null : DateTime.parse(json['expiresAt'] as String).toLocal(),
        nextPurchaseStartsAt: DateTime.parse(json['nextPurchaseStartsAt'] as String).toLocal(),
        upcoming: (json['upcoming'] as List? ?? const [])
            .map((e) => SubscriptionPeriodEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        features: (json['features'] as List? ?? const [])
            .map((e) => FeatureUsageEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Một đơn mua gói (tạo ở web, FE chỉ xem lại). `cycle`: "Monthly"/"Yearly". `status`: "Pending"/"Paid"/"Cancelled"/"Expired"/"Voided"/"NeedsReview".
class SubscriptionOrderEntity {
  final String invoiceNumber;
  final String planCode;
  final String planName;
  final String cycle;
  final BigInt amountCents;
  final String status;
  final DateTime createdAt;
  final DateTime? paidAt;

  const SubscriptionOrderEntity({
    required this.invoiceNumber,
    required this.planCode,
    required this.planName,
    required this.cycle,
    required this.amountCents,
    required this.status,
    required this.createdAt,
    this.paidAt,
  });

  bool get isPaid => status == 'Paid';

  factory SubscriptionOrderEntity.fromJson(Map<String, dynamic> json) => SubscriptionOrderEntity(
        invoiceNumber: json['invoiceNumber'] as String,
        planCode: json['planCode'] as String,
        planName: json['planName'] as String,
        cycle: json['cycle'] as String,
        amountCents: BigInt.from(json['amountCents'] as int),
        status: json['status'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        paidAt: json['paidAt'] == null ? null : DateTime.parse(json['paidAt'] as String).toLocal(),
      );
}

/// Liên kết một lần sang website để mua/gia hạn gói, mang mã dùng một lần, không mang token đăng nhập.
class WebSessionLinkEntity {
  final String url;
  final DateTime expiresAt;

  const WebSessionLinkEntity({required this.url, required this.expiresAt});

  factory WebSessionLinkEntity.fromJson(Map<String, dynamic> json) => WebSessionLinkEntity(
        url: json['url'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
      );
}
