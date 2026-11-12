import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/finance_methods/presentation/screens/b7_alert_thresholds_screen.dart';
import '../../fixtures/fixture.dart';

/// Adapter mặc định: ngưỡng hệ thống (chưa có ngưỡng cá nhân).
RouteAdapter _adapter({
  String thresholdsFixture = 'alert_thresholds',
  String setThresholdsFixture = 'alert_thresholds_personal',
}) {
  return RouteAdapter((o) {
    if (o.path.contains('/alert-thresholds') && o.method == 'PUT') return respondFixture(setThresholdsFixture);
    if (o.path.contains('/alert-thresholds') && o.method == 'DELETE') return respondJson({'success': true, 'data': null});
    if (o.path.contains('/alert-thresholds')) return respondFixture(thresholdsFixture);
    return respondFixture(thresholdsFixture);
  });
}

Future<void> _pump(WidgetTester tester, RouteAdapter adapter) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: const MaterialApp(home: AlertThresholdsScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('AlertThresholdsScreen (B7)', () {
    testWidgets('hiện ngưỡng hệ thống', (tester) async {
      await _pump(tester, _adapter());

      expect(find.byKey(const ValueKey('threshold-effective')), findsOneWidget);
      expect(find.textContaining('T1=70% · T2=90%'), findsWidgets);
    });

    testWidgets('đặt ngưỡng cá nhân: gửi PUT đúng body, hiện nguồn personal', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.drag(find.byKey(const ValueKey('threshold-t1-input')), const Offset(50, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('threshold-save')));
      await tester.pumpAndSettle();

      final putReq = adapter.requests.firstWhere((r) => r.method == 'PUT');
      expect(putReq.path, contains('/alert-thresholds'));
      expect(find.textContaining('nguồn: personal'), findsOneWidget);
    });

    testWidgets('xóa ngưỡng cá nhân: gửi DELETE rồi tự tải lại GET', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.tap(find.text('Mặc định'));
      await tester.pumpAndSettle();

      final deleteReq = adapter.requests.firstWhere((r) => r.method == 'DELETE' && r.path.contains('/alert-thresholds'));
      expect(deleteReq, isNotNull);
      expect(find.textContaining('nguồn: system'), findsOneWidget);
    });
  });
}
