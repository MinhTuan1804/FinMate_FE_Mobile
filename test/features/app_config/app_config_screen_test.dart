import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/app_config/presentation/screens/app_config_screen.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import '../../fixtures/fixture.dart';

Future<void> _pump(WidgetTester tester, RouteAdapter adapter) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: const MaterialApp(home: AppConfigScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('AppConfigScreen', () {
    testWidgets('hiện phiên bản, công tắc tính năng và giao diện khi tải xong', (tester) async {
      await _pump(tester, RouteAdapter((o) => respondFixture('app_config')));

      expect(find.text('Phiên bản cấu hình: 3'), findsOneWidget);

      final chatAiSwitch =
          tester.widget<SwitchListTile>(find.byKey(const ValueKey('app-config-feature-chatAi')));
      expect(chatAiSwitch.value, isTrue);

      final groupsSwitch =
          tester.widget<SwitchListTile>(find.byKey(const ValueKey('app-config-feature-groups')));
      expect(groupsSwitch.value, isFalse);

      expect(find.text('Màu chính: #1E88E5'), findsOneWidget);
    });

    testWidgets('bảo trì bật thì hiện tiêu đề và nội dung thông báo', (tester) async {
      await _pump(tester, RouteAdapter((o) => respondFixture('app_config_maintenance')));

      final maintenanceSwitch =
          tester.widget<SwitchListTile>(find.byKey(const ValueKey('app-config-maintenance-enabled')));
      expect(maintenanceSwitch.value, isTrue);
      expect(find.text('Đang bảo trì'), findsWidgets);
      expect(find.text('Hệ thống đang nâng cấp, quay lại sau 30 phút.'), findsOneWidget);
    });

    testWidgets('bấm nút refresh gọi lại API', (tester) async {
      var callCount = 0;
      final adapter = RouteAdapter((o) {
        callCount++;
        return respondFixture('app_config');
      });
      await _pump(tester, adapter);
      expect(callCount, 1);

      await tester.tap(find.byKey(const ValueKey('app-config-refresh')));
      await tester.pumpAndSettle();

      expect(callCount, 2);
    });
  });
}
