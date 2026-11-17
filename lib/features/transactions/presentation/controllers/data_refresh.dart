import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/analytics/presentation/reports_providers.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';

/// Ghi giao dịch làm thay đổi số dư, ngân sách và báo cáo: tải lại các phần phụ thuộc.
///
/// async + await `load()`/`loadPlanningData()` (trước đây fire-and-forget): 2 hàm này tận cùng gọi
/// `syncAllWidgets()` (đẩy dữ liệu mới cho W1/W2/4×4) — phải đợi xong thật sự thì hàm tạo/xác nhận
/// giao dịch gọi `refreshDerivedData` mới được coi là xong, để tránh race lúc người dùng thoát app
/// ngay sau khi lưu (widget có thể chưa kịp nhận dữ liệu mới, phải mở lại app 1 lần nữa mới đúng).
Future<void> refreshDerivedData(Ref ref) async {
  await ref.read(accountsControllerProvider.notifier).load();
  await ref.read(planningControllerProvider.notifier).loadPlanningData(silent: true);
  ref.invalidate(monthlySummaryProvider);
  ref.invalidate(categoryBreakdownProvider);
  ref.invalidate(forecastProvider);
}
