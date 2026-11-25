import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/finance_methods/data/finance_methods_repository.dart';
import 'package:finmate/features/finance_methods/domain/financial_plan.dart';

/// Bản nháp kế hoạch tháng. Hạn mức người dùng đang sửa là state cục bộ của màn (như câu trả lời nháp ở màn khảo sát);
/// số dư tính lại trên máy bằng [planSurplus], không gọi lại API.
final financialPlanDraftProvider = FutureProvider.autoDispose<FinancialPlanEntity>(
  (ref) => ref.watch(financeMethodsRepositoryProvider).getFinancialPlanDraft(),
);
