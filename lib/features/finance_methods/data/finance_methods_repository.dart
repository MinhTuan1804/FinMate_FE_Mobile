import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/finance_methods/domain/finance_models.dart';

final financeMethodsRepositoryProvider = Provider<IFinanceMethodsRepository>(
  (ref) => FinanceMethodsRepository(apiClient: ref.watch(apiClientProvider)),
);

/// Gọi backend của luồng quản lý tài chính. Màn hình chỉ phụ thuộc vào giao diện này để test bằng bản giả.
abstract class IFinanceMethodsRepository {
  Future<Survey> getSurvey();

  /// Thay TOÀN BỘ câu trả lời và đánh dấu đã làm xong. Chỉ gửi câu đang hiển thị: backend từ chối câu không tồn tại hoặc đã tắt.
  Future<Survey> submitSurvey(List<SurveyAnswer> answers);
  Future<Survey> skipSurvey();

  /// Tạo gợi ý từ câu trả lời khảo sát (AI chọn, luật là dự phòng; backend dùng lại gợi ý vừa tạo trong thời gian cấu hình với cùng câu trả lời).
  /// 422 `SURVEY_NOT_ANSWERED` nếu chưa làm khảo sát.
  Future<Recommendation> generateRecommendation();
  Future<Recommendation> skipRecommendation(String id);

  /// Mọi cách đang bật, để người dùng tự chọn khi không theo gợi ý.
  Future<List<FinanceMethod>> getCatalog();
  Future<List<UserMethod>> getMyMethods();

  /// [role] là `primary` hoặc `supporting`; chọn lại cùng vai trò thì thay cách đang giữ vai trò đó.
  Future<UserMethod> chooseMethod({required String methodCode, required String role, String? recommendationId});

  /// Giá trị null xóa ghi đè của tham số đó (về mặc định của phương pháp). Backend kiểm 1 ≤ T1 < T2 ≤ 99.
  Future<UserMethod> updateMethodParams(String id, Map<String, int?> params);
  Future<void> endMethod(String id);

  Future<SpendableInfo> getSpendable();
  Future<List<GoalSuggestion>> getGoalSuggestions();

  /// Các hũ (tính cho tháng hiện tại) của những cách đang dùng có khối "hũ"; rỗng nếu không có.
  Future<List<JarSet>> getJars();

  /// Ngưỡng cảnh báo ngân sách đang áp dụng và nguồn của nó.
  Future<AlertThresholdSettings> getAlertThresholds();

  /// Đặt ngưỡng cá nhân (1 ≤ T1 < T2 ≤ 99); 422 `ALERT_THRESHOLD_INVALID` nếu sai. Chỉ có hiệu lực khi không có cách quản lý nào định nghĩa T1/T2.
  Future<AlertThresholdSettings> setAlertThresholds(int t1, int t2);

  /// Xóa ngưỡng cá nhân, quay về mặc định hệ thống.
  Future<AlertThresholdSettings> clearAlertThresholds();
}

class FinanceMethodsRepository implements IFinanceMethodsRepository {
  FinanceMethodsRepository({required this.apiClient});

  final ApiClient apiClient;

  // AI chọn nên có thể mất vài giây (đo ~7 giây); nới hạn chờ để không báo "mất mạng" khi backend vẫn đang xử lý.
  static const _recommendationTimeout = Duration(seconds: 45);

  @override
  Future<Survey> getSurvey() async {
    final response = await apiClient.get('/api/v1/survey', fromJsonT: (json) => Survey.fromJson(json as Map<String, dynamic>));
    return response.data!;
  }

  @override
  Future<Survey> submitSurvey(List<SurveyAnswer> answers) async {
    final response = await apiClient.put(
      '/api/v1/survey/answers',
      data: {'answers': answers.map((a) => a.toJson()).toList()},
      fromJsonT: (json) => Survey.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  @override
  Future<Survey> skipSurvey() async {
    final response = await apiClient.post('/api/v1/survey/skip', fromJsonT: (json) => Survey.fromJson(json as Map<String, dynamic>));
    return response.data!;
  }

  @override
  Future<Recommendation> generateRecommendation() async {
    final response = await apiClient.post(
      '/api/v1/finance-methods/recommendations',
      receiveTimeout: _recommendationTimeout,
      fromJsonT: (json) => Recommendation.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  @override
  Future<Recommendation> skipRecommendation(String id) async {
    final response = await apiClient.post(
      '/api/v1/finance-methods/recommendations/$id/skip',
      fromJsonT: (json) => Recommendation.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  @override
  Future<List<FinanceMethod>> getCatalog() async {
    final response = await apiClient.get(
      '/api/v1/finance-methods',
      fromJsonT: (json) => (json as List).map((e) => FinanceMethod.fromJson(e as Map<String, dynamic>)).toList(growable: false),
    );
    return response.data ?? const [];
  }

  @override
  Future<List<UserMethod>> getMyMethods() async {
    final response = await apiClient.get(
      '/api/v1/me/methods',
      fromJsonT: (json) => (json as List).map((e) => UserMethod.fromJson(e as Map<String, dynamic>)).toList(growable: false),
    );
    return response.data ?? const [];
  }

  @override
  Future<UserMethod> chooseMethod({required String methodCode, required String role, String? recommendationId}) async {
    final response = await apiClient.post(
      '/api/v1/me/methods',
      data: {'methodCode': methodCode, 'role': role, if (recommendationId != null) 'recommendationId': recommendationId},
      fromJsonT: (json) => UserMethod.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  @override
  Future<UserMethod> updateMethodParams(String id, Map<String, int?> params) async {
    final response = await apiClient.patch(
      '/api/v1/me/methods/$id/params',
      data: {'params': params},
      fromJsonT: (json) => UserMethod.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  @override
  Future<void> endMethod(String id) => apiClient.delete('/api/v1/me/methods/$id');

  @override
  Future<SpendableInfo> getSpendable() async {
    final response = await apiClient.get('/api/v1/me/spendable', fromJsonT: (json) => SpendableInfo.fromJson(json as Map<String, dynamic>));
    return response.data!;
  }

  @override
  Future<List<JarSet>> getJars() async {
    final response = await apiClient.get(
      '/api/v1/me/jars',
      fromJsonT: (json) => (json as List).map((e) => JarSet.fromJson(e as Map<String, dynamic>)).toList(growable: false),
    );
    return response.data ?? const [];
  }

  @override
  Future<AlertThresholdSettings> getAlertThresholds() async {
    final response = await apiClient.get(
      '/api/v1/me/alert-thresholds',
      fromJsonT: (json) => AlertThresholdSettings.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  @override
  Future<AlertThresholdSettings> setAlertThresholds(int t1, int t2) async {
    final response = await apiClient.put(
      '/api/v1/me/alert-thresholds',
      data: {'t1Pct': t1, 't2Pct': t2},
      fromJsonT: (json) => AlertThresholdSettings.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  @override
  Future<AlertThresholdSettings> clearAlertThresholds() async {
    // ApiClient.delete không trả thân phản hồi; đọc lại trạng thái mới ngay sau khi xóa.
    await apiClient.delete('/api/v1/me/alert-thresholds');
    return getAlertThresholds();
  }

  @override
  Future<List<GoalSuggestion>> getGoalSuggestions() async {
    final response = await apiClient.get(
      '/api/v1/me/goal-suggestions',
      fromJsonT: (json) => (json as List).map((e) => GoalSuggestion.fromJson(e as Map<String, dynamic>)).toList(growable: false),
    );
    return response.data ?? const [];
  }
}
