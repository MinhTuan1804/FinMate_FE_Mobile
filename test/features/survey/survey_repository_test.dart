import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/survey/data/survey_repository.dart';
import 'package:finmate/features/survey/domain/survey.dart';
import '../../fixtures/fixture.dart';

void main() {
  group('SurveyRepository', () {
    test('getSurvey() GET đúng path, parse đủ questions/answers/showIf', () async {
      final adapter = RouteAdapter((o) => respondFixture('survey_pending'));
      final repo = SurveyRepository(apiClient: testApiClient(adapter));

      final survey = await repo.getSurvey();

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, contains('/api/v1/survey'));
      expect(survey.status, 'pending');
      expect(survey.isPending, isTrue);
      expect(survey.completedAt, isNull);
      expect(survey.questions, hasLength(10));
      expect(survey.answers, isEmpty);
      final saving = survey.questions.firstWhere((q) => q.code == 'saving_style');
      expect(saving.showIf, isNotNull);
      expect(saving.showIf!['all'], hasLength(2));
      final income = survey.questions.firstWhere((q) => q.code == 'income_pattern');
      expect(income.showIf, isNull);
      expect(income.options, hasLength(5));
    });

    test('getSurvey() với survey đã completed: status/completedAt/answers đúng', () async {
      final adapter = RouteAdapter((o) => respondFixture('survey_completed'));
      final repo = SurveyRepository(apiClient: testApiClient(adapter));

      final survey = await repo.getSurvey();

      expect(survey.status, 'completed');
      expect(survey.isCompleted, isTrue);
      expect(survey.completedAt, isNotNull);
      expect(survey.answers, hasLength(10));
      expect(survey.answers.firstWhere((a) => a.questionCode == 'saving_style').optionCode, 'B');
    });

    test('submitAnswers() PUT đúng path + body {answers}', () async {
      final adapter = RouteAdapter((o) => respondFixture('survey_completed'));
      final repo = SurveyRepository(apiClient: testApiClient(adapter));

      final answers = [
        const SurveyAnswerEntity(questionCode: 'income_pattern', optionCode: 'A'),
        const SurveyAnswerEntity(questionCode: 'main_goal', optionCode: 'B'),
      ];
      final survey = await repo.submitAnswers(answers);

      final req = adapter.requests.single;
      expect(req.method, 'PUT');
      expect(req.path, contains('/api/v1/survey/answers'));
      expect(req.data, {
        'answers': [
          {'questionCode': 'income_pattern', 'optionCode': 'A'},
          {'questionCode': 'main_goal', 'optionCode': 'B'},
        ],
      });
      expect(survey.status, 'completed');
    });

    test('submitAnswers() với lỗi SURVEY_ANSWER_INVALID (ví dụ trùng câu) → ném đúng ApiException', () async {
      final adapter = RouteAdapter((o) => respondFixture('survey_answer_invalid', status: 422));
      final repo = SurveyRepository(apiClient: testApiClient(adapter));

      await expectLater(
        repo.submitAnswers([const SurveyAnswerEntity(questionCode: 'income_pattern', optionCode: 'A')]),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'SURVEY_ANSWER_INVALID')),
      );
    });

    test('skip() POST đúng path', () async {
      final adapter = RouteAdapter((o) => respondFixture('survey_skipped'));
      final repo = SurveyRepository(apiClient: testApiClient(adapter));

      final survey = await repo.skip();

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, contains('/api/v1/survey/skip'));
      expect(survey.status, 'skipped');
    });

    test('skip() khi đã quyết định rồi → ném ONBOARDING_ALREADY_DECIDED', () async {
      final adapter = RouteAdapter((o) => respondFixture('survey_already_decided', status: 409));
      final repo = SurveyRepository(apiClient: testApiClient(adapter));

      await expectLater(
        repo.skip(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'ONBOARDING_ALREADY_DECIDED')),
      );
    });

    test('deleteSurvey() gọi DELETE rồi GET lại để lấy trạng thái mới (về pending)', () async {
      var deleteCalled = false;
      final adapter = RouteAdapter((o) {
        if (o.method == 'DELETE') {
          deleteCalled = true;
          return respondJson({'success': true, 'data': null, 'error': null, 'meta': null});
        }
        return respondFixture('survey_pending');
      });
      final repo = SurveyRepository(apiClient: testApiClient(adapter));

      final survey = await repo.deleteSurvey();

      expect(deleteCalled, isTrue);
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.first.method, 'DELETE');
      expect(adapter.requests.first.path, contains('/api/v1/survey'));
      expect(adapter.requests.last.method, 'GET');
      expect(survey.status, 'pending');
    });
  });
}
