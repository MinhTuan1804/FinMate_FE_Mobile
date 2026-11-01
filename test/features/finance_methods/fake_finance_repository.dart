import 'package:finmate/features/finance_methods/data/finance_methods_repository.dart';
import 'package:finmate/features/finance_methods/domain/finance_models.dart';
import '../../fixtures/fixture.dart';

// Dữ liệu mẫu đọc từ phản hồi THẬT của backend (test/fixtures/api/finance_*.json), không tự viết tay.
Survey pendingSurvey() => Survey.fromJson(fixtureData('finance_survey_pending') as Map<String, dynamic>);
Recommendation sampleRecommendation() => Recommendation.fromJson(fixtureData('finance_recommendation') as Map<String, dynamic>);
UserMethod sampleUserMethod() => UserMethod.fromJson(fixtureData('finance_choose') as Map<String, dynamic>);
SpendableInfo sampleSpendable() => SpendableInfo.fromJson(fixtureData('finance_spendable') as Map<String, dynamic>);

List<FinanceMethod> sampleCatalog() =>
    (fixtureData('finance_catalog') as List).map((e) => FinanceMethod.fromJson(e as Map<String, dynamic>)).toList();

List<GoalSuggestion> sampleSuggestions() =>
    (fixtureData('finance_goal_suggestions') as List).map((e) => GoalSuggestion.fromJson(e as Map<String, dynamic>)).toList();

/// Một cách của danh mục thật, đang được người dùng dùng với vai trò [role] (tham số lấy mặc định).
UserMethod userMethodOf(String code, {String role = 'primary', Map<String, int> overrides = const {}}) {
  final method = sampleCatalog().firstWhere((m) => m.code == code);
  return UserMethod(
    id: 'um-$code',
    method: method,
    role: role,
    chosenVia: 'recommendation',
    overrides: overrides,
    effective: {for (final p in method.params) p.key: overrides[p.key] ?? p.defaultValue},
  );
}

/// Các hũ thật của backend (cách `category_budget` được gắn khối hũ nhu cầu / mong muốn / mục tiêu, thu nhập 20 triệu).
List<JarSet> jarSetsFixture() => (fixtureData('finance_jars') as List).map((e) => JarSet.fromJson(e as Map<String, dynamic>)).toList();

/// Cách đang dùng đó (khối "jars" nằm trong bố cục): `userMethodId` khớp với [jarSetsFixture].
UserMethod userMethodWithJars() =>
    (fixtureData('finance_my_methods_with_jars') as List).map((e) => UserMethod.fromJson(e as Map<String, dynamic>)).single;

/// Các cách người dùng đang dùng khi admin ĐÃ TẮT cách đó (phản hồi thật của backend): vẫn còn trong danh sách nhưng `available = false`.
List<UserMethod> unavailableUserMethods() =>
    (fixtureData('finance_my_methods_unavailable') as List).map((e) => UserMethod.fromJson(e as Map<String, dynamic>)).toList();

/// Ngưỡng cảnh báo thật của backend theo nguồn: `system`, `personal` hoặc `method`.
AlertThresholdSettings thresholdsFixture(String source) =>
    AlertThresholdSettings.fromJson(fixtureData('finance_alert_thresholds_$source') as Map<String, dynamic>);

/// Bản giả của backend: ghi lại mọi lời gọi ghi để test kiểm tra đúng cái đã gửi.
class FakeFinanceRepository implements IFinanceMethodsRepository {
  FakeFinanceRepository({
    Survey? survey,
    Recommendation? recommendation,
    this.recommendationError,
    this.submitError,
    AlertThresholdSettings? thresholds,
    this.thresholdError,
  })  : survey = survey ?? pendingSurvey(),
        recommendation = recommendation ?? sampleRecommendation(),
        thresholds = thresholds ?? thresholdsFixture('system');

  Survey survey;
  Recommendation recommendation;
  Object? recommendationError;
  Object? submitError;

  /// Các hũ "backend" giả trả về (mặc định không có).
  List<JarSet> jars = const [];

  /// Trạng thái ngưỡng hiện tại của "backend" giả; đặt/xóa ngưỡng cá nhân đổi nó như backend thật.
  AlertThresholdSettings thresholds;
  Object? thresholdError;
  final List<ThresholdPair> savedThresholds = [];
  int clearedThresholds = 0;

  final List<List<SurveyAnswer>> submitted = [];
  int skipSurveyCalls = 0;
  final List<String> skippedRecommendations = [];
  final List<({String code, String role, String? recommendationId})> chosen = [];

  @override
  Future<Survey> getSurvey() async => survey;

  @override
  Future<Survey> submitSurvey(List<SurveyAnswer> answers) async {
    if (submitError case final error?) throw error;
    submitted.add(answers);
    return survey;
  }

  @override
  Future<Survey> skipSurvey() async {
    skipSurveyCalls++;
    return survey;
  }

  @override
  Future<Recommendation> generateRecommendation() async {
    if (recommendationError case final error?) throw error;
    return recommendation;
  }

  @override
  Future<Recommendation> skipRecommendation(String id) async {
    skippedRecommendations.add(id);
    return recommendation;
  }

  @override
  Future<List<FinanceMethod>> getCatalog() async => sampleCatalog();

  @override
  Future<List<UserMethod>> getMyMethods() async => const [];

  @override
  Future<UserMethod> chooseMethod({required String methodCode, required String role, String? recommendationId}) async {
    chosen.add((code: methodCode, role: role, recommendationId: recommendationId));
    return userMethodOf(methodCode, role: role);
  }

  @override
  Future<UserMethod> updateMethodParams(String id, Map<String, int?> params) async => sampleUserMethod();

  @override
  Future<void> endMethod(String id) async {}

  @override
  Future<SpendableInfo> getSpendable() async => sampleSpendable();

  @override
  Future<List<GoalSuggestion>> getGoalSuggestions() async => sampleSuggestions();

  @override
  Future<List<JarSet>> getJars() async => jars;

  @override
  Future<AlertThresholdSettings> getAlertThresholds() async => thresholds;

  @override
  Future<AlertThresholdSettings> setAlertThresholds(int t1, int t2) async {
    if (thresholdError case final error?) throw error;
    savedThresholds.add(ThresholdPair(t1, t2));
    final pair = ThresholdPair(t1, t2);
    thresholds = AlertThresholdSettings(
      effective: pair,
      source: AlertThresholdSettings.sourcePersonal,
      methodCode: null,
      methodName: null,
      personal: pair,
      systemDefault: thresholds.systemDefault,
    );
    return thresholds;
  }

  @override
  Future<AlertThresholdSettings> clearAlertThresholds() async {
    clearedThresholds++;
    thresholds = AlertThresholdSettings(
      effective: thresholds.systemDefault,
      source: AlertThresholdSettings.sourceSystem,
      methodCode: null,
      methodName: null,
      personal: null,
      systemDefault: thresholds.systemDefault,
    );
    return thresholds;
  }
}
