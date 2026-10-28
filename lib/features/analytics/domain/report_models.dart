import 'package:finmate/core/format/money.dart';

/// Tổng hợp thu/chi tháng (GET /reports/monthly-summary)
class MonthlySummary {
  final BigInt totalSpentCents;
  final BigInt totalIncomeCents;
  final BigInt netCents;
  final BigInt prevMonthSpentCents;
  final int transactionCount;

  /// % thay đổi chi tiêu so với tháng trước; null nếu tháng trước không có dữ liệu
  final double? changePercent;

  const MonthlySummary({
    required this.totalSpentCents,
    required this.totalIncomeCents,
    required this.netCents,
    required this.prevMonthSpentCents,
    required this.transactionCount,
    this.changePercent,
  });

  static final empty = MonthlySummary(
    totalSpentCents: BigInt.zero,
    totalIncomeCents: BigInt.zero,
    netCents: BigInt.zero,
    prevMonthSpentCents: BigInt.zero,
    transactionCount: 0,
  );

  factory MonthlySummary.fromJson(Map<String, dynamic> json) => MonthlySummary(
        totalSpentCents: parseCents(json['totalSpentCents']),
        totalIncomeCents: parseCents(json['totalIncomeCents']),
        netCents: parseCents(json['netCents']),
        prevMonthSpentCents: parseCents(json['prevMonthSpentCents']),
        transactionCount: (json['transactionCount'] as num?)?.toInt() ?? 0,
        changePercent: (json['changePercent'] as num?)?.toDouble(),
      );
}

/// Một danh mục trong cơ cấu chi tiêu
class CategoryShare {
  final String? categoryId;
  final String name;
  final String slug;
  final BigInt spentCents;
  final double percent;

  const CategoryShare({
    required this.categoryId,
    required this.name,
    required this.slug,
    required this.spentCents,
    required this.percent,
  });

  factory CategoryShare.fromJson(Map<String, dynamic> json) => CategoryShare(
        categoryId: json['categoryId'] as String?,
        name: json['categoryName'] as String? ?? 'Chưa phân loại',
        slug: json['categorySlug'] as String? ?? '',
        spentCents: parseCents(json['spentCents']),
        percent: (json['percent'] as num?)?.toDouble() ?? 0,
      );
}

/// Cơ cấu chi tiêu theo danh mục (GET /reports/category-breakdown)
class CategoryBreakdown {
  final BigInt totalSpentCents;
  final List<CategoryShare> items;

  const CategoryBreakdown({required this.totalSpentCents, required this.items});

  static final empty = CategoryBreakdown(totalSpentCents: BigInt.zero, items: const []);

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) => CategoryBreakdown(
        totalSpentCents: parseCents(json['totalSpentCents']),
        items: ((json['items'] as List?) ?? const []).map((e) => CategoryShare.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// Lời khuyên đi kèm dự báo; backend chỉ trả khi người dùng đã khai báo thu nhập
class ForecastAdvice {
  final BigInt monthlyIncomeCents;

  /// Số dư dự kiến cuối tháng (có thể âm)
  final BigInt projectedBalanceCents;

  /// Số tiền nên cắt giảm mỗi ngày để không âm; null nếu không cần
  final BigInt? suggestedDailyCutCents;

  const ForecastAdvice({
    required this.monthlyIncomeCents,
    required this.projectedBalanceCents,
    this.suggestedDailyCutCents,
  });

  /// null nếu không phải object (ví dụ null hoặc chuỗi từ phiên bản backend cũ)
  static ForecastAdvice? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return ForecastAdvice(
      monthlyIncomeCents: parseCents(json['monthlyIncomeCents']),
      projectedBalanceCents: parseCents(json['projectedBalanceCents']),
      suggestedDailyCutCents: json['suggestedDailyCutCents'] == null ? null : parseCents(json['suggestedDailyCutCents']),
    );
  }
}

/// Dự báo chi tiêu cuối tháng (GET /reports/forecast)
class Forecast {
  final BigInt spentSoFarCents;
  final BigInt projectedSpendCents;
  final int daysElapsed;
  final int daysInMonth;
  final int basedOnDays;

  /// low | medium | high
  final String confidence;
  final ForecastAdvice? advice;

  const Forecast({
    required this.spentSoFarCents,
    required this.projectedSpendCents,
    required this.daysElapsed,
    required this.daysInMonth,
    required this.basedOnDays,
    required this.confidence,
    this.advice,
  });

  static final empty = Forecast(
    spentSoFarCents: BigInt.zero,
    projectedSpendCents: BigInt.zero,
    daysElapsed: 0,
    daysInMonth: 0,
    basedOnDays: 0,
    confidence: 'low',
  );

  /// Chưa có dữ liệu để dự báo
  bool get hasData => basedOnDays > 0 || spentSoFarCents > BigInt.zero;

  factory Forecast.fromJson(Map<String, dynamic> json) => Forecast(
        spentSoFarCents: parseCents(json['spentSoFarCents']),
        projectedSpendCents: parseCents(json['projectedSpendCents']),
        daysElapsed: (json['daysElapsed'] as num?)?.toInt() ?? 0,
        daysInMonth: (json['daysInMonth'] as num?)?.toInt() ?? 0,
        basedOnDays: (json['basedOnDays'] as num?)?.toInt() ?? 0,
        confidence: json['confidence'] as String? ?? 'low',
        advice: ForecastAdvice.tryParse(json['advice']),
      );
}
