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

    testWidgets('cách không có hũ (50/30/20): hiện khối tiền khả dụng theo homeLayout, không còn dòng "không có khối hũ"', (tester) async {
      await _pump(tester, _adapter(myMethodsFixture: 'my_methods', jarsFixture: 'finance_jars_empty'));

      expect(find.byKey(const ValueKey('method-block-spendable')), findsOneWidget);
      expect(find.text('TIỀN KHẢ DỤNG THÁNG NÀY'), findsOneWidget);
      expect(find.textContaining('không có khối hũ'), findsNothing);
      expect(find.byKey(const ValueKey('switch-method')), findsOneWidget);
    });

    // Dựng cách đang dùng từ fixture, chỉnh method/effective theo từng ca.
    RouteAdapter customMethodAdapter(Map<String, dynamic> Function(Map<String, dynamic> um) change) {
      final list = (fixtureData('my_methods') as List).map((e) => change(Map<String, dynamic>.from(e as Map))).toList();
      return RouteAdapter((o) {
        if (o.path.contains('/me/methods') && o.method == 'GET') return respondJson({'success': true, 'data': list});
        return _adapter(jarsFixture: 'finance_jars_empty').handler(o);
      });
    }

    Map<String, dynamic> param(String key, String label, int def) => {'key': key, 'label': label, 'type': 'percent', 'default': def, 'min': 0, 'max': 100, 'userEditable': true};

    testWidgets('khối params dạng allocation: hiện thanh tỷ lệ, tổng và cảnh báo khi chưa đủ 100%, kèm khối mục tiêu', (tester) async {
      final adapter = customMethodAdapter((um) {
        final method = Map<String, dynamic>.from(um['method'] as Map);
        method['params'] = [param('needs_pct', 'Nhu cầu', 50), param('wants_pct', 'Mong muốn', 30), param('goals_pct', 'Mục tiêu', 10)];
        method['homeLayout'] = [
          {'type': 'params', 'title': 'Chia thu nhập', 'keys': ['needs_pct', 'wants_pct', 'goals_pct'], 'display': 'allocation'},
          {'type': 'goals'},
        ];
        um['method'] = method;
        um['effective'] = {'needs_pct': 50, 'wants_pct': 30, 'goals_pct': 10};
        return um;
      });
      await _pump(tester, adapter);

      expect(find.text('Chia thu nhập'), findsOneWidget);
      expect(find.text('Nhu cầu'), findsOneWidget);
      expect(find.text('90% · còn 10% chưa phân bổ'), findsOneWidget);
      expect(find.byKey(const ValueKey('method-block-goals')), findsOneWidget);
    });

    testWidgets('không khai báo homeLayout: dùng bố cục mặc định của BE, tham số tự nhóm theo ý nghĩa; cách bị tắt có cảnh báo', (tester) async {
      final adapter = customMethodAdapter((um) {
        final method = Map<String, dynamic>.from(um['method'] as Map);
        method['params'] = [
          param('t1_pct', 'Ngưỡng nhắc nhẹ', 70),
          param('t2_pct', 'Ngưỡng cảnh báo mạnh', 90),
          {'key': 'forecast_minute', 'label': 'Giờ nhắc dự báo', 'type': 'minutes', 'default': 1320, 'min': 0, 'max': 1439, 'userEditable': true},
        ];
        method.remove('homeLayout');
        method['available'] = false;
        um['method'] = method;
        um['effective'] = {'t1_pct': 70, 't2_pct': 90, 'forecast_minute': 1320};
        return um;
      });
      await _pump(tester, adapter);

      expect(find.byKey(const ValueKey('method-block-spendable')), findsOneWidget);
      expect(find.byKey(const ValueKey('method-block-goals')), findsOneWidget);
      expect(find.text('Ngưỡng cảnh báo'), findsOneWidget);
      expect(find.text('Dự báo hằng ngày'), findsOneWidget);
      expect(find.text('22:00'), findsOneWidget);
      expect(find.byKey(const ValueKey('method-unavailable-um-1')), findsOneWidget);
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

    testWidgets('khung quản lý: không còn chuỗi key=value; giờ nhập HH:mm gửi BE bằng phút; tổng tỷ lệ cảnh báo; lỗi BE hiện trong hộp', (tester) async {
      final list = (fixtureData('my_methods') as List).map((e) {
        final um = Map<String, dynamic>.from(e as Map);
        final method = Map<String, dynamic>.from(um['method'] as Map);
        Map<String, dynamic> pr(String k, String l, String t, int d, int mn, int mx) =>
            {'key': k, 'label': l, 'type': t, 'default': d, 'min': mn, 'max': mx, 'userEditable': true};
        method['params'] = [
          pr('forecast_minute', 'Giờ nhắc dự báo hằng ngày', 'minutes', 1320, 0, 1439),
          pr('needs_pct', 'Nhu cầu', 'percent', 50, 0, 100),
          pr('wants_pct', 'Mong muốn', 'percent', 30, 0, 100),
        ];
        um['method'] = method;
        um['effective'] = {'forecast_minute': 1320, 'needs_pct': 50, 'wants_pct': 30};
        return um;
      }).toList();
      final adapter = RouteAdapter((o) {
        if (o.method == 'PATCH') {
          return respondJson({'success': false, 'data': null, 'error': {'code': 'FINANCE_METHOD_PARAM_INVALID', 'message': 'Ngưỡng nhắc nhẹ (T1) phải nhỏ hơn T2.'}, 'meta': null}, status: 422);
        }
        if (o.path.contains('/me/methods') && o.method == 'GET') return respondJson({'success': true, 'data': list});
        return _adapter(jarsFixture: 'finance_jars_empty').handler(o);
      });
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('open-edit-methods')));
      await tester.pumpAndSettle();
      expect(find.textContaining('forecast_minute='), findsNothing);
      expect(find.text('22:00'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('my-method-edit-params-um-1')));
      await tester.pumpAndSettle();
      expect(find.text('80% · chưa đủ 100%'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('param-field-forecast_minute')), '21:30');
      await tester.tap(find.byKey(const ValueKey('param-dialog-save')));
      await tester.pumpAndSettle();

      final patch = adapter.requests.firstWhere((r) => r.method == 'PATCH');
      expect((patch.data['params'] as Map)['forecast_minute'], 1290);
      expect(find.byKey(const ValueKey('param-server-error')), findsOneWidget);
      expect(find.textContaining('phải nhỏ hơn T2'), findsOneWidget);
    });

    testWidgets('kết thúc một cách đang dùng: gửi DELETE và mục biến mất khỏi sheet', (tester) async {
      final adapter = _adapter(myMethodsFixture: 'my_methods');
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('open-edit-methods')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('my-method-end-um-1')));
      await tester.pumpAndSettle();
      expect(adapter.requests.any((r) => r.method == 'DELETE'), isFalse); // chưa xác nhận thì chưa xóa
      await tester.tap(find.byKey(const ValueKey('my-method-end-confirm')));
      await tester.pumpAndSettle();

      final deleteReq = adapter.requests.firstWhere((r) => r.method == 'DELETE' && r.path.contains('/me/methods/'));
      expect(deleteReq.path, contains('/me/methods/um-1'));
      expect(find.byKey(const ValueKey('my-method-um-1')), findsNothing);
    });
  });
}
