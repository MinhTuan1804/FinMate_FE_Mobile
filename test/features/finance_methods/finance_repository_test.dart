import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/finance_methods/data/finance_methods_repository.dart';
import 'package:finmate/features/finance_methods/domain/finance_models.dart';
import '../../fixtures/fixture.dart';

void main() {
  late RouteAdapter adapter;
  late FinanceMethodsRepository repository;

  setUp(() {
    adapter = RouteAdapter((options) {
      final route = '${options.method} ${options.path}';
      return switch (route) {
        'GET /api/v1/survey' => respondFixture('finance_survey_pending'),
        'PUT /api/v1/survey/answers' => respondFixture('finance_survey_submit'),
        'POST /api/v1/survey/skip' => respondFixture('finance_survey_submit'),
        'POST /api/v1/finance-methods/recommendations' => respondFixture('finance_recommendation'),
        'GET /api/v1/finance-methods' => respondFixture('finance_catalog'),
        'GET /api/v1/me/methods' => respondFixture('finance_my_methods'),
        'POST /api/v1/me/methods' => respondFixture('finance_choose', status: 201),
        'GET /api/v1/me/spendable' => respondFixture('finance_spendable'),
        'GET /api/v1/me/goal-suggestions' => respondFixture('finance_goal_suggestions'),
        'GET /api/v1/me/jars' => respondFixture('finance_jars'),
        'GET /api/v1/me/alert-thresholds' => respondFixture('finance_alert_thresholds_personal'),
        'PUT /api/v1/me/alert-thresholds' => respondFixture('finance_alert_thresholds_personal'),
        'DELETE /api/v1/me/alert-thresholds' => respondFixture('finance_alert_thresholds_system'),
        'DELETE /api/v1/me/methods/um-1' => ResponseBody.fromString('', 204),
        _ when route.startsWith('PATCH /api/v1/me/methods/um-1/params') => respondFixture('finance_choose'),
        _ when route.startsWith('POST /api/v1/finance-methods/recommendations/') => respondFixture('finance_recommendation'),
        _ => respondJson({'success': false, 'error': {'code': 'NOT_FOUND', 'message': route}}, status: 404),
      };
    });
    repository = FinanceMethodsRepository(apiClient: testApiClient(adapter));
  });

  test('khảo sát: lấy, nộp (thay toàn bộ câu trả lời) và bỏ qua', () async {
    final survey = await repository.getSurvey();
    await repository.submitSurvey([const SurveyAnswer('income_pattern', 'A'), const SurveyAnswer('month_end_balance', 'B')]);
    await repository.skipSurvey();

    expect(survey.questions, isNotEmpty);
    expect(adapter.to('/survey/answers').single.data, {
      'answers': [
        {'questionCode': 'income_pattern', 'optionCode': 'A'},
        {'questionCode': 'month_end_balance', 'optionCode': 'B'},
      ],
    });
    expect(adapter.to('/survey/skip'), hasLength(1));
  });

  test('tạo gợi ý: đọc cả bố cục trang chủ và nới hạn chờ cho bước AI chọn', () async {
    final recommendation = await repository.generateRecommendation();

    expect(recommendation.primary.method.homeLayout, isNotEmpty);
    final request = adapter.to('/finance-methods/recommendations').single;
    expect(request.receiveTimeout, const Duration(seconds: 45));
  });

  test('lệnh thường không đặt hạn chờ riêng (dùng mặc định của ApiClient); chỉ lệnh chậm mới nới', () async {
    await repository.getCatalog();

    expect(adapter.to('/finance-methods').single.receiveTimeout, isNull);
  });

  test('chọn một cách: chỉ gửi recommendationId khi có', () async {
    await repository.chooseMethod(methodCode: 'category_budget', role: 'primary', recommendationId: 'rec-1');
    await repository.chooseMethod(methodCode: 'goal_fund', role: 'supporting');

    final bodies = adapter.requests.where((r) => r.method == 'POST' && r.path == '/api/v1/me/methods').map((r) => r.data).toList();
    expect(bodies, [
      {'methodCode': 'category_budget', 'role': 'primary', 'recommendationId': 'rec-1'},
      {'methodCode': 'goal_fund', 'role': 'supporting'},
    ]);
  });

  test('chỉnh tham số: null nghĩa là xóa ghi đè (về mặc định)', () async {
    await repository.updateMethodParams('um-1', {'t1_pct': 60, 't2_pct': null});

    expect(adapter.to('/me/methods/um-1/params').single.data, {
      'params': {'t1_pct': 60, 't2_pct': null},
    });
  });

  test('ngừng dùng một cách: DELETE và phản hồi 204 không lỗi', () async {
    await repository.endMethod('um-1');

    expect(adapter.requests.last.method, 'DELETE');
  });

  test('đọc các cách đang dùng, tiền khả dụng và mẫu mục tiêu', () async {
    final mine = await repository.getMyMethods();
    final spendable = await repository.getSpendable();
    final suggestions = await repository.getGoalSuggestions();

    expect(mine.single.method.homeLayout, isNotEmpty);
    expect(spendable.spendableCents, 20000000);
    expect(suggestions, isNotEmpty);
  });

  test('các hũ: đọc từ /me/jars', () async {
    final sets = await repository.getJars();

    expect(sets, hasLength(1));
    expect(sets.single.jars, hasLength(3));
    expect(adapter.to('/me/jars').single.method, 'GET');
  });

  test('ngưỡng cảnh báo: đọc, đặt ngưỡng cá nhân bằng PUT và đọc lại trạng thái sau khi xóa', () async {
    final current = await repository.getAlertThresholds();
    final saved = await repository.setAlertThresholds(50, 80);
    await repository.clearAlertThresholds();

    expect(current.source, AlertThresholdSettings.sourcePersonal);
    expect(saved.effective, const ThresholdPair(50, 80));
    expect(adapter.to('/me/alert-thresholds').where((r) => r.method == 'PUT').single.data, {'t1Pct': 50, 't2Pct': 80});
    final methods = adapter.to('/me/alert-thresholds').map((r) => r.method).toList();
    expect(methods.sublist(methods.length - 2), ['DELETE', 'GET'], reason: 'DELETE không có thân phản hồi nên phải đọc lại ngay');
  });

  test('bỏ qua gợi ý gọi đúng đường dẫn của gợi ý đó', () async {
    await repository.skipRecommendation('rec-9');

    expect(adapter.requests.last.path, '/api/v1/finance-methods/recommendations/rec-9/skip');
  });
}
