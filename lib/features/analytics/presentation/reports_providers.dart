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

final categoryBreakdownProvider = FutureProvider<CategoryBreakdown>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return CategoryBreakdown.empty;
  final now = DateTime.now();
  return ref.watch(reportsRepositoryProvider).getCategoryBreakdown(year: now.year, month: now.month);
});

final forecastProvider = FutureProvider<Forecast>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return Forecast.empty;
  return ref.watch(reportsRepositoryProvider).getForecast();
});
