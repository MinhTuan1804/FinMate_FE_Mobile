import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/finance_methods/presentation/screens/b5_my_methods_screen.dart';
import '../../fixtures/fixture.dart';

/// Adapter mặc định: chưa có cách nào đang dùng + tiền khả dụng + hũ.
RouteAdapter _adapter({
  String myMethodsFixture = 'my_methods_empty',
  String updateParamsFixture = 'my_method_params_updated',
  String jarsFixture = 'finance_jars',
  String spendableFixture = 'finance_spendable',
}) {
  return RouteAdapter((o) {
    if (o.path.contains('/params')) return respondFixture(updateParamsFixture);
    if (o.path.contains('/me/methods/') && o.method == 'DELETE') return respondJson({'success': true, 'data': null});
    if (o.path.contains('/me/methods') && o.method == 'GET') return respondFixture(myMethodsFixture);
    if (o.path.contains('/me/jars')) return respondFixture(jarsFixture);
    if (o.path.contains('/me/spendable')) return respondFixture(spendableFixture);
    return respondFixture(myMethodsFixture);
  });
}

Future<void> _pump(WidgetTester tester, RouteAdapter adapter) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: const MaterialApp(home: MyMethodsScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('MyMethodsScreen (B5)', () {
    testWidgets('chưa có cách đang dùng: hiện trạng thái trống, vẫn thấy hũ của phương pháp khác', (tester) async {
      await _pump(tester, _adapter());

      expect(find.text('Chưa dùng cách quản lý nào.'), findsOneWidget);

      expect(find.byKey(const ValueKey('jar-set-um-2')), findsOneWidget);
      expect(find.text('Vượt hạn mức'), findsOneWidget);
    });

    testWidgets('chỉnh tham số: mở sheet từ icon bút, lưu thì PATCH đúng body', (tester) async {
      final adapter = _adapter(myMethodsFixture: 'my_methods');
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('open-edit-methods')));
      await tester.pumpAndSettle();

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

    testWidgets('kết thúc một cách đang dùng: gửi DELETE và mục biến mất khỏi sheet', (tester) async {
      final adapter = _adapter(myMethodsFixture: 'my_methods');
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('open-edit-methods')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('my-method-end-um-1')));
      await tester.pumpAndSettle();

      final deleteReq = adapter.requests.firstWhere((r) => r.method == 'DELETE' && r.path.contains('/me/methods/'));
      expect(deleteReq.path, contains('/me/methods/um-1'));
      expect(find.byKey(const ValueKey('my-method-um-1')), findsNothing);
    });
  });
}
