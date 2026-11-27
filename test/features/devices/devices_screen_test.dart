import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/core/network/token_storage.dart';
import 'package:finmate/features/devices/presentation/screens/devices_screen.dart';
import '../../fixtures/fixture.dart';

RouteAdapter _adapter() {
  return RouteAdapter((o) => respondJson({'success': true, 'data': null}));
}

Future<void> _pump(WidgetTester tester, RouteAdapter adapter) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(testApiClient(adapter)),
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
    ],
    child: const MaterialApp(home: DevicesScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('DevicesScreen', () {
    testWidgets('không còn ô token thử và nút đăng ký/gỡ đăng ký', (tester) async {
      await _pump(tester, _adapter());

      expect(find.byKey(const ValueKey('device-token')), findsNothing);
      expect(find.byKey(const ValueKey('device-register')), findsNothing);
      expect(find.byKey(const ValueKey('device-unregister')), findsNothing);
      expect(find.byKey(const ValueKey('device-logout-all')), findsOneWidget);
    });

    testWidgets('đăng xuất tất cả thiết bị: hủy trong hộp thoại thì không gửi request', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('device-logout-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(adapter.requests, isEmpty);
    });

    testWidgets('đăng xuất tất cả thiết bị: xác nhận thì gọi POST /auth/logout-all', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('device-logout-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng xuất tất cả'));
      await tester.pumpAndSettle();

      final req = adapter.requests.firstWhere((r) => r.path.contains('/auth/logout-all'));
      expect(req.method, 'POST');
    });
  });
}
