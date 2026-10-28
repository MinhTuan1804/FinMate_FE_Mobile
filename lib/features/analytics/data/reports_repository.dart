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

  Future<MonthlySummary> getMonthlySummary({required int year, required int month}) async {
    final response = await apiClient.get(
      '/api/v1/reports/monthly-summary',
      queryParameters: {'year': year, 'month': month},
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
}
