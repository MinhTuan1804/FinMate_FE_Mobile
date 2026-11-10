import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/finance_methods/data/finance_methods_repository.dart';
import '../../fixtures/fixture.dart';

void main() {
  group('FinanceMethodsRepository', () {
    test('getCatalog() đọc đúng danh mục, kể cả role/goalMode nguyên văn lowercase/snake_case', () async {
      final adapter = RouteAdapter((o) => respondFixture('finance_methods_catalog'));
      final repo = FinanceMethodsRepository(apiClient: testApiClient(adapter));

      final methods = await repo.getCatalog();

      expect(adapter.requests.single.path, contains('/api/v1/finance-methods'));
      expect(methods, hasLength(4));
      final catBudget = methods.firstWhere((m) => m.code == 'category_budget');
      expect(catBudget.role, 'primary');
      expect(catBudget.goalMode, 'reserve_first');
      expect(catBudget.canBePrimary, isTrue);
      expect(catBudget.params.map((p) => p.key), contains('t1_pct'));
      final supportOnly = methods.firstWhere((m) => m.code == 'debt_repayment');
      expect(supportOnly.canBePrimary, isFalse);
      expect(supportOnly.canBeSupport, isTrue);
    });

    test('generateRecommendation() POST đúng path, parse source/outcome', () async {
      final adapter = RouteAdapter((o) => respondFixture('finance_recommendation'));
      final repo = FinanceMethodsRepository(apiClient: testApiClient(adapter));

      final rec = await repo.generateRecommendation();

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, contains('/finance-methods/recommendations'));
      expect(rec.source, 'rule_fallback');
      expect(rec.outcome, 'shown');
      expect(rec.support, isNull);
      expect(rec.primary.method.code, 'category_budget');
    });

    test('getLatestRecommendation() GET đúng path', () async {
      final adapter = RouteAdapter((o) => respondFixture('finance_recommendation'));
      final repo = FinanceMethodsRepository(apiClient: testApiClient(adapter));

      final rec = await repo.getLatestRecommendation();

      expect(adapter.requests.single.path, contains('/recommendations/latest'));
      expect(rec.id, 'rec-1');
    });

    test('skipRecommendation() POST đúng path, outcome đổi thành skipped', () async {
      final adapter = RouteAdapter((o) => respondFixture('finance_recommendation_skipped'));
      final repo = FinanceMethodsRepository(apiClient: testApiClient(adapter));

      final rec = await repo.skipRecommendation('rec-1');

      expect(adapter.requests.single.path, contains('/recommendations/rec-1/skip'));
      expect(rec.outcome, 'skipped');
    });

    test('getMyMethods() GET đúng path, parse overrides/effective', () async {
      final adapter = RouteAdapter((o) => respondFixture('my_methods'));
      final repo = FinanceMethodsRepository(apiClient: testApiClient(adapter));

      final list = await repo.getMyMethods();

      expect(adapter.requests.single.path, contains('/me/methods'));
      expect(list, hasLength(1));
      expect(list.single.effective['t1_pct'], 70);
      expect(list.single.chosenVia, 'recommended');
    });

    test('chooseMethod() POST đúng body (kể cả recommendationId null)', () async {
      final adapter = RouteAdapter((o) => respondFixture('my_method_chosen'));
      final repo = FinanceMethodsRepository(apiClient: testApiClient(adapter));

      final chosen = await repo.chooseMethod(methodCode: 'category_budget', role: 'primary');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, contains('/me/methods'));
      expect(req.data, {'methodCode': 'category_budget', 'role': 'primary', 'recommendationId': null});
      expect(chosen.chosenVia, 'manual');
    });

    test('updateMethodParams() PATCH đúng path và body (gộp cả null để xóa ghi đè)', () async {
      final adapter = RouteAdapter((o) => respondFixture('my_method_params_updated'));
      final repo = FinanceMethodsRepository(apiClient: testApiClient(adapter));

      final updated = await repo.updateMethodParams('um-1', {'t1_pct': 60, 'needs_pct': null});

      final req = adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, contains('/me/methods/um-1/params'));
      expect(req.data, {'params': {'t1_pct': 60, 'needs_pct': null}});
      expect(updated.overrides['t1_pct'], 60);
    });

    test('endMethod() gọi DELETE đúng path', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null}));
      final repo = FinanceMethodsRepository(apiClient: testApiClient(adapter));

      await repo.endMethod('um-1');

      final req = adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, contains('/me/methods/um-1'));
    });

    test('getGoalSuggestions() GET đúng path', () async {
      final adapter = RouteAdapter((o) => respondFixture('goal_suggestions'));
      final repo = FinanceMethodsRepository(apiClient: testApiClient(adapter));

      final list = await repo.getGoalSuggestions();

      expect(adapter.requests.single.path, contains('/me/goal-suggestions'));
      expect(list, hasLength(2));
    });

    test('getAlertThresholds() GET đúng path, nguồn system', () async {
      final adapter = RouteAdapter((o) => respondFixture('alert_thresholds'));
      final repo = FinanceMethodsRepository(apiClient: testApiClient(adapter));

      final t = await repo.getAlertThresholds();

      expect(adapter.requests.single.path, contains('/me/alert-thresholds'));
      expect(t.source, 'system');
      expect(t.personal, isNull);
    });

    test('setAlertThresholds() PUT đúng path và body', () async {
      final adapter = RouteAdapter((o) => respondFixture('alert_thresholds_personal'));
      final repo = FinanceMethodsRepository(apiClient: testApiClient(adapter));

      final t = await repo.setAlertThresholds(t1Pct: 60, t2Pct: 85);

      final req = adapter.requests.single;
      expect(req.method, 'PUT');
      expect(req.data, {'t1Pct': 60, 't2Pct': 85});
      expect(t.source, 'personal');
    });

    test('clearAlertThresholds() gọi DELETE rồi GET lại để lấy trạng thái mới', () async {
      final adapter = RouteAdapter((o) {
        if (o.method == 'DELETE') return respondJson({'success': true, 'data': null});
        return respondFixture('alert_thresholds');
      });
      final repo = FinanceMethodsRepository(apiClient: testApiClient(adapter));

      final t = await repo.clearAlertThresholds();

      expect(adapter.requests, hasLength(2));
      expect(adapter.requests[0].method, 'DELETE');
      expect(adapter.requests[1].method, 'GET');
      expect(t.source, 'system');
    });

    test('getJars() GET đúng path, parse level/allocatedCents', () async {
      final adapter = RouteAdapter((o) => respondFixture('finance_jars'));
      final repo = FinanceMethodsRepository(apiClient: testApiClient(adapter));

      final sets = await repo.getJars();

      expect(adapter.requests.single.path, contains('/me/jars'));
      expect(sets, hasLength(1));
      expect(sets.single.jars.firstWhere((j) => j.key == 'play_pct').level, 'over');
    });

    test('getSpendable() GET đúng path, spendableCents null khi chưa khai thu nhập', () async {
      final adapter = RouteAdapter((o) => respondFixture('finance_spendable_no_income'));
      final repo = FinanceMethodsRepository(apiClient: testApiClient(adapter));

      final s = await repo.getSpendable();

      expect(adapter.requests.single.path, contains('/me/spendable'));
      expect(s.incomeCents, isNull);
      expect(s.spendableCents, isNull);
    });
  });
}
