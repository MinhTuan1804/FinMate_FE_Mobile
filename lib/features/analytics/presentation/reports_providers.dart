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

/// Như [monthlySummaryProvider] nhưng lọc theo 1 ví — dùng cho chip tài khoản trên Trang chủ
/// (Issue D, 2026-11-13). `null` = tổng mọi ví, cùng dữ liệu với [monthlySummaryProvider].
final monthlySummaryForAccountProvider = FutureProvider.family<MonthlySummary, String?>((ref, accountId) {
  // Luôn theo dõi monthlySummaryProvider (không chỉ dùng giá trị khi accountId null) để mọi nơi
  // gọi refreshDerivedData()/invalidate nó — sau khi tạo/xác nhận giao dịch, hoặc sau khi Flow 1
  // tự ghi nhận — cũng làm mới ĐÚNG nhánh đang lọc theo ví cụ thể, không chỉ nhánh "Tất cả". Thiếu
  // dòng này là lý do Thu nhập/Chi tiêu không đổi khi đang chọn 1 ví cụ thể (2026-11-13).
  ref.watch(monthlySummaryProvider);

  if (ref.watch(currentUserIdProvider) == null) return MonthlySummary.empty;
  if (accountId == null) return ref.watch(monthlySummaryProvider.future);
  final now = DateTime.now();
  return ref.watch(reportsRepositoryProvider).getMonthlySummary(year: now.year, month: now.month, accountId: accountId);
});

/// Khoảng ngày cho F1 tab Ngày/Tuần/Năm — [from]/[to] bao gồm cả 2 đầu, giờ local.
typedef DateRange = (DateTime from, DateTime to);

/// Thu/chi cộng dồn trong 1 khoảng ngày tùy ý (GET /reports/timeline, phân trang) — dùng cho F1 tab
/// Ngày/Tuần/Năm; tab Tháng vẫn dùng [monthlySummaryProvider] (monthly-summary), không qua đây.
final periodSummaryProvider = FutureProvider.autoDispose.family<MonthlySummary, DateRange>((ref, range) {
  if (ref.watch(currentUserIdProvider) == null) return MonthlySummary.empty;
  return ref.watch(reportsRepositoryProvider).getPeriodSummary(from: range.$1, to: range.$2);
});

final categoryBreakdownProvider = FutureProvider<CategoryBreakdown>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return CategoryBreakdown.empty;
  final now = DateTime.now();
  return ref.watch(reportsRepositoryProvider).getCategoryBreakdown(year: now.year, month: now.month);
});

/// Tháng/năm cần xem, dùng chung cho [monthlySummaryForMonthProvider] và
/// [categoryBreakdownForMonthProvider] — F2 cho đổi tháng xem lại, khác [monthlySummaryProvider]
/// (luôn là tháng hiện tại, dùng cho F1/Trang chủ).
typedef YearMonth = (int year, int month);

final monthlySummaryForMonthProvider = FutureProvider.autoDispose.family<MonthlySummary, YearMonth>((ref, ym) {
  if (ref.watch(currentUserIdProvider) == null) return MonthlySummary.empty;
  return ref.watch(reportsRepositoryProvider).getMonthlySummary(year: ym.$1, month: ym.$2);
});

final categoryBreakdownForMonthProvider = FutureProvider.autoDispose.family<CategoryBreakdown, YearMonth>((ref, ym) {
  if (ref.watch(currentUserIdProvider) == null) return CategoryBreakdown.empty;
  return ref.watch(reportsRepositoryProvider).getCategoryBreakdown(year: ym.$1, month: ym.$2);
});

/// (năm, tháng, 'expense'|'income') — F2 tab Chi tiêu/Thu nhập.
typedef YearMonthType = (int year, int month, String type);

final categoryBreakdownByTypeForMonthProvider = FutureProvider.autoDispose.family<CategoryBreakdown, YearMonthType>((ref, ymt) {
  if (ref.watch(currentUserIdProvider) == null) return CategoryBreakdown.empty;
  return ref.watch(reportsRepositoryProvider).getCategoryBreakdown(year: ymt.$1, month: ymt.$2, type: ymt.$3);
});

final forecastProvider = FutureProvider<Forecast>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return Forecast.empty;
  return ref.watch(reportsRepositoryProvider).getForecast();
});

/// Nhận xét AI do BE sinh sẵn (`InsightGeneratorJob`) — F1 chỉ hiện nhận xét mới nhất.
final spendingInsightsProvider = FutureProvider<List<SpendingInsight>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  return ref.watch(reportsRepositoryProvider).getInsights();
});
