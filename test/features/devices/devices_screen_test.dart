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
    testWidgets('đăng ký thiết bị gửi đúng token (đã sinh sẵn) và platform mặc định Android', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      final tokenField = tester.widget<TextField>(find.byKey(const ValueKey('device-token')));
      final token = tokenField.controller!.text;
      expect(token, isNotEmpty);

      await tester.tap(find.byKey(const ValueKey('device-register')));
      await tester.pumpAndSettle();

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, contains('/api/v1/devices'));
      expect(req.data, {'token': token, 'platform': 'Android'});
      expect(find.textContaining('Đã đăng ký thiết bị'), findsOneWidget);
    });

    testWidgets('bấm sinh lại token thì ô token đổi giá trị khác', (tester) async {
      await _pump(tester, _adapter());

      final before = tester.widget<TextField>(find.byKey(const ValueKey('device-token'))).controller!.text;
      await tester.tap(find.byKey(const ValueKey('device-token-regenerate')));
      await tester.pump();
      final after = tester.widget<TextField>(find.byKey(const ValueKey('device-token'))).controller!.text;

      expect(after, isNot(equals(before)));
    });

    testWidgets('chọn nền tảng iOS rồi đăng ký thì gửi platform Ios', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('device-platform')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('iOS').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('device-register')));
      await tester.pumpAndSettle();

      expect(adapter.requests.single.data['platform'], 'Ios');
    });

    testWidgets('gỡ đăng ký gửi DELETE với token hiện tại trong body', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      final token = tester.widget<TextField>(find.byKey(const ValueKey('device-token'))).controller!.text;
      await tester.tap(find.byKey(const ValueKey('device-unregister')));
      await tester.pumpAndSettle();

      final req = adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.data, {'token': token});
      expect(find.textContaining('Đã gỡ đăng ký'), findsOneWidget);
    });

    testWidgets('lỗi mạng khi đăng ký hiện thông báo lỗi, không crash', (tester) async {
      await _pump(tester, RouteAdapter((o) => throwNetworkDown(o)));

      await tester.tap(find.byKey(const ValueKey('device-register')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
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
