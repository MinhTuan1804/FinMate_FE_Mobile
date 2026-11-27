import 'package:finmate/core/format/money.dart';

/// Dòng tiền của kỳ (Phase 90): chi/thu không gồm vay nợ, quỹ nhóm, chuyển ví; các khoản đó nằm ở đây.
/// [netCents] là số dư thực sự thay đổi (có thể âm), luôn bằng thu − chi ± các phần còn lại.
class CashFlow {
  final BigInt netCents;
  final BigInt loanOutflowCents;
  final BigInt loanInflowCents;
  final BigInt groupFundOutflowCents;
  final BigInt groupFundInflowCents;
  final BigInt transferOutflowCents;
  final BigInt transferInflowCents;
  final BigInt refundSurplusCents;
  final BigInt reversalNetCents;

  const CashFlow({
    required this.netCents,
    required this.loanOutflowCents,
    required this.loanInflowCents,
    required this.groupFundOutflowCents,
    required this.groupFundInflowCents,
    required this.transferOutflowCents,
    required this.transferInflowCents,
    required this.refundSurplusCents,
    required this.reversalNetCents,
  });

  factory CashFlow.fromJson(Map<String, dynamic> json) => CashFlow(
        netCents: parseCents(json['netCents']),
        loanOutflowCents: parseCents(json['loanOutflowCents']),
        loanInflowCents: parseCents(json['loanInflowCents']),
        groupFundOutflowCents: parseCents(json['groupFundOutflowCents']),
        groupFundInflowCents: parseCents(json['groupFundInflowCents']),
        transferOutflowCents: parseCents(json['transferOutflowCents']),
        transferInflowCents: parseCents(json['transferInflowCents']),
        refundSurplusCents: parseCents(json['refundSurplusCents']),
        reversalNetCents: parseCents(json['reversalNetCents']),
      );

  /// Các phần ngoài thu/chi có tác động (khác 0), có dấu: dương = tiền vào ví. Để giải thích vì sao số dư đổi khác thu − chi.
  List<(String, BigInt)> get otherParts => [
        ('Cho vay / trả nợ', loanInflowCents - loanOutflowCents),
        ('Quỹ nhóm', groupFundInflowCents - groupFundOutflowCents),
        ('Chuyển giữa các ví', transferInflowCents - transferOutflowCents),
        ('Hoàn tiền vượt chi', refundSurplusCents),
        ('Giao dịch bị đảo', reversalNetCents),
      ].where((p) => p.$2 != BigInt.zero).toList();
}

/// Tổng hợp thu/chi tháng (GET /reports/monthly-summary)
class MonthlySummary {
  final BigInt totalSpentCents;
  final BigInt totalIncomeCents;
  final BigInt netCents;
  final BigInt prevMonthSpentCents;
  final int transactionCount;

  /// % thay đổi chi tiêu so với tháng trước; null nếu tháng trước không có dữ liệu
  final double? changePercent;

  /// Tổng thu kỳ liền trước; null khi BE không trả (bản cũ).
  final BigInt? prevMonthIncomeCents;

  /// % thay đổi tổng thu so với kỳ liền trước; null khi kỳ trước không có thu.
  final double? incomeChangePercent;

  /// Dòng tiền của kỳ; null khi BE không trả (period-summary, bản cũ).
  final CashFlow? cashFlow;

  const MonthlySummary({
    required this.totalSpentCents,
    required this.totalIncomeCents,
    required this.netCents,
    required this.prevMonthSpentCents,
    required this.transactionCount,
    this.changePercent,
    this.prevMonthIncomeCents,
    this.incomeChangePercent,
    this.cashFlow,
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
        prevMonthIncomeCents: json['prevMonthIncomeCents'] == null ? null : parseCents(json['prevMonthIncomeCents']),
        incomeChangePercent: (json['incomeChangePercent'] as num?)?.toDouble(),
        cashFlow: json['cashFlow'] is Map<String, dynamic> ? CashFlow.fromJson(json['cashFlow'] as Map<String, dynamic>) : null,
      );

  /// GET /reports/period-summary: kỳ này và kỳ liền trước dài bằng kỳ này (Ngày/Tuần/Năm).
  factory MonthlySummary.fromPeriodJson(Map<String, dynamic> json) => MonthlySummary(
        totalSpentCents: parseCents(json['totalSpentCents']),
        totalIncomeCents: parseCents(json['totalIncomeCents']),
        netCents: parseCents(json['netCents']),
        prevMonthSpentCents: parseCents(json['prevTotalSpentCents']),
        transactionCount: (json['transactionCount'] as num?)?.toInt() ?? 0,
        changePercent: (json['spentChangePercent'] as num?)?.toDouble(),
        prevMonthIncomeCents: json['prevTotalIncomeCents'] == null ? null : parseCents(json['prevTotalIncomeCents']),
        incomeChangePercent: (json['incomeChangePercent'] as num?)?.toDouble(),
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

/// Một ngày trong GET /reports/timeline — dùng để cộng dồn thu/chi theo kỳ tùy ý (F1 Ngày/Tuần/Năm),
/// không cần giữ danh sách giao dịch chi tiết của ngày đó.
class TimelineDaySummary {
  /// Ngày (local, 00:00); null nếu BE không trả `date` hợp lệ.
  final DateTime? date;
  final BigInt totalSpentCents;
  final BigInt totalIncomeCents;
  final int transactionCount;

  const TimelineDaySummary({
    this.date,
    required this.totalSpentCents,
    required this.totalIncomeCents,
    required this.transactionCount,
  });

  factory TimelineDaySummary.fromJson(Map<String, dynamic> json) => TimelineDaySummary(
        date: DateTime.tryParse(json['date'] as String? ?? ''),
        totalSpentCents: parseCents(json['totalSpentCents']),
        totalIncomeCents: parseCents(json['totalIncomeCents']),
        transactionCount: (json['transactions'] as List?)?.length ?? 0,
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

/// Một nhận xét AI về chi tiêu (GET /reports/insights) — do `InsightGeneratorJob` sinh sẵn ở BE,
/// không phải suy diễn ở FE.
class SpendingInsight {
  final String id;
  final String insightType;
  final String title;
  final String body;
  final String? categoryName;
  final BigInt? amountCents;
  final bool isRead;

  const SpendingInsight({
    required this.id,
    required this.insightType,
    required this.title,
    required this.body,
    required this.categoryName,
    required this.amountCents,
    required this.isRead,
  });

  factory SpendingInsight.fromJson(Map<String, dynamic> json) => SpendingInsight(
        id: json['id'] as String,
        insightType: json['insightType'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        categoryName: json['categoryName'] as String?,
        amountCents: json['amountCents'] == null ? null : parseCents(json['amountCents']),
        isRead: json['isRead'] as bool? ?? false,
      );
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
