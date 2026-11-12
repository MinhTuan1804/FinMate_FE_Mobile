import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/survey/domain/survey.dart';

final surveyRepositoryProvider = Provider<SurveyRepository>(
  (ref) => SurveyRepository(apiClient: ref.watch(apiClientProvider)),
);

/// Khảo sát đầu vào ("onboarding"): 4 route dưới `/api/v1/survey`.
class SurveyRepository {
  final ApiClient apiClient;

  SurveyRepository({required this.apiClient});

  Future<SurveyEntity> getSurvey() async {
    final res = await apiClient.get<SurveyEntity>(
      '/api/v1/survey',
      fromJsonT: (json) => SurveyEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as SurveyEntity;
  }

  /// Thay toàn bộ câu trả lời và đánh dấu đã làm xong. BE tự lọc lại theo ShowIf của chính nó
  /// trước khi lưu — FE chỉ cần gửi những câu đang hiện trên màn hình theo logic ShowIf cục bộ.
  Future<SurveyEntity> submitAnswers(List<SurveyAnswerEntity> answers) async {
    final res = await apiClient.put<SurveyEntity>(
      '/api/v1/survey/answers',
      data: {'answers': answers.map((a) => a.toJson()).toList()},
      fromJsonT: (json) => SurveyEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as SurveyEntity;
  }

  Future<SurveyEntity> skip() async {
    final res = await apiClient.post<SurveyEntity>(
      '/api/v1/survey/skip',
      fromJsonT: (json) => SurveyEntity.fromJson(json as Map<String, dynamic>),
    );
    return res.data as SurveyEntity;
  }

  /// Xóa câu trả lời + các gợi ý suy ra từ chúng; khảo sát về lại 'pending'. BE không trả body cho
  /// DELETE (và `ApiClient.delete` không đọc body), nên gọi GET lại để lấy trạng thái mới nhất.
  Future<SurveyEntity> deleteSurvey() async {
    await apiClient.delete('/api/v1/survey');
    return getSurvey();
  }
}
