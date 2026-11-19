import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/forecast/presentation/screens/f3_cashflow_forecast_screen.dart';
import '../../fixtures/fixture.dart';

Future<void> _pump(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(RouteAdapter((_) => respondFixture('cashflow'))))],
    child: const MaterialApp(home: F3CashflowForecastScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [390.0, 360.0, 320.0]) {
    testWidgets('F3 thẻ tóm tắt không tràn ở ${width.toInt()}dp; "Thấp nhất dự kiến" có số tiền một dòng và ngày ở dòng riêng', (tester) async {
      await _pump(tester, width);

      expect(tester.takeException(), isNull, reason: 'RenderFlex overflow ở màn dự báo dòng tiền');
      expect(find.text('Thấp nhất dự kiến'), findsOneWidget);
      expect(find.textContaining('Ngày '), findsOneWidget);
      // Số tiền không còn dính kèm "(dd/MM)" cùng một chuỗi
      expect(find.textContaining('₫ ('), findsNothing);
    });
  }

  testWidgets('F3 biểu đồ chỉ có tooltip cho đường số dư dự kiến', (tester) async {
    await _pump(tester, 390);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final data = chart.data;
    // 3 đường: hai dải mờ (barWidth 0) và đường số dư dự kiến
    expect(data.lineBarsData.length, 3);
    final indicators = data.lineTouchData.getTouchedSpotIndicator(data.lineBarsData[0], [0]);
    expect(indicators.single, isNull, reason: 'dải mờ không có chỉ báo chạm');
    final main = data.lineTouchData.getTouchedSpotIndicator(data.lineBarsData[2], [0]);
    expect(main.single, isNotNull);
  });

  testWidgets('F3 có ô Thu/Chi dự kiến tính từ events + chú thích nét đứt, và chế độ tối không tràn', (tester) async {
    GlassColors.dark = true;
    addTearDown(() => GlassColors.dark = false);
    await _pump(tester, 360);

    expect(tester.takeException(), isNull);
    expect(find.text('Thu dự kiến'), findsOneWidget);
    expect(find.text('Chi dự kiến'), findsOneWidget);
    expect(find.textContaining('Dự báo AI từ'), findsOneWidget);
    expect(find.text('Mô phỏng áp lực dòng tiền'), findsOneWidget);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData[2].dashArray, isNotNull);
  });
}
