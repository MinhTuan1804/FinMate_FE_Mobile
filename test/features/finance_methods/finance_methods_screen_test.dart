import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/finance_methods/presentation/screens/finance_methods_screen.dart';
import '../../fixtures/fixture.dart';

/// Adapter mặc định: catalog + chưa có cách nào đang dùng + chưa có gợi ý (404) + ngưỡng hệ thống + có thu nhập.
RouteAdapter _adapter({
  String catalogFixture = 'finance_methods_catalog',
  String myMethodsFixture = 'my_methods_empty',
  String? latestRecommendationFixture,
  String generateRecommendationFixture = 'finance_recommendation',
  String skipRecommendationFixture = 'finance_recommendation_skipped',
  String chooseMethodFixture = 'my_method_chosen',
  String updateParamsFixture = 'my_method_params_updated',
  String thresholdsFixture = 'alert_thresholds',
  String setThresholdsFixture = 'alert_thresholds_personal',
  String jarsFixture = 'finance_jars',
  String spendableFixture = 'finance_spendable',
  String goalSuggestionsFixture = 'goal_suggestions',
}) {
  return RouteAdapter((o) {
    if (o.path.contains('/recommendations/latest')) {
      return latestRecommendationFixture == null
          ? respondFixture('finance_recommendation_not_found', status: 404)
          : respondFixture(latestRecommendationFixture);
    }
    if (o.path.contains('/skip')) return respondFixture(skipRecommendationFixture);
    if (o.path.contains('/recommendations') && o.method == 'POST') return respondFixture(generateRecommendationFixture);
    if (o.path.contains('/finance-methods') && o.method == 'GET') return respondFixture(catalogFixture);
    if (o.path.contains('/me/methods') && o.method == 'POST') return respondFixture(chooseMethodFixture);
    if (o.path.contains('/params')) return respondFixture(updateParamsFixture);
    if (o.path.contains('/me/methods/') && o.method == 'DELETE') return respondJson({'success': true, 'data': null});
    if (o.path.contains('/me/methods') && o.method == 'GET') return respondFixture(myMethodsFixture);
    if (o.path.contains('/alert-thresholds') && o.method == 'PUT') return respondFixture(setThresholdsFixture);
    if (o.path.contains('/alert-thresholds') && o.method == 'DELETE') return respondJson({'success': true, 'data': null});
    if (o.path.contains('/alert-thresholds')) return respondFixture(thresholdsFixture);
    if (o.path.contains('/me/jars')) return respondFixture(jarsFixture);
    if (o.path.contains('/me/spendable')) return respondFixture(spendableFixture);
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
    child: const MaterialApp(home: FinanceMethodsScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('FinanceMethodsScreen', () {
    testWidgets('hiện catalog, chưa có cách đang dùng, chưa có gợi ý, ngưỡng hệ thống, tiền khả dụng, hũ, mẫu mục tiêu', (tester) async {
      await _pump(tester, _adapter());

      expect(find.byKey(const ValueKey('method-catalog-category_budget')), findsOneWidget);
      expect(find.byKey(const ValueKey('method-choose-primary-category_budget')), findsOneWidget);
      expect(find.byKey(const ValueKey('method-choose-supporting-category_budget')), findsNothing);
      expect(find.byKey(const ValueKey('method-choose-supporting-debt_repayment')), findsOneWidget);
      expect(find.byKey(const ValueKey('method-choose-primary-debt_repayment')), findsNothing);

      expect(find.text('Chưa dùng cách quản lý nào.'), findsOneWidget);
      expect(find.text('Chưa có gợi ý nào.'), findsOneWidget);

      expect(find.byKey(const ValueKey('threshold-effective')), findsOneWidget);
      expect(find.textContaining('T1=70% · T2=90%'), findsWidgets);

      expect(find.byKey(const ValueKey('spendable-amount')), findsOneWidget);
      expect(find.textContaining('10.000.000'), findsOneWidget);

      expect(find.byKey(const ValueKey('jar-set-um-2')), findsOneWidget);
      expect(find.text('Vượt hạn mức'), findsOneWidget);

      expect(find.byKey(const ValueKey('goal-suggestion-emergency_fund')), findsOneWidget);
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

    testWidgets('chọn một cách từ catalog: cách đó xuất hiện trong "Cách tôi đang dùng"', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('method-choose-primary-category_budget')));
      await tester.pumpAndSettle();

      final chooseReq = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.endsWith('/me/methods'));
      expect(chooseReq.data, {'methodCode': 'category_budget', 'role': 'primary', 'recommendationId': null});
      expect(find.text('Đã chọn cách quản lý.'), findsOneWidget);
    });

    testWidgets('chỉnh tham số: mở hộp thoại, lưu thì PATCH đúng body', (tester) async {
      final adapter = _adapter(myMethodsFixture: 'my_methods');
      await _pump(tester, adapter);

      expect(find.byKey(const ValueKey('my-method-um-1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('my-method-edit-params-um-1')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('param-field-t1_pct')), '60');
      await tester.tap(find.byKey(const ValueKey('param-dialog-save')));
      await tester.pumpAndSettle();

      final patchReq = adapter.requests.firstWhere((r) => r.method == 'PATCH');
      expect(patchReq.path, contains('/me/methods/um-1/params'));
      expect((patchReq.data['params'] as Map)['t1_pct'], 60);
    });

    testWidgets('kết thúc một cách đang dùng: gửi DELETE và mục biến mất khỏi danh sách', (tester) async {
      final adapter = _adapter(myMethodsFixture: 'my_methods');
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('my-method-end-um-1')));
      await tester.pumpAndSettle();

      final deleteReq = adapter.requests.firstWhere((r) => r.method == 'DELETE' && r.path.contains('/me/methods/'));
      expect(deleteReq.path, contains('/me/methods/um-1'));
      expect(find.byKey(const ValueKey('my-method-um-1')), findsNothing);
    });

    testWidgets('đặt ngưỡng cá nhân: gửi PUT đúng body, hiện nguồn personal', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.enterText(find.byKey(const ValueKey('threshold-t1-input')), '60');
      await tester.enterText(find.byKey(const ValueKey('threshold-t2-input')), '85');
      await tester.tap(find.byKey(const ValueKey('threshold-save')));
      await tester.pumpAndSettle();

      final putReq = adapter.requests.firstWhere((r) => r.method == 'PUT');
      expect(putReq.data, {'t1Pct': 60, 't2Pct': 85});
      expect(find.textContaining('nguồn: personal'), findsOneWidget);
    });

    testWidgets('xóa ngưỡng cá nhân: gửi DELETE rồi tự tải lại GET', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('threshold-clear')));
      await tester.pumpAndSettle();

      final deleteReq = adapter.requests.firstWhere((r) => r.method == 'DELETE' && r.path.contains('/alert-thresholds'));
      expect(deleteReq, isNotNull);
      expect(find.textContaining('nguồn: system'), findsOneWidget);
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
