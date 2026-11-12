import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/finance_methods/domain/finance_method.dart';

final financeMethodsRepositoryProvider = Provider<FinanceMethodsRepository>(
  (ref) => FinanceMethodsRepository(apiClient: ref.watch(apiClientProvider)),
);

class FinanceMethodsRepository {
  final ApiClient apiClient;

  FinanceMethodsRepository({required this.apiClient});

  /// GET /finance-methods: mọi cách đang bật, để người dùng tự chọn khi không nhận gợi ý.
  Future<List<MethodEntity>> getCatalog() async {
    final response = await apiClient.get(
      '/api/v1/finance-methods',
      fromJsonT: (json) => (json as List).map((e) => MethodEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  /// POST /finance-methods/recommendations: tạo gợi ý từ câu trả lời khảo sát. 422 nếu chưa làm khảo sát.
  Future<RecommendationEntity> generateRecommendation() async {
    final response = await apiClient.post(
      '/api/v1/finance-methods/recommendations',
      fromJsonT: (json) => RecommendationEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// GET /finance-methods/recommendations/latest. 404 nếu chưa có gợi ý nào.
  Future<RecommendationEntity> getLatestRecommendation() async {
    final response = await apiClient.get(
      '/api/v1/finance-methods/recommendations/latest',
      fromJsonT: (json) => RecommendationEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// POST /finance-methods/recommendations/{id}/skip
  Future<RecommendationEntity> skipRecommendation(String id) async {
    final response = await apiClient.post(
      '/api/v1/finance-methods/recommendations/$id/skip',
      fromJsonT: (json) => RecommendationEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// GET /me/methods: các cách tôi đang dùng (cách chính trước).
  Future<List<UserMethodEntity>> getMyMethods() async {
    final response = await apiClient.get(
      '/api/v1/me/methods',
      fromJsonT: (json) => (json as List).map((e) => UserMethodEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  /// POST /me/methods: chọn một cách làm chính hoặc bổ trợ, thay cách đang giữ vai trò đó.
  Future<UserMethodEntity> chooseMethod({required String methodCode, required String role, String? recommendationId}) async {
    final response = await apiClient.post(
      '/api/v1/me/methods',
      data: {'methodCode': methodCode, 'role': role, 'recommendationId': recommendationId},
      fromJsonT: (json) => UserMethodEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// PATCH /me/methods/{id}/params: gộp thay đổi vào phần ghi đè. Giá trị null trong [changes] xóa ghi đè (về mặc định).
  Future<UserMethodEntity> updateMethodParams(String id, Map<String, int?> changes) async {
    final response = await apiClient.patch(
      '/api/v1/me/methods/$id/params',
      data: {'params': changes},
      fromJsonT: (json) => UserMethodEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// DELETE /me/methods/{id}: ngừng dùng cách này. Dữ liệu giao dịch/ngân sách/mục tiêu không bị ảnh hưởng.
  Future<void> endMethod(String id) async {
    await apiClient.delete('/api/v1/me/methods/$id');
  }

  /// GET /me/goal-suggestions: mẫu mục tiêu gắn với cách đang dùng, đã bỏ mẫu không hợp theo khảo sát.
  Future<List<GoalSuggestionEntity>> getGoalSuggestions() async {
    final response = await apiClient.get(
      '/api/v1/me/goal-suggestions',
      fromJsonT: (json) => (json as List).map((e) => GoalSuggestionEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  /// GET /me/alert-thresholds
  Future<AlertThresholdSettingsEntity> getAlertThresholds() async {
    final response = await apiClient.get(
      '/api/v1/me/alert-thresholds',
      fromJsonT: (json) => AlertThresholdSettingsEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// PUT /me/alert-thresholds: đặt ngưỡng cá nhân (1 ≤ T1 < T2 ≤ 99). Chỉ có hiệu lực khi không có cách quản lý nào định nghĩa T1/T2.
  Future<AlertThresholdSettingsEntity> setAlertThresholds({required int t1Pct, required int t2Pct}) async {
    final response = await apiClient.put(
      '/api/v1/me/alert-thresholds',
      data: {'t1Pct': t1Pct, 't2Pct': t2Pct},
      fromJsonT: (json) => AlertThresholdSettingsEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// DELETE /me/alert-thresholds: xóa ngưỡng cá nhân, quay về mặc định hệ thống.
  Future<AlertThresholdSettingsEntity> clearAlertThresholds() async {
    await apiClient.delete('/api/v1/me/alert-thresholds');
    // ApiClient.delete không đọc phần thân (trả void), nhưng BE trả lại trạng thái mới — gọi GET lại cho chắc.
    return getAlertThresholds();
  }

  /// GET /me/jars: hũ của các cách đang dùng có khối "hũ" (cách chính trước; rỗng nếu không có).
  Future<List<JarSetEntity>> getJars() async {
    final response = await apiClient.get(
      '/api/v1/me/jars',
      fromJsonT: (json) => (json as List).map((e) => JarSetEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  /// GET /me/spendable: tiền khả dụng tháng này.
  Future<SpendableEntity> getSpendable() async {
    final response = await apiClient.get(
      '/api/v1/me/spendable',
      fromJsonT: (json) => SpendableEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }
}
