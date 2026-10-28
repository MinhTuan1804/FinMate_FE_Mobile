import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/analytics/presentation/reports_providers.dart';
import 'package:finmate/features/planning/presentation/controllers/planning_controller.dart';

/// Ghi giao dịch làm thay đổi số dư, ngân sách và báo cáo: tải lại các phần phụ thuộc
void refreshDerivedData(Ref ref) {
  ref.read(accountsControllerProvider.notifier).load();
  ref.read(planningControllerProvider.notifier).loadPlanningData(silent: true);
  ref.invalidate(monthlySummaryProvider);
  ref.invalidate(categoryBreakdownProvider);
  ref.invalidate(forecastProvider);
}
