import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/forecast/domain/forecast.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';

final forecastRepositoryProvider = Provider<ForecastRepository>(
  (ref) => ForecastRepository(apiClient: ref.watch(apiClientProvider)),
);

String _dateOnly(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

/// "one_off"/"user_marked" (chuỗi BE trả về) -> "OneOff"/"UserMarked" (tên enum C# BE nhận ở request).
String _exclusionReasonApiValue(String reason) => switch (reason) {
      'one_off' => 'OneOff',
      'user_marked' => 'UserMarked',
      _ => reason,
    };

/// Một khoản thu/chi giả định để thử kịch bản (không lưu gì ở BE).
class ScenarioItemInput {
  final DateTime date;
  final BigInt amountCents;
  final RecurringDirection direction;
  final String? label;

  const ScenarioItemInput({required this.date, required this.amountCents, required this.direction, this.label});

  Map<String, dynamic> toJson() => {
        'date': _dateOnly(date),
        'amountCents': amountCents.toInt(),
        'direction': direction.apiValue,
        if (label != null) 'label': label,
      };
}

/// Một danh mục + hạn mức muốn áp làm ngân sách kỳ tới (POST /forecast/categories/apply).
class CategoryBudgetItemInput {
  final String categoryId;
  final BigInt limitCents;

  const CategoryBudgetItemInput({required this.categoryId, required this.limitCents});

  Map<String, dynamic> toJson() => {'categoryId': categoryId, 'limitCents': limitCents.toInt()};
}

class ForecastRepository {
  final ApiClient apiClient;

  static const _path = '/api/v1/forecast';

  ForecastRepository({required this.apiClient});

  /// Số dư dự kiến từng ngày từ hôm nay tới [to] (mặc định cuối tháng, theo BE). [accountId] null = tất cả ví.
  Future<CashflowForecastEntity> getCashflow({String? accountId, DateTime? to}) async {
    final response = await apiClient.get(
      '$_path/cashflow',
      queryParameters: {
        if (accountId != null) 'accountId': accountId,
        if (to != null) 'to': _dateOnly(to),
      },
      fromJsonT: (json) => CashflowForecastEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Tính lại số dư với các khoản thu/chi giả định [items]. Không lưu gì ở BE.
  Future<CashflowForecastEntity> runScenario({
    String? accountId,
    DateTime? to,
    required List<ScenarioItemInput> items,
  }) async {
    final response = await apiClient.post(
      '$_path/cashflow/scenario',
      data: {
        if (accountId != null) 'accountId': accountId,
        if (to != null) 'to': _dateOnly(to),
        'items': items.map((i) => i.toJson()).toList(),
      },
      fromJsonT: (json) => CashflowForecastEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Số tiền có thể chi trong kỳ và mỗi ngày, kèm bảng cách tính.
  Future<SafeToSpendEntity> getSpendable() async {
    final response = await apiClient.get(
      '$_path/spendable',
      fromJsonT: (json) => SafeToSpendEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Tiến độ, mức chi dự kiến và trạng thái (ok|at_risk|over) của từng ngân sách tháng này.
  Future<List<BudgetForecastEntity>> getBudgets() async {
    final response = await apiClient.get(
      '$_path/budgets',
      fromJsonT: (json) => (json as List).map((e) => BudgetForecastEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  /// Lịch thu nhập dự kiến, khoản thu trễ, ước tính thu nhập không đều.
  Future<IncomeForecastEntity> getIncome() async {
    final response = await apiClient.get(
      '$_path/income',
      fromJsonT: (json) => IncomeForecastEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Các cảnh báo dự báo gần nhất (mới nhất trước).
  Future<List<ForecastAlertEntity>> getAlerts({int limit = 20}) async {
    final response = await apiClient.get(
      '$_path/alerts',
      queryParameters: {'limit': limit},
      fromJsonT: (json) => (json as List).map((e) => ForecastAlertEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  /// Báo một cảnh báo là không chính xác. BE hiện chỉ nhận feedback = "inaccurate".
  Future<ForecastAlertEntity> setAlertFeedback(String alertId) async {
    final response = await apiClient.post(
      '$_path/alerts/$alertId/feedback',
      data: {'feedback': 'inaccurate'},
      fromJsonT: (json) => ForecastAlertEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Khoản chi bị đánh dấu bất thường, mới nhất trước. [openOnly] = false thì lấy cả đã phản hồi.
  Future<List<AnomalyEntity>> getAnomalies({bool openOnly = true, int limit = 20}) async {
    final response = await apiClient.get(
      '$_path/anomalies',
      queryParameters: {if (!openOnly) 'status': 'all', 'limit': limit},
      fromJsonT: (json) => (json as List).map((e) => AnomalyEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  /// Phản hồi một khoản bất thường: normal | one_off | wrong_entry | suspicious.
  Future<AnomalyFeedbackResultEntity> setAnomalyFeedback({required String anomalyId, required String resolution}) async {
    final response = await apiClient.post(
      '$_path/anomalies/$anomalyId/feedback',
      data: {'resolution': resolution},
      fromJsonT: (json) => AnomalyFeedbackResultEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Chi tiêu dự kiến theo danh mục cho một tháng tới. [month] "yyyy-MM"; null = BE tự chọn tháng tới.
  Future<CategoryForecastEntity> getCategoryForecast({String? month}) async {
    final response = await apiClient.get(
      '$_path/categories',
      queryParameters: {if (month != null) 'month': month},
      fromJsonT: (json) => CategoryForecastEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// "Dùng làm ngân sách kỳ tới": lưu hạn mức (đã xem, có thể đã chỉnh) cho từng danh mục.
  Future<List<AppliedCategoryBudgetEntity>> applyCategoryBudgets(List<CategoryBudgetItemInput> items) async {
    final response = await apiClient.post(
      '$_path/categories/apply',
      data: {'items': items.map((i) => i.toJson()).toList()},
      fromJsonT: (json) =>
          (json as List).map((e) => AppliedCategoryBudgetEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  /// Ngày dự kiến đạt mục tiêu tiết kiệm. [scenarioMonthlyCents] khác null = thử mức góp khác, không lưu gì.
  Future<GoalForecastEntity> getGoalForecast(String goalId, {BigInt? scenarioMonthlyCents}) async {
    final response = await apiClient.get(
      '$_path/goals/$goalId',
      queryParameters: {if (scenarioMonthlyCents != null) 'monthlyContributionCents': scenarioMonthlyCents.toInt()},
      fromJsonT: (json) => GoalForecastEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Cài đặt dự báo hiện tại: dự phòng, ngưỡng số dư thấp, giờ yên lặng, bật/tắt cảnh báo, danh sách ví.
  Future<ForecastSettingsEntity> getSettings() async {
    final response = await apiClient.get(
      '/api/v1/me/forecast-settings',
      fromJsonT: (json) => ForecastSettingsEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Thay TOÀN BỘ cài đặt dự báo. [reserveCents]/[lowBalanceThresholdCents] null = dùng mặc định/tắt.
  /// [quietHoursStart]/[quietHoursEnd] cùng null = giờ yên lặng mặc định hệ thống.
  Future<ForecastSettingsEntity> updateSettings({
    BigInt? reserveCents,
    BigInt? lowBalanceThresholdCents,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool forecastAlertsEnabled = true,
  }) async {
    final response = await apiClient.put(
      '/api/v1/me/forecast-settings',
      data: {
        'reserveCents': reserveCents?.toInt(),
        'lowBalanceThresholdCents': lowBalanceThresholdCents?.toInt(),
        'quietHoursStart': quietHoursStart,
        'quietHoursEnd': quietHoursEnd,
        'forecastAlertsEnabled': forecastAlertsEnabled,
      },
      fromJsonT: (json) => ForecastSettingsEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Bật/tắt một ví có được tính vào dữ liệu dự báo hay không.
  Future<ForecastAccountEntity> setAccountInclusion(String accountId, bool included) async {
    final response = await apiClient.patch(
      '/api/v1/financial-accounts/$accountId/forecast-inclusion',
      data: {'included': included},
      fromJsonT: (json) => ForecastAccountEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Loại (hoặc đưa lại) một giao dịch khỏi dữ liệu dự báo. [reason]: "one_off" | "user_marked" (chỉ áp dụng khi [excluded] = true).
  Future<TransactionForecastExclusionEntity> setTransactionExclusion(
    String transactionId, {
    required bool excluded,
    String? reason,
  }) async {
    final response = await apiClient.patch(
      '/api/v1/transactions/$transactionId/forecast-exclusion',
      data: {
        'excluded': excluded,
        // BE nhận enum ForecastExclusionReason qua model binding nên cần đúng tên thành viên C# (PascalCase),
        // khác với chuỗi snake_case mà BE trả về khi đọc (ReasonText trong ForecastSettingsService).
        if (reason != null) 'reason': _exclusionReasonApiValue(reason),
      },
      fromJsonT: (json) => TransactionForecastExclusionEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }
}
