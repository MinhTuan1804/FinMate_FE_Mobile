import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/survey/data/survey_repository.dart';
import 'package:finmate/features/survey/domain/survey.dart';

final surveyControllerProvider =
    StateNotifierProvider.autoDispose<SurveyController, AsyncValue<SurveyEntity?>>(
  (ref) => SurveyController(ref.watch(surveyRepositoryProvider))..load(),
);

/// Tải/gửi/bỏ qua/xóa khảo sát. KHÔNG giữ câu trả lời đang chọn trên máy ở đây — việc đó là state
/// UI cục bộ của màn hình (xem [SurveyScreen]), vì nhét nó vào `AsyncValue<SurveyEntity?>` bằng
/// cách emit lại CÙNG MỘT instance `SurveyEntity` sẽ bị Riverpod xem là "state không đổi" (AsyncValue
/// so sánh bằng giá trị) và bỏ qua rebuild — một kiểu bug im lặng tương tự vụ TextEditingController
/// dispose sớm ở FinanceMethods, nhưng ở đây tránh được bằng cách không tái sử dụng state này.
class SurveyController extends StateNotifier<AsyncValue<SurveyEntity?>> {
  SurveyController(this.repository) : super(const AsyncValue.loading());

  final SurveyRepository repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await repository.getSurvey());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> submit(List<SurveyAnswerEntity> answers) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await repository.submitAnswers(answers));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> skip() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await repository.skip());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteSurvey() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await repository.deleteSurvey());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// Đọc nhãn lỗi ngắn gọn từ [ApiException] theo mã lỗi BE (không dùng statusCode — xem ghi chú ở
/// FinanceMethods: `_handleError` gộp mọi lỗi dạng {error:{code,message}} về statusCode 400).
String surveyErrorMessage(Object error) {
  if (error is ApiException) {
    switch (error.code) {
      case 'SURVEY_ANSWER_INVALID':
        return 'Câu trả lời không hợp lệ: ${error.message}';
      case 'ONBOARDING_ALREADY_DECIDED':
        return 'Bạn đã làm hoặc đã bỏ qua khảo sát rồi.';
      default:
        return error.message;
    }
  }
  return error.toString();
}
