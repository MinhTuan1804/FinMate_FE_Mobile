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

  /// Tổng thu/chi trong [from]..[to] (2 đầu bao gồm, tính theo ngày) và kỳ liền trước dài bằng kỳ này,
  /// do BE tính (GET /reports/period-summary, tối đa 1100 ngày). Dùng cho F1 tab Ngày/Tuần/Năm và
  /// thẻ tổng của màn Lịch sử. Giờ trong [from]/[to] bị bỏ: BE chỉ nhận ngày.
  Future<MonthlySummary> getPeriodSummary({required DateTime from, required DateTime to, String? accountId}) async {
    final response = await apiClient.get(
      '/api/v1/reports/period-summary',
      queryParameters: {
        'fromDate': _dateOnly(from),
        'toDate': _dateOnly(to),
        if (accountId != null) 'accountId': accountId,
      },
      fromJsonT: (json) => MonthlySummary.fromPeriodJson(json as Map<String, dynamic>),
    );
    return response.data ?? MonthlySummary.empty;
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Các ngày có giao dịch trong [from]..[to] (GET /reports/timeline, phân trang theo cursor).
  /// Ngày không có giao dịch không có trong kết quả — nơi dùng tự coi là 0.
  Future<List<TimelineDaySummary>> getTimelineDays({required DateTime from, required DateTime to}) async {
    final days = <TimelineDaySummary>[];
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

      days.addAll(response.data ?? const <TimelineDaySummary>[]);
      cursor = response.meta?.nextCursor;
    } while (cursor != null);

    return days;
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
