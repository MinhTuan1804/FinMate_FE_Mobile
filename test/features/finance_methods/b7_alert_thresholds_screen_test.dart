import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/domain/entities/user_profile.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/finance_methods/presentation/screens/b7_alert_thresholds_screen.dart';
import '../../fixtures/fixture.dart';

class _MockAuth extends StateNotifier<AsyncValue<UserProfile?>> implements AuthController {
  _MockAuth(super.state);

  final saved = <NotificationPrefs>[];

  @override
  Future<void> updateNotificationPrefs(NotificationPrefs prefs) async {
    saved.add(prefs);
    state = AsyncValue.data(state.value!.copyWith(notificationPrefs: prefs));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
      expect(find.textContaining('70% · 90% (mặc định hệ thống)'), findsOneWidget);
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
      expect(find.textContaining('(cá nhân)'), findsOneWidget);
    });

    testWidgets('xóa ngưỡng cá nhân: gửi DELETE rồi tự tải lại GET', (tester) async {
      final adapter = _adapter();
      await _pump(tester, adapter);

      await tester.tap(find.text('Mặc định'));
      await tester.pumpAndSettle();

      final deleteReq = adapter.requests.firstWhere((r) => r.method == 'DELETE' && r.path.contains('/alert-thresholds'));
      expect(deleteReq, isNotNull);
      expect(find.textContaining('(mặc định hệ thống)'), findsOneWidget);
    });

    testWidgets('tùy chọn thông báo lấy từ hồ sơ; tắt công tắc gọi updateNotificationPrefs với đúng giá trị', (tester) async {
      final user = UserProfile(
        id: 'u1',
        email: 'probe@example.com',
        displayName: 'Probe',
        isEmailVerified: true,
        notificationPrefs: NotificationPrefs.defaultPrefs(),
        createdAt: DateTime(2026),
      );
      final auth = _MockAuth(AsyncValue.data(user));
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(testApiClient(_adapter())),
          authControllerProvider.overrideWith((ref) => auth),
        ],
        child: const MaterialApp(home: AlertThresholdsScreen()),
      ));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.descendant(of: find.byKey(const ValueKey('pref-push')), matching: find.byType(Switch))).value, isTrue);
      await tester.tap(find.byKey(const ValueKey('pref-budget')));
      await tester.pumpAndSettle();

      expect(auth.saved, hasLength(1));
      expect(auth.saved.single.budgetAlertsEnabled, isFalse);
      expect(auth.saved.single.pushEnabled, isTrue);
    });
  });
}
