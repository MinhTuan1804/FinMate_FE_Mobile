import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/analytics/presentation/screens/spending_anomalies_screen.dart';
import '../../fixtures/fixture.dart';

RouteAdapter _adapter({bool anomaliesFail = false}) => RouteAdapter((o) {
      if (o.path.contains('/alerts')) return respondFixture('forecast_alerts');
      if (o.path.contains('/anomalies') && o.path.contains('/feedback')) return respondFixture('forecast_anomaly_feedback');
      if (o.path.contains('/anomalies')) {
        if (anomaliesFail) throwNetworkDown(o);
        return respondFixture('forecast_anomalies');
      }
      return respondFixture('cashflow');
    });

Future<void> _pump(WidgetTester tester, RouteAdapter adapter) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: const MaterialApp(home: SpendingAnomaliesScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hiện khoản bất thường và cảnh báo từ API', (tester) async {
    await _pump(tester, _adapter());

    expect(find.text('Phát hiện 1 bất thường'), findsOneWidget);
    expect(find.text('Chi tiêu tại Nhà hàng ABC cao bất thường'), findsOneWidget);
    expect(find.text('Đã phản hồi: Nhập sai'), findsOneWidget);
    expect(find.text('Số dư sắp xuống dưới mức bạn đặt'), findsOneWidget);
  });

  testWidgets('gửi phản hồi bất thường gọi endpoint feedback', (tester) async {
    final adapter = _adapter();
    await _pump(tester, adapter);

    await tester.tap(find.widgetWithText(ActionChip, 'Bình thường'));
    await tester.pumpAndSettle();

    expect(adapter.to('/anomalies/an-1/feedback'), hasLength(1));
  });

  testWidgets('lỗi tải bất thường hiện thông điệp và nút Thử lại', (tester) async {
    await _pump(tester, _adapter(anomaliesFail: true));

    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Không có kết nối mạng. Vui lòng kiểm tra lại đường truyền.'), findsOneWidget);
  });
}
