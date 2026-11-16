import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/analytics/domain/report_models.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(apiClient: ref.watch(apiClientProvider)),
);

/// Báo cáo tổng hợp từ backend (không tính toán lại ở FE, không dữ liệu mẫu)
class ReportsRepository {
  final ApiClient apiClient;

  ReportsRepository({required this.apiClient});

  /// [accountId] null = tổng mọi ví. Có giá trị = chỉ ví đó (Issue D, 2026-11-13: BE luôn tính
  /// live cho trường hợp này, không qua cache daily_summaries).
  Future<MonthlySummary> getMonthlySummary({required int year, required int month, String? accountId}) async {
    final response = await apiClient.get(
      '/api/v1/reports/monthly-summary',
      queryParameters: {'year': year, 'month': month, if (accountId != null) 'accountId': accountId},
      fromJsonT: (json) => MonthlySummary.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? MonthlySummary.empty;
  }

  /// Tổng chi/thu cho khoảng ngày bất kỳ (gồm cả hai đầu, giờ VN), tối đa 1100 ngày. Chỉ đọc 4 trường đầu của [MonthlySummary].
  Future<MonthlySummary> getPeriodSummary({required DateTime from, required DateTime to, String? accountId}) async {
    String day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final response = await apiClient.get(
      '/api/v1/reports/period-summary',
      queryParameters: {'fromDate': day(from), 'toDate': day(to), if (accountId != null) 'accountId': accountId},
      fromJsonT: (json) => MonthlySummary.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? MonthlySummary.empty;
  }

  Future<CategoryBreakdown> getCategoryBreakdown({required int year, required int month}) async {
    final response = await apiClient.get(
      '/api/v1/reports/category-breakdown',
      queryParameters: {'year': year, 'month': month},
      fromJsonT: (json) => CategoryBreakdown.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? CategoryBreakdown.empty;
  }

  Future<Forecast> getForecast() async {
    final response = await apiClient.get(
      '/api/v1/reports/forecast',
      fromJsonT: (json) => Forecast.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? Forecast.empty;
  }

  Future<List<SpendingInsight>> getInsights({bool unreadOnly = false}) async {
    final response = await apiClient.get(
      '/api/v1/reports/insights',
      queryParameters: {'unreadOnly': unreadOnly},
      fromJsonT: (json) => (json as List).map((e) => SpendingInsight.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  Future<void> markInsightRead(String id) async {
    await apiClient.patch('/api/v1/reports/insights/$id/read', fromJsonT: (json) => json);
  }
}
