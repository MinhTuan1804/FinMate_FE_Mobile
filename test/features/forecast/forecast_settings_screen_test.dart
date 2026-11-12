import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/forecast/presentation/screens/forecast_settings_screen.dart';
import '../../fixtures/fixture.dart';

/// Adapter mặc định: GET settings -> forecast_settings.json, PUT settings -> forecast_settings_updated.json,
/// PATCH .../forecast-inclusion -> forecast_account_inclusion.json, PATCH .../forecast-exclusion -> transaction_forecast_exclusion.json.
RouteAdapter _adapter({
  String settingsFixture = 'forecast_settings',
  String updateFixture = 'forecast_settings_updated',
  String accountInclusionFixture = 'forecast_account_inclusion',
  String exclusionFixture = 'transaction_forecast_exclusion',
}) {
  return RouteAdapter((o) {
    if (o.path.contains('/me/forecast-settings') && o.method == 'PUT') return respondFixture(updateFixture);
    if (o.path.contains('/me/forecast-settings')) return respondFixture(settingsFixture);
    if (o.path.contains('/forecast-inclusion')) return respondFixture(accountInclusionFixture);
    if (o.path.contains('/forecast-exclusion')) return respondFixture(exclusionFixture);
    return respondFixture(settingsFixture);
  });
}

Future<void> _pump(WidgetTester tester, RouteAdapter adapter) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: const MaterialApp(home: ForecastSettingsScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('ForecastSettingsScreen', () {
    testWidgets('hiện cài đặt hiện tại: dự phòng mặc định, ngưỡng số dư thấp, giờ yên lặng mặc định, danh sách ví', (tester) async {
      await _pump(tester, _adapter());

      expect(find.text('Cài đặt dự báo'), findsOneWidget);
      expect(find.textContaining('Dự phòng đang áp dụng: 2.000.000 ₫'), findsOneWidget);

      final useDefaultReserve = tester.widget<CheckboxListTile>(find.byKey(const ValueKey('forecast-settings-use-default-reserve')));
      expect(useDefaultReserve.value, isTrue);
      expect(find.byKey(const ValueKey('forecast-settings-reserve-amount')), findsNothing);

      final lowBalanceEnabled = tester.widget<SwitchListTile>(find.byKey(const ValueKey('forecast-settings-low-balance-enabled')));
      expect(lowBalanceEnabled.value, isTrue);
      expect(find.byKey(const ValueKey('forecast-settings-low-balance-amount')), findsOneWidget);

      final useDefaultQuietHours =
          tester.widget<CheckboxListTile>(find.byKey(const ValueKey('forecast-settings-use-default-quiet-hours')));
      expect(useDefaultQuietHours.value, isTrue);
      expect(find.textContaining('22:00–07:00'), findsOneWidget);

      expect(find.text('Ví chính'), findsOneWidget);
      expect(find.text('Ví tiết kiệm'), findsOneWidget);
      final acc1 = tester.widget<SwitchListTile>(find.byKey(const ValueKey('forecast-account-switch-acc-1')));
      expect(acc1.value, isTrue);
      final acc2 = tester.widget<SwitchListTile>(find.byKey(const ValueKey('forecast-account-switch-acc-2')));
      expect(acc2.value, isFalse);
    });

    testWidgets('bỏ dùng dự phòng mặc định, nhập số tiền, lưu thì gửi đúng reserveCents', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('forecast-settings-use-default-reserve')));
      await tester.pump();

      expect(find.byKey(const ValueKey('forecast-settings-reserve-amount')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('forecast-settings-reserve-amount')), '3.000.000');
      await tester.tap(find.byKey(const ValueKey('forecast-settings-save')));
      await tester.pumpAndSettle();

      final putReq = adapter.requests.firstWhere((r) => r.method == 'PUT');
      expect(putReq.data, {
        'reserveCents': 3000000,
        'lowBalanceThresholdCents': 500000,
        'quietHoursStart': null,
        'quietHoursEnd': null,
        'forecastAlertsEnabled': true,
      });
      expect(find.text('Đã lưu cài đặt dự báo.'), findsOneWidget);
    });

    testWidgets('tắt cảnh báo số dư thấp thì lưu gửi lowBalanceThresholdCents = null', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('forecast-settings-low-balance-enabled')));
      await tester.pump();
      expect(find.byKey(const ValueKey('forecast-settings-low-balance-amount')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('forecast-settings-save')));
      await tester.pumpAndSettle();

      final putReq = adapter.requests.firstWhere((r) => r.method == 'PUT');
      expect(putReq.data, {
        'reserveCents': null,
        'lowBalanceThresholdCents': null,
        'quietHoursStart': null,
        'quietHoursEnd': null,
        'forecastAlertsEnabled': true,
      });
    });

    testWidgets('tắt cảnh báo dự báo rồi lưu thì gửi forecastAlertsEnabled = false', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('forecast-settings-alerts-enabled')));
      await tester.tap(find.byKey(const ValueKey('forecast-settings-save')));
      await tester.pumpAndSettle();

      final putReq = adapter.requests.firstWhere((r) => r.method == 'PUT');
      expect(putReq.data['forecastAlertsEnabled'], isFalse);
    });

    testWidgets('bật ví đang tắt theo mặc định thì gọi API và cập nhật switch ngay', (tester) async {
      await _pump(tester, _adapter());

      await tester.tap(find.byKey(const ValueKey('forecast-account-switch-acc-2')));
      await tester.pumpAndSettle();

      final acc2 = tester.widget<SwitchListTile>(find.byKey(const ValueKey('forecast-account-switch-acc-2')));
      expect(acc2.value, isTrue);
      // Ví còn lại không bị ảnh hưởng
      final acc1 = tester.widget<SwitchListTile>(find.byKey(const ValueKey('forecast-account-switch-acc-1')));
      expect(acc1.value, isTrue);
    });

    testWidgets('loại một giao dịch khỏi dự báo: nhập ID, chọn lý do, bấm nút thì hiện kết quả', (tester) async {
      await _pump(tester, _adapter());

      await tester.enterText(find.byKey(const ValueKey('exclusion-transaction-id')), 'tx-1');
      await tester.tap(find.byKey(const ValueKey('exclude-transaction-button')));
      await tester.pumpAndSettle();

      expect(find.text('Đã loại khỏi dự báo (Chi một lần).'), findsOneWidget);
    });

    testWidgets('đưa lại một giao dịch vào dự báo thì hiện kết quả đã đưa lại', (tester) async {
      await _pump(tester, _adapter(exclusionFixture: 'transaction_forecast_inclusion'));

      await tester.enterText(find.byKey(const ValueKey('exclusion-transaction-id')), 'tx-1');
      await tester.tap(find.byKey(const ValueKey('include-transaction-button')));
      await tester.pumpAndSettle();

      expect(find.text('Đã đưa lại vào dự báo.'), findsOneWidget);
    });

    testWidgets('lỗi khi tải cài đặt hiện thông điệp và nút Thử lại', (tester) async {
      await _pump(tester, RouteAdapter((o) => throwNetworkDown(o)));

      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
