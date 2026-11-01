import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/finance_methods/data/finance_methods_repository.dart';
import 'package:finmate/features/finance_methods/domain/finance_models.dart';

final surveyProvider = FutureProvider.autoDispose<Survey>(
  (ref) => ref.watch(financeMethodsRepositoryProvider).getSurvey(),
);

/// Các cách người dùng đang dùng. Chưa đăng nhập thì rỗng (không gọi API với phiên không có).
final myMethodsProvider = FutureProvider.autoDispose<List<UserMethod>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return const <UserMethod>[];
  return ref.watch(financeMethodsRepositoryProvider).getMyMethods();
});

/// Mọi cách đang bật. Danh mục do admin quản lý nên app không giữ bản cứng.
final financeCatalogProvider = FutureProvider.autoDispose<List<FinanceMethod>>(
  (ref) => ref.watch(financeMethodsRepositoryProvider).getCatalog(),
);

final spendableProvider = FutureProvider.autoDispose<SpendableInfo>(
  (ref) => ref.watch(financeMethodsRepositoryProvider).getSpendable(),
);

final goalSuggestionsProvider = FutureProvider.autoDispose<List<GoalSuggestion>>(
  (ref) => ref.watch(financeMethodsRepositoryProvider).getGoalSuggestions(),
);

/// Các hũ của tháng này (chi tiêu theo danh mục so với phần thu nhập được chia).
final jarsProvider = FutureProvider.autoDispose<List<JarSet>>(
  (ref) => ref.watch(financeMethodsRepositoryProvider).getJars(),
);

/// Ngưỡng cảnh báo ngân sách đang áp dụng và nguồn của nó (cách quản lý / cá nhân / mặc định hệ thống).
final alertThresholdsProvider = FutureProvider.autoDispose<AlertThresholdSettings>(
  (ref) => ref.watch(financeMethodsRepositoryProvider).getAlertThresholds(),
);

/// Sau khi chọn, đổi tham số hoặc ngừng dùng một cách: mọi thứ phụ thuộc vào cách đang dùng phải tải lại.
void refreshFinanceMethods(WidgetRef ref) {
  ref.invalidate(jarsProvider); // đổi tỷ lệ một hũ hoặc đổi cách quản lý là đổi số được chia
  ref.invalidate(alertThresholdsProvider); // đổi cách quản lý có thể đổi nguồn của ngưỡng
  ref.invalidate(myMethodsProvider);
  ref.invalidate(spendableProvider);
  ref.invalidate(goalSuggestionsProvider);
}
