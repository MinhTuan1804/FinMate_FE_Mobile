import 'package:finmate/core/format/money.dart';

/// Một khoản tiền vào/ra đã biết ngày trên đường số dư dự kiến (lương, hóa đơn, khoản giả định...).
class CashflowEventEntity {
  final String kind;
  final String label;
  final BigInt amountCents;
  final String? recurringItemId;

  const CashflowEventEntity({
    required this.kind,
    required this.label,
    required this.amountCents,
    this.recurringItemId,
  });

  factory CashflowEventEntity.fromJson(Map<String, dynamic> json) => CashflowEventEntity(
        kind: json['kind'] as String,
        label: json['label'] as String,
        amountCents: parseCents(json['amountCents']),
        recurringItemId: json['recurringItemId'] as String?,
      );
}

/// Số dư dự kiến của một ngày, kèm đường thận trọng/lạc quan và các khoản phát sinh đúng ngày đó.
class CashflowDayEntity {
  final DateTime date;
  final BigInt expectedBalanceCents;
  final BigInt lowBalanceCents;
  final BigInt highBalanceCents;
  final BigInt flexibleSpendCents;
  final List<CashflowEventEntity> events;

  const CashflowDayEntity({
    required this.date,
    required this.expectedBalanceCents,
    required this.lowBalanceCents,
    required this.highBalanceCents,
    required this.flexibleSpendCents,
    required this.events,
  });

  String get formattedExpectedBalance => formatVnd(expectedBalanceCents);

  factory CashflowDayEntity.fromJson(Map<String, dynamic> json) => CashflowDayEntity(
        date: DateTime.parse(json['date'] as String),
        expectedBalanceCents: parseCents(json['expectedBalanceCents']),
        lowBalanceCents: parseCents(json['lowBalanceCents']),
        highBalanceCents: parseCents(json['highBalanceCents']),
        flexibleSpendCents: parseCents(json['flexibleSpendCents']),
        events: (json['events'] as List? ?? const [])
            .map((e) => CashflowEventEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Một nguyên nhân chính khiến số dư cuối kỳ tăng/giảm (hiện tối đa 3 cái, theo BE).
class CashflowCauseEntity {
  final String kind;
  final String label;
  final BigInt amountCents;

  const CashflowCauseEntity({required this.kind, required this.label, required this.amountCents});

  String get formattedAmount => formatVnd(amountCents);

  factory CashflowCauseEntity.fromJson(Map<String, dynamic> json) => CashflowCauseEntity(
        kind: json['kind'] as String,
        label: json['label'] as String,
        amountCents: parseCents(json['amountCents']),
      );
}

/// Dự báo dòng tiền/số dư cuối kỳ (GET /forecast/cashflow, POST /forecast/cashflow/scenario).
class CashflowForecastEntity {
  final DateTime from;
  final DateTime to;
  final BigInt startBalanceCents;
  final BigInt endBalanceCents;
  final BigInt endLowBalanceCents;
  final BigInt endHighBalanceCents;
  final DateTime lowestDay;
  final BigInt lowestBalanceCents;

  /// Độ tin cậy của dự báo, do BE đặt (vd. "high"/"medium"/"low")
  final String confidence;

  /// Cơ sở tính (vd. "recurring_items")
  final String basis;
  final List<CashflowDayEntity> days;
  final List<CashflowCauseEntity> mainCauses;

  const CashflowForecastEntity({
    required this.from,
    required this.to,
    required this.startBalanceCents,
    required this.endBalanceCents,
    required this.endLowBalanceCents,
    required this.endHighBalanceCents,
    required this.lowestDay,
    required this.lowestBalanceCents,
    required this.confidence,
    required this.basis,
    required this.days,
    required this.mainCauses,
  });

  String get formattedStartBalance => formatVnd(startBalanceCents);
  String get formattedEndBalance => formatVnd(endBalanceCents);
  String get formattedLowestBalance => formatVnd(lowestBalanceCents);

  factory CashflowForecastEntity.fromJson(Map<String, dynamic> json) => CashflowForecastEntity(
        from: DateTime.parse(json['from'] as String),
        to: DateTime.parse(json['to'] as String),
        startBalanceCents: parseCents(json['startBalanceCents']),
        endBalanceCents: parseCents(json['endBalanceCents']),
        endLowBalanceCents: parseCents(json['endLowBalanceCents']),
        endHighBalanceCents: parseCents(json['endHighBalanceCents']),
        lowestDay: DateTime.parse(json['lowestDay'] as String),
        lowestBalanceCents: parseCents(json['lowestBalanceCents']),
        confidence: json['confidence'] as String,
        basis: json['basis'] as String,
        days: (json['days'] as List? ?? const [])
            .map((e) => CashflowDayEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        mainCauses: (json['mainCauses'] as List? ?? const [])
            .map((e) => CashflowCauseEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Một ví và số dư hiện tại, dùng trong bảng cách tính "số tiền có thể chi".
class SpendableAccountEntity {
  final String id;
  final String name;
  final BigInt balanceCents;

  const SpendableAccountEntity({required this.id, required this.name, required this.balanceCents});

  String get formattedBalance => formatVnd(balanceCents);

  factory SpendableAccountEntity.fromJson(Map<String, dynamic> json) => SpendableAccountEntity(
        id: json['id'] as String,
        name: json['name'] as String,
        balanceCents: parseCents(json['balanceCents']),
      );
}

/// Một khoản thu/chi định kỳ rơi vào kỳ tính "số tiền có thể chi" (số tiền luôn dương).
class UpcomingItemEntity {
  final DateTime date;
  final String label;
  final BigInt amountCents;
  final String? recurringItemId;

  const UpcomingItemEntity({
    required this.date,
    required this.label,
    required this.amountCents,
    this.recurringItemId,
  });

  String get formattedAmount => formatVnd(amountCents);

  factory UpcomingItemEntity.fromJson(Map<String, dynamic> json) => UpcomingItemEntity(
        date: DateTime.parse(json['date'] as String),
        label: json['label'] as String,
        amountCents: parseCents(json['amountCents']),
        recurringItemId: json['recurringItemId'] as String?,
      );
}

/// Phần một mục tiêu tiết kiệm chiếm trong số tiền có thể chi (đã trừ sẵn phần cần để dành).
class SpendableGoalEntity {
  final String goalId;
  final String name;
  final BigInt requiredPerMonthCents;
  final BigInt depositedThisMonthCents;
  final BigInt setAsideCents;

  const SpendableGoalEntity({
    required this.goalId,
    required this.name,
    required this.requiredPerMonthCents,
    required this.depositedThisMonthCents,
    required this.setAsideCents,
  });

  String get formattedSetAside => formatVnd(setAsideCents);

  factory SpendableGoalEntity.fromJson(Map<String, dynamic> json) => SpendableGoalEntity(
        goalId: json['goalId'] as String,
        name: json['name'] as String,
        requiredPerMonthCents: parseCents(json['requiredPerMonthCents']),
        depositedThisMonthCents: parseCents(json['depositedThisMonthCents']),
        setAsideCents: parseCents(json['setAsideCents']),
      );
}

/// Số tiền có thể chi trong kỳ và mỗi ngày (GET /forecast/spendable). [spendableCents] không
/// bao giờ âm: hụt tiền thì dồn vào [shortfallCents] thay vì trả số có thể chi âm (theo BE).
class SafeToSpendEntity {
  final DateTime periodStart;
  final DateTime periodEnd;
  final int daysRemaining;

  /// "next_income" (dừng ở lần lương kế tiếp) hoặc "month_end" (dừng cuối tháng)
  final String periodBasis;
  final BigInt balanceCents;
  final BigInt expectedIncomeCents;
  final BigInt upcomingBillsCents;
  final BigInt goalSetAsideCents;
  final BigInt reserveCents;
  final BigInt spendableCents;
  final BigInt perDayCents;
  final BigInt shortfallCents;
  final List<SpendableAccountEntity> accounts;
  final List<UpcomingItemEntity> incomes;
  final List<UpcomingItemEntity> bills;
  final List<SpendableGoalEntity> goals;

  const SafeToSpendEntity({
    required this.periodStart,
    required this.periodEnd,
    required this.daysRemaining,
    required this.periodBasis,
    required this.balanceCents,
    required this.expectedIncomeCents,
    required this.upcomingBillsCents,
    required this.goalSetAsideCents,
    required this.reserveCents,
    required this.spendableCents,
    required this.perDayCents,
    required this.shortfallCents,
    required this.accounts,
    required this.incomes,
    required this.bills,
    required this.goals,
  });

  bool get hasShortfall => shortfallCents > BigInt.zero;

  String get formattedSpendable => formatVnd(spendableCents);
  String get formattedPerDay => formatVnd(perDayCents);
  String get formattedShortfall => formatVnd(shortfallCents);

  factory SafeToSpendEntity.fromJson(Map<String, dynamic> json) => SafeToSpendEntity(
        periodStart: DateTime.parse(json['periodStart'] as String),
        periodEnd: DateTime.parse(json['periodEnd'] as String),
        daysRemaining: json['daysRemaining'] as int,
        periodBasis: json['periodBasis'] as String,
        balanceCents: parseCents(json['balanceCents']),
        expectedIncomeCents: parseCents(json['expectedIncomeCents']),
        upcomingBillsCents: parseCents(json['upcomingBillsCents']),
        goalSetAsideCents: parseCents(json['goalSetAsideCents']),
        reserveCents: parseCents(json['reserveCents']),
        spendableCents: parseCents(json['spendableCents']),
        perDayCents: parseCents(json['perDayCents']),
        shortfallCents: parseCents(json['shortfallCents']),
        accounts: (json['accounts'] as List? ?? const [])
            .map((e) => SpendableAccountEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        incomes: (json['incomes'] as List? ?? const [])
            .map((e) => UpcomingItemEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        bills: (json['bills'] as List? ?? const [])
            .map((e) => UpcomingItemEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        goals: (json['goals'] as List? ?? const [])
            .map((e) => SpendableGoalEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Tiến độ, mức chi dự kiến và trạng thái của một ngân sách tháng này (GET /forecast/budgets).
/// [categoryId] null = ngân sách tổng.
class BudgetForecastEntity {
  final String budgetId;
  final String? categoryId;
  final String? categoryName;
  final BigInt limitCents;
  final BigInt spentCents;
  final BigInt projectedCents;
  final int projectedPercent;

  /// "ok" | "at_risk" | "over"
  final String status;
  final BigInt maxDailySpendCents;
  final int daysRemaining;

  /// "pace" (nhịp chi tháng này) | "history" (thói quen danh mục, đầu tháng chưa đủ ngày)
  final String basis;

  const BudgetForecastEntity({
    required this.budgetId,
    this.categoryId,
    this.categoryName,
    required this.limitCents,
    required this.spentCents,
    required this.projectedCents,
    required this.projectedPercent,
    required this.status,
    required this.maxDailySpendCents,
    required this.daysRemaining,
    required this.basis,
  });

  bool get isTotal => categoryId == null;
  bool get isOver => status == 'over';
  bool get isAtRisk => status == 'at_risk';

  String get formattedLimit => formatVnd(limitCents);
  String get formattedSpent => formatVnd(spentCents);
  String get formattedProjected => formatVnd(projectedCents);
  String get formattedMaxDailySpend => formatVnd(maxDailySpendCents);

  factory BudgetForecastEntity.fromJson(Map<String, dynamic> json) => BudgetForecastEntity(
        budgetId: json['budgetId'] as String,
        categoryId: json['categoryId'] as String?,
        categoryName: json['categoryName'] as String?,
        limitCents: parseCents(json['limitCents']),
        spentCents: parseCents(json['spentCents']),
        projectedCents: parseCents(json['projectedCents']),
        projectedPercent: json['projectedPercent'] as int,
        status: json['status'] as String,
        maxDailySpendCents: parseCents(json['maxDailySpendCents']),
        daysRemaining: json['daysRemaining'] as int,
        basis: json['basis'] as String,
      );
}

/// Một khoản thu định kỳ đã quá ngày dự kiến mà chưa thấy tiền về.
class LateIncomeEntity {
  final String recurringItemId;
  final String name;
  final BigInt amountCents;
  final DateTime expectedDate;
  final int daysLate;

  const LateIncomeEntity({
    required this.recurringItemId,
    required this.name,
    required this.amountCents,
    required this.expectedDate,
    required this.daysLate,
  });

  String get formattedAmount => formatVnd(amountCents);

  factory LateIncomeEntity.fromJson(Map<String, dynamic> json) => LateIncomeEntity(
        recurringItemId: json['recurringItemId'] as String,
        name: json['name'] as String,
        amountCents: parseCents(json['amountCents']),
        expectedDate: DateTime.parse(json['expectedDate'] as String),
        daysLate: json['daysLate'] as int,
      );
}

/// Ước tính thu nhập không đều: mức thận trọng (phân vị 25) và trung bình theo tháng gần đây.
class IrregularIncomeEntity {
  final BigInt conservativeMonthlyCents;
  final BigInt averageMonthlyCents;
  final int monthsUsed;
  final BigInt receivedThisMonthCents;

  const IrregularIncomeEntity({
    required this.conservativeMonthlyCents,
    required this.averageMonthlyCents,
    required this.monthsUsed,
    required this.receivedThisMonthCents,
  });

  String get formattedConservativeMonthly => formatVnd(conservativeMonthlyCents);
  String get formattedReceivedThisMonth => formatVnd(receivedThisMonthCents);

  factory IrregularIncomeEntity.fromJson(Map<String, dynamic> json) => IrregularIncomeEntity(
        conservativeMonthlyCents: parseCents(json['conservativeMonthlyCents']),
        averageMonthlyCents: parseCents(json['averageMonthlyCents']),
        monthsUsed: json['monthsUsed'] as int,
        receivedThisMonthCents: parseCents(json['receivedThisMonthCents']),
      );
}

/// Lịch thu nhập dự kiến, khoản thu trễ, ước tính thu nhập không đều (GET /forecast/income).
class IncomeForecastEntity {
  final bool isRegular;
  final List<UpcomingItemEntity> upcoming;
  final List<LateIncomeEntity> late;
  final IrregularIncomeEntity? irregular;

  const IncomeForecastEntity({
    required this.isRegular,
    required this.upcoming,
    required this.late,
    this.irregular,
  });

  factory IncomeForecastEntity.fromJson(Map<String, dynamic> json) => IncomeForecastEntity(
        isRegular: json['isRegular'] as bool,
        upcoming: (json['upcoming'] as List? ?? const [])
            .map((e) => UpcomingItemEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        late: (json['late'] as List? ?? const [])
            .map((e) => LateIncomeEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        irregular: json['irregular'] == null
            ? null
            : IrregularIncomeEntity.fromJson(json['irregular'] as Map<String, dynamic>),
      );
}

/// Một cảnh báo dự báo (GET /forecast/alerts). [data] là payload tự do kèm theo tuỳ loại cảnh báo
/// (vd. shortfallDate, budgetId...) — chỉ để debug/điều hướng, UI không cần đọc từng khoá.
class ForecastAlertEntity {
  final String id;

  /// low_balance | budget_risk | bill_due | bill_status_check | income_late | price_change |
  /// anomaly | group_budget | group_goal
  final String kind;
  final String title;
  final String body;
  final Map<String, dynamic> data;

  /// "pending" (đang hoãn qua giờ yên lặng) | "sent"
  final String status;
  final DateTime scheduledFor;
  final DateTime? sentAt;
  final bool markedInaccurate;
  final DateTime createdAt;

  const ForecastAlertEntity({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.data,
    required this.status,
    required this.scheduledFor,
    this.sentAt,
    required this.markedInaccurate,
    required this.createdAt,
  });

  factory ForecastAlertEntity.fromJson(Map<String, dynamic> json) => ForecastAlertEntity(
        id: json['id'] as String,
        kind: json['kind'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        status: json['status'] as String,
        scheduledFor: DateTime.parse(json['scheduledFor'] as String).toLocal(),
        sentAt: json['sentAt'] == null ? null : DateTime.parse(json['sentAt'] as String).toLocal(),
        markedInaccurate: json['markedInaccurate'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}

/// Một khoản chi bị đánh dấu bất thường (GET /forecast/anomalies).
class AnomalyEntity {
  final String id;
  final String transactionId;

  /// category_spike | merchant_spike | duplicate
  final String kind;

  /// "normal" | "high" — chỉ mức "high" mới được gửi thông báo đẩy
  final String severity;
  final BigInt amountCents;
  final BigInt typicalCents;
  final int ratioPercent;
  final String? categoryId;
  final String? merchantName;
  final DateTime? transactedAt;

  /// null = chưa phản hồi; "normal" | "one_off" | "wrong_entry" | "suspicious"
  final String? resolution;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  const AnomalyEntity({
    required this.id,
    required this.transactionId,
    required this.kind,
    required this.severity,
    required this.amountCents,
    required this.typicalCents,
    required this.ratioPercent,
    this.categoryId,
    this.merchantName,
    this.transactedAt,
    this.resolution,
    this.resolvedAt,
    required this.createdAt,
  });

  bool get isResolved => resolution != null;

  String get formattedAmount => formatVnd(amountCents);
  String get formattedTypical => formatVnd(typicalCents);

  factory AnomalyEntity.fromJson(Map<String, dynamic> json) => AnomalyEntity(
        id: json['id'] as String,
        transactionId: json['transactionId'] as String,
        kind: json['kind'] as String,
        severity: json['severity'] as String,
        amountCents: parseCents(json['amountCents']),
        typicalCents: parseCents(json['typicalCents']),
        ratioPercent: json['ratioPercent'] as int,
        categoryId: json['categoryId'] as String?,
        merchantName: json['merchantName'] as String?,
        transactedAt: json['transactedAt'] == null ? null : DateTime.parse(json['transactedAt'] as String).toLocal(),
        resolution: json['resolution'] as String?,
        resolvedAt: json['resolvedAt'] == null ? null : DateTime.parse(json['resolvedAt'] as String).toLocal(),
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}

/// Kết quả phản hồi một khoản bất thường. [guidance] chỉ có khi phản hồi là "suspicious" (giao dịch lạ).
class AnomalyFeedbackResultEntity {
  final AnomalyEntity anomaly;
  final String? guidance;

  const AnomalyFeedbackResultEntity({required this.anomaly, this.guidance});

  factory AnomalyFeedbackResultEntity.fromJson(Map<String, dynamic> json) => AnomalyFeedbackResultEntity(
        anomaly: AnomalyEntity.fromJson(json['anomaly'] as Map<String, dynamic>),
        guidance: json['guidance'] as String?,
      );
}

/// Một danh mục trong dự báo chi tiêu tháng tới (GET /forecast/categories). [categoryId] null = chưa phân loại
/// (không đề xuất hạn mức được).
class CategoryForecastItemEntity {
  final String? categoryId;
  final String categoryName;
  final BigInt projectedCents;

  /// "history" | "budget" | "average" | "none" — cùng từ vựng với basis của Cashflow
  final String basis;

  /// "normal" | "low" — cùng từ vựng với confidence của Cashflow
  final String confidence;
  final BigInt previousMonthCents;
  final BigInt? currentLimitCents;

  /// So với tháng trước; null khi tháng trước không chi gì.
  final int? changePercent;
  final bool changedSignificantly;

  /// Hạn mức đề xuất (đã làm tròn lên); null khi [categoryId] null (chưa phân loại).
  final BigInt? suggestedLimitCents;

  const CategoryForecastItemEntity({
    this.categoryId,
    required this.categoryName,
    required this.projectedCents,
    required this.basis,
    required this.confidence,
    required this.previousMonthCents,
    this.currentLimitCents,
    this.changePercent,
    required this.changedSignificantly,
    this.suggestedLimitCents,
  });

  bool get isUncategorized => categoryId == null;

  String get formattedProjected => formatVnd(projectedCents);
  String get formattedPreviousMonth => formatVnd(previousMonthCents);

  factory CategoryForecastItemEntity.fromJson(Map<String, dynamic> json) => CategoryForecastItemEntity(
        categoryId: json['categoryId'] as String?,
        categoryName: json['categoryName'] as String,
        projectedCents: parseCents(json['projectedCents']),
        basis: json['basis'] as String,
        confidence: json['confidence'] as String,
        previousMonthCents: parseCents(json['previousMonthCents']),
        currentLimitCents: json['currentLimitCents'] == null ? null : parseCents(json['currentLimitCents']),
        changePercent: json['changePercent'] as int?,
        changedSignificantly: json['changedSignificantly'] as bool,
        suggestedLimitCents: json['suggestedLimitCents'] == null ? null : parseCents(json['suggestedLimitCents']),
      );
}

/// Dự báo chi tiêu theo danh mục cho một tháng tới (GET /forecast/categories). [seasonalAdjusted] luôn false:
/// chưa điều chỉnh mùa vụ (cần trên một năm dữ liệu).
class CategoryForecastEntity {
  /// "yyyy-MM"
  final String month;

  /// Các tháng được phép chọn ("yyyy-MM"), hiện tại chỉ gồm các tháng tới.
  final List<String> availableMonths;
  final bool enoughHistory;
  final int monthsWithData;
  final bool seasonalAdjusted;
  final BigInt projectedTotalCents;
  final BigInt previousMonthTotalCents;
  final List<CategoryForecastItemEntity> items;

  const CategoryForecastEntity({
    required this.month,
    required this.availableMonths,
    required this.enoughHistory,
    required this.monthsWithData,
    required this.seasonalAdjusted,
    required this.projectedTotalCents,
    required this.previousMonthTotalCents,
    required this.items,
  });

  String get formattedProjectedTotal => formatVnd(projectedTotalCents);
  String get formattedPreviousMonthTotal => formatVnd(previousMonthTotalCents);

  factory CategoryForecastEntity.fromJson(Map<String, dynamic> json) => CategoryForecastEntity(
        month: json['month'] as String,
        availableMonths: (json['availableMonths'] as List? ?? const []).map((e) => e as String).toList(),
        enoughHistory: json['enoughHistory'] as bool,
        monthsWithData: json['monthsWithData'] as int,
        seasonalAdjusted: json['seasonalAdjusted'] as bool,
        projectedTotalCents: parseCents(json['projectedTotalCents']),
        previousMonthTotalCents: parseCents(json['previousMonthTotalCents']),
        items: (json['items'] as List? ?? const [])
            .map((e) => CategoryForecastItemEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Kết quả áp hạn mức đề xuất làm ngân sách (POST /forecast/categories/apply).
class AppliedCategoryBudgetEntity {
  final String budgetId;
  final String categoryId;
  final BigInt limitCents;

  /// "next_period" (danh mục đã có ngân sách — áp từ tháng sau) | "now" (ngân sách mới tạo — áp ngay)
  final String effective;

  const AppliedCategoryBudgetEntity({
    required this.budgetId,
    required this.categoryId,
    required this.limitCents,
    required this.effective,
  });

  bool get isNow => effective == 'now';
  String get formattedLimit => formatVnd(limitCents);

  factory AppliedCategoryBudgetEntity.fromJson(Map<String, dynamic> json) => AppliedCategoryBudgetEntity(
        budgetId: json['budgetId'] as String,
        categoryId: json['categoryId'] as String,
        limitCents: parseCents(json['limitCents']),
        effective: json['effective'] as String,
      );
}

/// Ngày dự kiến đạt mục tiêu tiết kiệm, trung bình và thận trọng (GET /forecast/goals/{goalId}).
class GoalForecastEntity {
  final String goalId;
  final String name;

  /// "active" | "completed" | "cancelled"
  final String goalStatus;
  final BigInt targetCents;
  final BigInt savedCents;
  final BigInt remainingCents;
  final int percentComplete;
  final DateTime? deadline;

  /// "reached" | "unreachable" | "no_deadline" | "on_track" | "behind"
  final String forecastStatus;
  final BigInt averageMonthlyCents;
  final BigInt conservativeMonthlyCents;
  final int monthsOfData;

  /// "normal" | "low"
  final String confidence;

  /// true nếu đang xem theo mức góp giả định (không lưu), không theo lịch sử góp thật.
  final bool isScenario;
  final DateTime? likelyDate;
  final DateTime? conservativeDate;

  /// Mức cần góp mỗi tháng để kịp hạn chót; chỉ có khi có hạn chót và chưa chắc kịp.
  final BigInt? requiredMonthlyCents;

  /// Thông điệp đã được BE soạn sẵn bằng tiếng Việt, hiện trực tiếp.
  final String message;

  const GoalForecastEntity({
    required this.goalId,
    required this.name,
    required this.goalStatus,
    required this.targetCents,
    required this.savedCents,
    required this.remainingCents,
    required this.percentComplete,
    this.deadline,
    required this.forecastStatus,
    required this.averageMonthlyCents,
    required this.conservativeMonthlyCents,
    required this.monthsOfData,
    required this.confidence,
    required this.isScenario,
    this.likelyDate,
    this.conservativeDate,
    this.requiredMonthlyCents,
    required this.message,
  });

  String get formattedTarget => formatVnd(targetCents);
  String get formattedSaved => formatVnd(savedCents);
  String get formattedRemaining => formatVnd(remainingCents);
  String get formattedAverageMonthly => formatVnd(averageMonthlyCents);
  String get formattedConservativeMonthly => formatVnd(conservativeMonthlyCents);

  factory GoalForecastEntity.fromJson(Map<String, dynamic> json) => GoalForecastEntity(
        goalId: json['goalId'] as String,
        name: json['name'] as String,
        goalStatus: json['goalStatus'] as String,
        targetCents: parseCents(json['targetCents']),
        savedCents: parseCents(json['savedCents']),
        remainingCents: parseCents(json['remainingCents']),
        percentComplete: json['percentComplete'] as int,
        deadline: json['deadline'] == null ? null : DateTime.parse(json['deadline'] as String),
        forecastStatus: json['forecastStatus'] as String,
        averageMonthlyCents: parseCents(json['averageMonthlyCents']),
        conservativeMonthlyCents: parseCents(json['conservativeMonthlyCents']),
        monthsOfData: json['monthsOfData'] as int,
        confidence: json['confidence'] as String,
        isScenario: json['isScenario'] as bool,
        likelyDate: json['likelyDate'] == null ? null : DateTime.parse(json['likelyDate'] as String),
        conservativeDate: json['conservativeDate'] == null ? null : DateTime.parse(json['conservativeDate'] as String),
        requiredMonthlyCents: json['requiredMonthlyCents'] == null ? null : parseCents(json['requiredMonthlyCents']),
        message: json['message'] as String,
      );
}


/// Một ví kèm trạng thái có tính vào dự báo hay không (trong ForecastSettingsEntity.accounts).
class ForecastAccountEntity {
  final String id;
  final String name;
  final bool includeInForecast;

  const ForecastAccountEntity({required this.id, required this.name, required this.includeInForecast});

  factory ForecastAccountEntity.fromJson(Map<String, dynamic> json) => ForecastAccountEntity(
        id: json['id'] as String,
        name: json['name'] as String,
        includeInForecast: json['includeInForecast'] as bool,
      );
}

/// Cài đặt dự báo của user: dự phòng, ngưỡng cảnh báo số dư thấp, giờ yên lặng, bật/tắt cảnh báo, danh sách ví.
class ForecastSettingsEntity {
  /// Dự phòng user tự đặt; null = dùng mặc định hệ thống ([defaultReservePercentOfIncome]).
  final BigInt? reserveCents;
  final int defaultReservePercentOfIncome;
  /// Dự phòng đang thực sự được trừ khi tính số tiền có thể chi (đã áp mặc định nếu [reserveCents] null).
  final BigInt effectiveReserveCents;
  /// Ngưỡng cảnh báo số dư thấp; null = tắt cảnh báo này.
  final BigInt? lowBalanceThresholdCents;
  /// Giờ yên lặng riêng "HH:mm"; null (cả hai) = dùng mặc định hệ thống.
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final String defaultQuietHoursStart;
  final String defaultQuietHoursEnd;
  final bool forecastAlertsEnabled;
  final List<ForecastAccountEntity> accounts;

  const ForecastSettingsEntity({
    this.reserveCents,
    required this.defaultReservePercentOfIncome,
    required this.effectiveReserveCents,
    this.lowBalanceThresholdCents,
    this.quietHoursStart,
    this.quietHoursEnd,
    required this.defaultQuietHoursStart,
    required this.defaultQuietHoursEnd,
    required this.forecastAlertsEnabled,
    this.accounts = const [],
  });

  bool get usesDefaultReserve => reserveCents == null;
  bool get usesDefaultQuietHours => quietHoursStart == null && quietHoursEnd == null;
  bool get lowBalanceAlertEnabled => lowBalanceThresholdCents != null;

  String get formattedEffectiveReserve => formatVnd(effectiveReserveCents);
  String? get formattedReserve => reserveCents == null ? null : formatVnd(reserveCents!);
  String? get formattedLowBalanceThreshold => lowBalanceThresholdCents == null ? null : formatVnd(lowBalanceThresholdCents!);

  factory ForecastSettingsEntity.fromJson(Map<String, dynamic> json) => ForecastSettingsEntity(
        reserveCents: json['reserveCents'] == null ? null : parseCents(json['reserveCents']),
        defaultReservePercentOfIncome: json['defaultReservePercentOfIncome'] as int,
        effectiveReserveCents: parseCents(json['effectiveReserveCents']),
        lowBalanceThresholdCents: json['lowBalanceThresholdCents'] == null ? null : parseCents(json['lowBalanceThresholdCents']),
        quietHoursStart: json['quietHoursStart'] as String?,
        quietHoursEnd: json['quietHoursEnd'] as String?,
        defaultQuietHoursStart: json['defaultQuietHoursStart'] as String,
        defaultQuietHoursEnd: json['defaultQuietHoursEnd'] as String,
        forecastAlertsEnabled: json['forecastAlertsEnabled'] as bool,
        accounts: (json['accounts'] as List<dynamic>? ?? const [])
            .map((e) => ForecastAccountEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Kết quả loại/đưa lại một giao dịch khỏi dữ liệu dự báo (PATCH /transactions/{id}/forecast-exclusion).
class TransactionForecastExclusionEntity {
  final String transactionId;
  final bool excludeFromForecast;
  /// one_off | user_marked | null (null khi [excludeFromForecast] = false)
  final String? reason;

  const TransactionForecastExclusionEntity({required this.transactionId, required this.excludeFromForecast, this.reason});

  factory TransactionForecastExclusionEntity.fromJson(Map<String, dynamic> json) => TransactionForecastExclusionEntity(
        transactionId: json['transactionId'] as String,
        excludeFromForecast: json['excludeFromForecast'] as bool,
        reason: json['reason'] as String?,
      );
}
