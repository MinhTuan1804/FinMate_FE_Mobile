import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/analytics/presentation/screens/f4_alerts_screen.dart';
import '../../fixtures/fixture.dart';

ResponseBody _route(RequestOptions o) {
  if (o.path.contains('/alerts')) return respondFixture('forecast_alerts');
  if (o.path.contains('/anomalies')) return respondFixture('forecast_anomalies');
  return respondFixture('categories');
}

Future<void> _pump(WidgetTester tester, double width, {bool dark = false}) async {
  GlassColors.dark = dark;
  addTearDown(() => GlassColors.dark = false);
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(RouteAdapter(_route)))],
    child: const MaterialApp(home: F4AlertsScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));
  for (final width in [360.0, 390.0]) {
    testWidgets('F4 không tràn ở ${width.toInt()}dp, có đủ khối chính', (tester) async {
      await _pump(tester, width);
      final ex = tester.takeException(); if (ex is FlutterError) debugPrint(ex.toStringDeep()); expect(ex, isNull);
      expect(find.text('Cảnh báo & Bất thường'), findsOneWidget);
      expect(find.text('Cảnh báo vượt ngân sách'), findsOneWidget);
      expect(find.text('Bạn muốn nhận cảnh báo sớm hơn?'), findsOneWidget);
      // BE không có phản hồi "Hữu ích" và không có màn chỉnh hạn mức -> ẩn
      expect(find.text('Hữu ích'), findsNothing);
      expect(find.textContaining('Điều chỉnh hạn mức'), findsNothing);
    });
  }

  testWidgets('F4 chế độ tối: chữ trên nền ink dùng onInk, không dùng trắng', (tester) async {
    await _pump(tester, 360, dark: true);
    expect(tester.takeException(), isNull);
    final selected = tester.widget<Text>(find.textContaining('Tất cả ('));
    expect(selected.style!.color, GlassColors.onInk);
    expect(GlassColors.onInk.computeLuminance(), lessThan(0.2));
    expect(GlassColors.ink.computeLuminance(), greaterThan(0.3));
  });
}
