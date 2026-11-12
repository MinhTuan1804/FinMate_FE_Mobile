import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/forecast/data/forecast_repository.dart';
import 'package:finmate/features/forecast/domain/forecast.dart';

/// Dự báo dòng tiền của tất cả ví, từ hôm nay tới cuối kỳ mặc định của BE.
final cashflowForecastProvider = FutureProvider.autoDispose<CashflowForecastEntity>(
  (ref) => ref.watch(forecastRepositoryProvider).getCashflow(),
);

/// Số tiền có thể chi trong kỳ hiện tại.
final safeToSpendProvider = FutureProvider.autoDispose<SafeToSpendEntity>(
  (ref) => ref.watch(forecastRepositoryProvider).getSpendable(),
);

/// Tiến độ/dự kiến của từng ngân sách tháng này.
final budgetForecastProvider = FutureProvider.autoDispose<List<BudgetForecastEntity>>(
  (ref) => ref.watch(forecastRepositoryProvider).getBudgets(),
);

/// Lịch thu nhập dự kiến, khoản thu trễ, thu nhập không đều.
final incomeForecastProvider = FutureProvider.autoDispose<IncomeForecastEntity>(
  (ref) => ref.watch(forecastRepositoryProvider).getIncome(),
);

/// Danh sách cảnh báo dự báo + hành động báo "không chính xác".
class ForecastAlertsController extends StateNotifier<AsyncValue<List<ForecastAlertEntity>>> {
  final ForecastRepository repository;

  ForecastAlertsController(this.repository) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repository.getAlerts());
  }

  Future<void> markInaccurate(String alertId) async {
    final updated = await repository.setAlertFeedback(alertId);
    if (!mounted) return;
    state = AsyncValue.data([
      for (final a in state.value ?? const <ForecastAlertEntity>[]) a.id == alertId ? updated : a,
    ]);
  }
}

final forecastAlertsControllerProvider =
    StateNotifierProvider.autoDispose<ForecastAlertsController, AsyncValue<List<ForecastAlertEntity>>>(
  (ref) => ForecastAlertsController(ref.watch(forecastRepositoryProvider)),
);

/// Danh sách khoản bất thường, lọc "đang mở"/"tất cả" + hành động phản hồi.
class AnomaliesController extends StateNotifier<AsyncValue<List<AnomalyEntity>>> {
  final ForecastRepository repository;
  bool openOnly = true;

  AnomaliesController(this.repository) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repository.getAnomalies(openOnly: openOnly));
  }

  Future<void> setOpenOnly(bool value) async {
    if (openOnly == value) return;
    openOnly = value;
    await load();
  }

  /// Trả về kết quả đầy đủ (gồm [AnomalyFeedbackResultEntity.guidance]) để UI hiện hướng dẫn khi cần.
  Future<AnomalyFeedbackResultEntity> sendFeedback(String anomalyId, String resolution) async {
    final result = await repository.setAnomalyFeedback(anomalyId: anomalyId, resolution: resolution);
    if (mounted) {
      state = AsyncValue.data([
        for (final a in state.value ?? const <AnomalyEntity>[]) a.id == anomalyId ? result.anomaly : a,
      ]);
    }
    return result;
  }
}

final anomaliesControllerProvider =
    StateNotifierProvider.autoDispose<AnomaliesController, AsyncValue<List<AnomalyEntity>>>(
  (ref) => AnomaliesController(ref.watch(forecastRepositoryProvider)),
);

/// Dự báo chi tiêu theo danh mục, đổi được tháng xem + áp hạn mức đề xuất làm ngân sách.
class CategoryForecastController extends StateNotifier<AsyncValue<CategoryForecastEntity>> {
  final ForecastRepository repository;
  String? month;

  CategoryForecastController(this.repository) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repository.getCategoryForecast(month: month));
  }

  Future<void> setMonth(String value) async {
    if (month == value) return;
    month = value;
    await load();
  }

  /// Áp hạn mức đề xuất của một danh mục làm ngân sách kỳ tới, rồi tải lại để thấy currentLimitCents mới.
  Future<AppliedCategoryBudgetEntity> applySuggested(CategoryForecastItemEntity item) async {
    final results = await repository.applyCategoryBudgets([
      CategoryBudgetItemInput(categoryId: item.categoryId!, limitCents: item.suggestedLimitCents!),
    ]);
    await load();
    return results.single;
  }
}

final categoryForecastControllerProvider =
    StateNotifierProvider.autoDispose<CategoryForecastController, AsyncValue<CategoryForecastEntity>>(
  (ref) => CategoryForecastController(ref.watch(forecastRepositoryProvider)),
);

/// Ngày dự kiến đạt mục tiêu tiết kiệm [goalId] (theo lịch sử góp thật, không giả định).
final goalForecastProvider = FutureProvider.autoDispose.family<GoalForecastEntity, String>(
  (ref, goalId) => ref.watch(forecastRepositoryProvider).getGoalForecast(goalId),
);

/// Cài đặt dự báo của user: dự phòng, ngưỡng số dư thấp, giờ yên lặng, bật/tắt cảnh báo, danh sách ví.
class ForecastSettingsController extends StateNotifier<AsyncValue<ForecastSettingsEntity>> {
  final ForecastRepository repository;

  ForecastSettingsController(this.repository) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repository.getSettings());
  }

  /// Lưu toàn bộ cài đặt (PUT thay hết, không phải patch từng phần).
  Future<void> update({
    BigInt? reserveCents,
    BigInt? lowBalanceThresholdCents,
    String? quietHoursStart,
    String? quietHoursEnd,
    required bool forecastAlertsEnabled,
  }) async {
    final updated = await repository.updateSettings(
      reserveCents: reserveCents,
      lowBalanceThresholdCents: lowBalanceThresholdCents,
      quietHoursStart: quietHoursStart,
      quietHoursEnd: quietHoursEnd,
      forecastAlertsEnabled: forecastAlertsEnabled,
    );
    if (mounted) state = AsyncValue.data(updated);
  }

  /// Bật/tắt một ví có tính vào dự báo; chỉ cập nhật ví đó trong danh sách đang có, không tải lại cả cài đặt.
  Future<void> setAccountInclusion(String accountId, bool included) async {
    final updatedAccount = await repository.setAccountInclusion(accountId, included);
    final current = state.valueOrNull;
    if (!mounted || current == null) return;
    state = AsyncValue.data(ForecastSettingsEntity(
      reserveCents: current.reserveCents,
      defaultReservePercentOfIncome: current.defaultReservePercentOfIncome,
      effectiveReserveCents: current.effectiveReserveCents,
      lowBalanceThresholdCents: current.lowBalanceThresholdCents,
      quietHoursStart: current.quietHoursStart,
      quietHoursEnd: current.quietHoursEnd,
      defaultQuietHoursStart: current.defaultQuietHoursStart,
      defaultQuietHoursEnd: current.defaultQuietHoursEnd,
      forecastAlertsEnabled: current.forecastAlertsEnabled,
      accounts: [for (final a in current.accounts) a.id == updatedAccount.id ? updatedAccount : a],
    ));
  }
}

final forecastSettingsControllerProvider =
    StateNotifierProvider.autoDispose<ForecastSettingsController, AsyncValue<ForecastSettingsEntity>>(
  (ref) => ForecastSettingsController(ref.watch(forecastRepositoryProvider)),
);
