import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/finance_methods/data/finance_methods_repository.dart';
import 'package:finmate/features/finance_methods/domain/finance_method.dart';

/// Danh mục mọi cách quản lý đang bật (ít đổi, tải một lần).
final methodCatalogProvider = FutureProvider.autoDispose<List<MethodEntity>>(
  (ref) => ref.watch(financeMethodsRepositoryProvider).getCatalog(),
);

/// Mẫu mục tiêu gắn với (các) cách đang dùng.
final goalSuggestionsProvider = FutureProvider.autoDispose<List<GoalSuggestionEntity>>(
  (ref) => ref.watch(financeMethodsRepositoryProvider).getGoalSuggestions(),
);

/// Hũ của (các) cách đang dùng có khối "hũ" — rỗng nếu không có cách nào như vậy.
final jarsProvider = FutureProvider.autoDispose<List<JarSetEntity>>(
  (ref) => ref.watch(financeMethodsRepositoryProvider).getJars(),
);

/// Tiền khả dụng tháng này.
final spendableProvider = FutureProvider.autoDispose<SpendableEntity>(
  (ref) => ref.watch(financeMethodsRepositoryProvider).getSpendable(),
);

/// Các cách quản lý tôi đang dùng; chọn/chỉnh tham số/kết thúc đều cập nhật lại list.
class MyMethodsController extends StateNotifier<AsyncValue<List<UserMethodEntity>>> {
  final FinanceMethodsRepository repository;

  MyMethodsController(this.repository) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repository.getMyMethods());
  }

  /// Lỗi (vd vai trò không hợp hoặc cách đang dùng vai trò còn lại) được ném lại cho màn hình.
  Future<UserMethodEntity> choose({required String methodCode, required String role, String? recommendationId}) async {
    final chosen = await repository.chooseMethod(methodCode: methodCode, role: role, recommendationId: recommendationId);
    await load();
    return chosen;
  }

  /// Lỗi (vd T1 ≥ T2) được ném lại cho màn hình, state giữ nguyên.
  Future<void> updateParams(String id, Map<String, int?> changes) async {
    final updated = await repository.updateMethodParams(id, changes);
    state = AsyncValue.data([for (final m in state.value ?? const <UserMethodEntity>[]) m.id == id ? updated : m]);
  }

  Future<void> end(String id) async {
    await repository.endMethod(id);
    state = AsyncValue.data([for (final m in state.value ?? const <UserMethodEntity>[]) if (m.id != id) m]);
  }
}

final myMethodsControllerProvider = StateNotifierProvider.autoDispose<MyMethodsController, AsyncValue<List<UserMethodEntity>>>(
  (ref) => MyMethodsController(ref.watch(financeMethodsRepositoryProvider)),
);

/// Gợi ý phương pháp mới nhất (null = chưa có lần nào, vd chưa làm khảo sát xong).
class RecommendationController extends StateNotifier<AsyncValue<RecommendationEntity?>> {
  final FinanceMethodsRepository repository;

  RecommendationController(this.repository) : super(const AsyncValue.data(null)) {
    loadLatest();
  }

  /// 404 (chưa có gợi ý nào) là trạng thái "chưa có" bình thường, không phải lỗi màn hình phải báo.
  /// Lỗi khác (mất mạng...) thì ném vào state.error để màn hình hiện nút Thử lại.
  /// Kiểm theo [ApiException.code] ('NOT_FOUND'), KHÔNG theo statusCode: ApiClient._handleError gộp
  /// mọi lỗi dạng {error:{code,message}} (bất kể status HTTP thật) vào BusinessRuleException với
  /// statusCode cố định 400, nên statusCode không phân biệt được 404 với 422 ở đây.
  Future<void> loadLatest() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await repository.getLatestRecommendation());
    } catch (e) {
      if (e is ApiException && e.code == 'NOT_FOUND') {
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  /// 422 khi chưa làm khảo sát: ném lại cho màn hình hiển thị, state giữ nguyên.
  Future<void> generate() async {
    final created = await repository.generateRecommendation();
    state = AsyncValue.data(created);
  }

  Future<void> skip(String id) async {
    final updated = await repository.skipRecommendation(id);
    state = AsyncValue.data(updated);
  }
}

final recommendationControllerProvider = StateNotifierProvider.autoDispose<RecommendationController, AsyncValue<RecommendationEntity?>>(
  (ref) => RecommendationController(ref.watch(financeMethodsRepositoryProvider)),
);

/// Ngưỡng cảnh báo của tôi và nguồn của nó.
class AlertThresholdsController extends StateNotifier<AsyncValue<AlertThresholdSettingsEntity>> {
  final FinanceMethodsRepository repository;

  AlertThresholdsController(this.repository) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repository.getAlertThresholds());
  }

  /// Lỗi (vd T1 ≥ T2) được ném lại cho màn hình, state giữ nguyên.
  Future<void> setPersonal({required int t1Pct, required int t2Pct}) async {
    final updated = await repository.setAlertThresholds(t1Pct: t1Pct, t2Pct: t2Pct);
    state = AsyncValue.data(updated);
  }

  Future<void> clearPersonal() async {
    final updated = await repository.clearAlertThresholds();
    state = AsyncValue.data(updated);
  }
}

final alertThresholdsControllerProvider =
    StateNotifierProvider.autoDispose<AlertThresholdsController, AsyncValue<AlertThresholdSettingsEntity>>(
  (ref) => AlertThresholdsController(ref.watch(financeMethodsRepositoryProvider)),
);
