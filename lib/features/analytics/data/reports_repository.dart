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

  /// [type] = 'expense' (mặc định) hoặc 'income' — F2 tab "Thu nhập".
  Future<CategoryBreakdown> getCategoryBreakdown({required int year, required int month, String type = 'expense'}) async {
    final response = await apiClient.get(
      '/api/v1/reports/category-breakdown',
      queryParameters: {'year': year, 'month': month, 'type': type},
      fromJsonT: (json) => CategoryBreakdown.fromJson(json as Map<String, dynamic>),
    );
    return response.data ?? CategoryBreakdown.empty;
  }

  /// Cộng dồn thu/chi trong [from]..[to] (2 đầu bao gồm) qua GET /reports/timeline, phân trang theo
  /// cursor cho tới khi hết (dùng cho F1 tab Ngày/Tuần/Năm — timeline không giới hạn khoảng ngày,
  /// chỉ giới hạn số giao dịch mỗi trang, nên "Năm" cần nhiều trang).
  Future<MonthlySummary> getPeriodSummary({required DateTime from, required DateTime to}) async {
    var spent = BigInt.zero;
    var income = BigInt.zero;
    var count = 0;
    String? cursor;

    do {
      final response = await apiClient.get(
        '/api/v1/reports/timeline',
        queryParameters: {
          'fromDate': from.toUtc().toIso8601String(),
          'toDate': to.toUtc().toIso8601String(),
          'limit': 100,
          if (cursor != null) 'cursor': cursor,
        },
        fromJsonT: (json) => (json as List).map((e) => TimelineDaySummary.fromJson(e as Map<String, dynamic>)).toList(),
      );

      for (final day in response.data ?? const <TimelineDaySummary>[]) {
        spent += day.totalSpentCents;
        income += day.totalIncomeCents;
        count += day.transactionCount;
      }
      cursor = response.meta?.nextCursor;
    } while (cursor != null);

    return MonthlySummary(
      totalSpentCents: spent,
      totalIncomeCents: income,
      netCents: income - spent,
      prevMonthSpentCents: BigInt.zero,
      transactionCount: count,
      changePercent: null,
    );
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
    await apiClient.patch('/api/v1/reports/insights/$id/read', fromJsonT: (_) => null);
  }
}
