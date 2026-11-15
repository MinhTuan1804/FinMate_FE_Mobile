import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/finance_methods/presentation/screens/b6_jar_detail_screen.dart';
import '../../fixtures/fixture.dart';

RouteAdapter _adapter({String budgetsFixture = 'budgets', String transactionsFixture = 'transactions'}) {
  return RouteAdapter((o) {
    if (o.path.contains('/me/jars')) return respondFixture('finance_jars');
    if (o.path.contains('/categories')) return respondFixture('categories');
    if (o.path.contains('/budgets')) return respondFixture(budgetsFixture);
    if (o.path.contains('/transactions')) return respondFixture(transactionsFixture);
    return respondFixture('finance_jars');
  });
}

Future<void> _pump(WidgetTester tester, RouteAdapter adapter, {String userMethodId = 'um-2', String jarKey = 'necessities_pct'}) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: MaterialApp(home: JarDetailScreen(userMethodId: userMethodId, jarKey: jarKey)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('JarDetailScreen (B6)', () {
    testWidgets('hiện breadcrumb, hero ngân sách và danh mục liên kết của hũ', (tester) async {
      await _pump(tester, _adapter());

      expect(find.text('Thiết yếu'), findsWidgets);
      expect(find.text('55% THU NHẬP'), findsOneWidget);
      expect(find.textContaining('ngày tới'), findsOneWidget);
      expect(find.textContaining('Tháng'), findsOneWidget);
    });

    testWidgets('không tìm thấy hũ (sai userMethodId/jarKey) thì báo rõ', (tester) async {
      await _pump(tester, _adapter(), userMethodId: 'um-missing', jarKey: 'missing');

      expect(find.text('Không tìm thấy hũ này.'), findsOneWidget);
    });
  });
}
