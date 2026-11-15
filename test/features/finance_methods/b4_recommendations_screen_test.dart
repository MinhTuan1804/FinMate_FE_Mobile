import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/finance_methods/presentation/screens/b4_recommendations_screen.dart';
import '../../fixtures/fixture.dart';

/// Adapter mặc định: catalog + chưa có gợi ý (404) + mẫu mục tiêu.
RouteAdapter _adapter({
  String catalogFixture = 'finance_methods_catalog',
  String? latestRecommendationFixture,
  String generateRecommendationFixture = 'finance_recommendation',
  int generateStatus = 200,
  String skipRecommendationFixture = 'finance_recommendation_skipped',
  String chooseMethodFixture = 'my_method_chosen',
  String goalSuggestionsFixture = 'goal_suggestions',
}) {
  return RouteAdapter((o) {
    if (o.path.contains('/recommendations/latest')) {
      return latestRecommendationFixture == null
          ? respondFixture('finance_recommendation_not_found', status: 404)
          : respondFixture(latestRecommendationFixture);
    }
    if (o.path.contains('/skip')) return respondFixture(skipRecommendationFixture);
    if (o.path.contains('/recommendations') && o.method == 'POST') return respondFixture(generateRecommendationFixture, status: generateStatus);
    if (o.path.contains('/finance-methods') && o.method == 'GET') return respondFixture(catalogFixture);
    if (o.path.contains('/me/methods') && o.method == 'POST') return respondFixture(chooseMethodFixture);
    if (o.path.contains('/goal-suggestions')) return respondFixture(goalSuggestionsFixture);
    return respondFixture(catalogFixture);
  });
}

Future<void> _pump(WidgetTester tester, RouteAdapter adapter) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: const MaterialApp(home: RecommendationsScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('RecommendationsScreen (B4)', () {
    testWidgets('hiện catalog, chưa làm khảo sát (422) nên chưa có gợi ý, mẫu mục tiêu', (tester) async {
      await _pump(tester, _adapter(generateRecommendationFixture: 'finance_recommendation_not_found', generateStatus: 422));

      expect(find.byKey(const ValueKey('method-catalog-category_budget')), findsOneWidget);
      expect(find.byKey(const ValueKey('method-choose-primary-category_budget')), findsOneWidget);
      expect(find.byKey(const ValueKey('method-choose-supporting-category_budget')), findsNothing);
      expect(find.byKey(const ValueKey('method-choose-supporting-debt_repayment')), findsOneWidget);
      expect(find.byKey(const ValueKey('method-choose-primary-debt_repayment')), findsNothing);

      expect(find.text('Chưa có gợi ý nào.'), findsOneWidget);
      expect(find.byKey(const ValueKey('goal-suggestion-emergency_fund')), findsOneWidget);
    });

    testWidgets('chưa có gợi ý (404) nhưng đã có khảo sát: tự tạo và hiện luôn', (tester) async {
      await _pump(tester, _adapter());

      expect(find.byKey(const ValueKey('method-recommendation-result')), findsOneWidget);
      expect(find.text('Chưa có gợi ý nào.'), findsNothing);
    });

    testWidgets('tạo gợi ý mới: hiện cách chính, lý do và nút bỏ qua', (tester) async {
      await _pump(tester, _adapter());

      await tester.tap(find.byKey(const ValueKey('method-generate-recommendation')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('method-recommendation-result')), findsOneWidget);
      expect(find.textContaining('Quy tắc 50/30/20'), findsWidgets);
      expect(find.byKey(const ValueKey('method-skip-recommendation')), findsOneWidget);
    });

    testWidgets('bỏ qua gợi ý: nút bỏ qua biến mất sau khi outcome đổi thành skipped', (tester) async {
      await _pump(tester, _adapter(latestRecommendationFixture: 'finance_recommendation'));

      expect(find.byKey(const ValueKey('method-skip-recommendation')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('method-skip-recommendation')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('method-skip-recommendation')), findsNothing);
    });

    testWidgets('chọn một cách từ catalog: gửi đúng body', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('method-choose-primary-category_budget')));
      await tester.pumpAndSettle();

      final chooseReq = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.endsWith('/me/methods'));
      expect(chooseReq.data, {'methodCode': 'category_budget', 'role': 'primary', 'recommendationId': null});
      expect(find.text('Đã chọn cách quản lý.'), findsOneWidget);
    });

    testWidgets('Áp dụng gợi ý: chọn đúng cách chính AI gợi ý, kèm recommendationId để backend ghi là đã nhận', (tester) async {
      final adapter = _adapter(latestRecommendationFixture: 'finance_recommendation');
      await _pump(tester, adapter);

      expect(find.byKey(const ValueKey('method-apply-recommendation')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('method-apply-recommendation')));
      await tester.pumpAndSettle();

      final chooseReqs = adapter.requests.where((r) => r.method == 'POST' && r.path.endsWith('/me/methods')).toList();
      expect(chooseReqs, hasLength(1));
      expect(chooseReqs.single.data, {'methodCode': 'category_budget', 'role': 'primary', 'recommendationId': 'rec-1'});
      expect(find.text('Đã áp dụng gợi ý.'), findsOneWidget);
    });

    testWidgets('Áp dụng gợi ý có cả cách bổ trợ: chọn cách chính trước rồi cách bổ trợ, cùng recommendationId', (tester) async {
      final rec = Map<String, dynamic>.from(fixtureData('finance_recommendation') as Map);
      final primary = Map<String, dynamic>.from(rec['primary'] as Map);
      final supportMethod = {...Map<String, dynamic>.from(primary['method'] as Map), 'code': 'debt_repayment', 'name': 'Trả nợ trước', 'role': 'supporting'};
      rec['support'] = {'method': supportMethod, 'reason': 'Bạn đang có khoản nợ cần ưu tiên.'};
      final adapter = RouteAdapter((o) {
        if (o.path.contains('/recommendations/latest')) return respondJson({'success': true, 'data': rec});
        return _adapter().handler(o);
      });
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('method-apply-recommendation')));
      await tester.pumpAndSettle();

      final chooseReqs = adapter.requests.where((r) => r.method == 'POST' && r.path.endsWith('/me/methods')).map((r) => r.data).toList();
      expect(chooseReqs, [
        {'methodCode': 'category_budget', 'role': 'primary', 'recommendationId': 'rec-1'},
        {'methodCode': 'debt_repayment', 'role': 'supporting', 'recommendationId': 'rec-1'},
      ]);
    });

    testWidgets('gợi ý đã xử lý (skipped): không còn nút Áp dụng', (tester) async {
      await _pump(tester, _adapter(latestRecommendationFixture: 'finance_recommendation_skipped'));

      expect(find.byKey(const ValueKey('method-apply-recommendation')), findsNothing);
    });

    testWidgets('tạo gợi ý khi chưa làm khảo sát (422) hiện lỗi, không crash', (tester) async {
      await _pump(
        tester,
        RouteAdapter((o) {
          if (o.path.contains('/recommendations') && o.method == 'POST') {
            return respondFixture('finance_recommendation_survey_not_answered', status: 422);
          }
          return _adapter().handler(o);
        }),
      );

      await tester.tap(find.byKey(const ValueKey('method-generate-recommendation')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
