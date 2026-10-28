import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/analytics/data/reports_repository.dart';
import 'package:finmate/features/analytics/domain/report_models.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';

/// Các provider báo cáo của tháng hiện tại; tự tải lại khi đổi người dùng,
/// chưa đăng nhập thì trả về báo cáo rỗng (không gọi API).
final monthlySummaryProvider = FutureProvider<MonthlySummary>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return MonthlySummary.empty;
  final now = DateTime.now();
  return ref.watch(reportsRepositoryProvider).getMonthlySummary(year: now.year, month: now.month);
});

final categoryBreakdownProvider = FutureProvider<CategoryBreakdown>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return CategoryBreakdown.empty;
  final now = DateTime.now();
  return ref.watch(reportsRepositoryProvider).getCategoryBreakdown(year: now.year, month: now.month);
});

final forecastProvider = FutureProvider<Forecast>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return Forecast.empty;
  return ref.watch(reportsRepositoryProvider).getForecast();
});
