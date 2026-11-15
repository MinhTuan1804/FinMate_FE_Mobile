import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/analytics/domain/report_models.dart';
import 'package:finmate/features/analytics/presentation/screens/ai_insights_screen.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import '../../fixtures/fixture.dart';

const _unread = {
  'id': 'i1',
  'insightType': 'vs_last_month',
  'title': 'Chi tiêu tháng này tăng',
  'body': 'Bạn đã chi nhiều hơn tháng trước 12%.',
  'categoryId': null,
  'categoryName': null,
  'amountCents': 1500000,
  'periodStart': '2026-11-01',
  'periodEnd': '2026-11-30',
  'isRead': false,
  'createdAt': '2026-11-10T08:00:00Z',
};
final _read = {..._unread, 'id': 'i2', 'title': 'Phát hiện khoản định kỳ', 'insightType': 'recurring_detected', 'isRead': true};

Map<String, dynamic> _ok(Object data) => {'success': true, 'data': data, 'error': null, 'meta': null};

Future<void> _pump(WidgetTester tester, RouteAdapter adapter) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      apiClientProvider.overrideWithValue(testApiClient(adapter)),
    ],
    child: const MaterialApp(home: AiInsightsScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('SpendingInsight.fromJson đọc số tiền nguyên và cờ đã đọc', () {
    final i = SpendingInsight.fromJson(_unread);
    expect(i.amountCents, BigInt.from(1500000));
    expect(i.isRead, isFalse);
    expect(SpendingInsight.fromJson({..._unread, 'amountCents': null}).amountCents, isNull);
  });

  testWidgets('hiện nhận xét từ API và đánh dấu đã đọc gọi PATCH', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.method == 'PATCH') return respondJson({}, status: 204);
      return respondJson(_ok([_unread, _read]));
    });
    await _pump(tester, adapter);

    expect(find.text('1 nhận xét mới'), findsOneWidget);
    expect(find.text('Chi tiêu tháng này tăng'), findsOneWidget);
    expect(find.text('1.500.000 ₫'), findsNWidgets(2));

    await tester.tap(find.text('Đánh dấu đã đọc'));
    await tester.pumpAndSettle();
    expect(adapter.requests.singleWhere((r) => r.method == 'PATCH').path, '/api/v1/reports/insights/i1/read');
  });

  testWidgets('chưa có nhận xét thì hiện trạng thái rỗng', (tester) async {
    await _pump(tester, RouteAdapter((o) => respondJson(_ok([]))));
    expect(find.textContaining('Chưa có nhận xét nào'), findsOneWidget);
  });

  testWidgets('lỗi tải hiện thông điệp và Thử lại', (tester) async {
    var fail = true;
    final adapter = RouteAdapter((o) {
      if (fail) throwNetworkDown(o);
      return respondJson(_ok([_unread]));
    });
    await _pump(tester, adapter);

    expect(find.text('Thử lại'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiêu tháng này tăng'), findsOneWidget);
  });
}
