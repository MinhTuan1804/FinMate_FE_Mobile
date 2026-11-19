import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/forecast/presentation/screens/f5_purchase_check_screen.dart';
import '../../fixtures/fixture.dart';

Map<String, dynamic> _check({String? safeDate}) => {
      'success': true,
      'data': {
        'status': 'assessable',
        'verdict': 'consider',
        'summary': 'Khoản mua này làm dòng tiền hơi căng.',
        'amountCents': 6500000,
        'purchaseDate': '2026-11-17',
        'item': 'Tai nghe',
        'maxAffordableCents': 4000000,
        'earliestSafeDate': safeDate,
        'budget': {'status': 'over', 'name': 'Mua sắm', 'limitCents': 8000000, 'projectedAfterCents': 13700000},
        'plan': {'status': 'over', 'spendableAfterCents': -100000},
        'lines': [],
      },
      'error': null,
      'meta': null,
    };

late RouteAdapter adapter;

Future<void> _pump(WidgetTester tester, double width, {String? safeDate, bool dark = false}) async {
  GlassColors.dark = dark;
  addTearDown(() => GlassColors.dark = false);
  tester.view.physicalSize = Size(width, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  adapter = RouteAdapter((o) {
    if (o.path.contains('purchase-check')) return respondJson(_check(safeDate: safeDate));
    if (o.path.contains('/categories')) return respondFixture('categories');
    return respondFixture('accounts');
  });
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: const MaterialApp(home: F5PurchaseCheckScreen()),
  ));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(1), '6500000');
  await tester.tap(find.text('Kiểm tra ngay'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));
  for (final width in [360.0, 390.0]) {
    testWidgets('F5 không tràn ở ${width.toInt()}dp; nút lập kế hoạch hiện khi có ngày an toàn', (tester) async {
      await _pump(tester, width, safeDate: '2026-12-05');
      expect(tester.takeException(), isNull);
      expect(find.text('NÊN CÂN NHẮC'), findsOneWidget);
      expect(find.text('Đề xuất thông minh từ AI'), findsOneWidget);
      expect(find.text('Lập kế hoạch mua sau ngày 05/12'), findsOneWidget);
      expect(find.text('Vẫn mua và trừ vào ngân sách'), findsOneWidget);
      expect(find.textContaining('/100'), findsNothing);
    });
  }

  testWidgets('F5 ẩn nút lập kế hoạch khi BE không trả ngày an toàn', (tester) async {
    await _pump(tester, 360);
    expect(find.textContaining('Lập kế hoạch mua sau ngày'), findsNothing);
  });

  testWidgets('F5 bấm lập kế hoạch chạy lại kiểm tra với ngày đó', (tester) async {
    await _pump(tester, 360, safeDate: '2026-12-05');
    final btn = find.text('Lập kế hoạch mua sau ngày 05/12');
    await tester.ensureVisible(btn);
    await tester.tap(btn);
    await tester.pumpAndSettle();
    final last = adapter.to('purchase-check').last;
    expect((last.data as Map)['purchaseDate'], '2026-12-05');
  });

  testWidgets('F5 chế độ tối: nút ink dùng onInk', (tester) async {
    await _pump(tester, 360, safeDate: '2026-12-05', dark: true);
    expect(tester.takeException(), isNull);
    final b = tester.widget<ElevatedButton>(find.ancestor(of: find.text('Kiểm tra ngay'), matching: find.byType(ElevatedButton)));
    expect(b.style!.foregroundColor!.resolve({}), GlassColors.onInk);
    expect(GlassColors.onInk.computeLuminance(), lessThan(0.2));
  });
}
