import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/subscriptions/presentation/screens/subscriptions_screen.dart';
import '../../fixtures/fixture.dart';

Future<void> _pump(WidgetTester tester, RouteAdapter adapter) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: const MaterialApp(home: SubscriptionsScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('SubscriptionsScreen', () {
    testWidgets('hiện gói hiện tại, danh sách gói và lịch sử đơn', (tester) async {
      final adapter = RouteAdapter((o) {
        if (o.path.contains('/me')) return respondFixture('subscriptions_me');
        if (o.path.contains('/plans')) return respondFixture('subscriptions_plans');
        return respondFixture('subscriptions_orders');
      });
      await _pump(tester, adapter);

      expect(find.byKey(const ValueKey('my-sub-plan-name')), findsOneWidget);
      expect(find.text('Miễn phí (free)'), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-free')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-pro')), findsOneWidget);
      expect(find.byKey(const ValueKey('order-FM261110ABCDEF')), findsOneWidget);
      expect(find.byKey(const ValueKey('order-FM261105FEDCBA')), findsOneWidget);
    });

    testWidgets('chưa có đơn nào thì hiện thông báo trống', (tester) async {
      final adapter = RouteAdapter((o) {
        if (o.path.contains('/me')) return respondFixture('subscriptions_me');
        if (o.path.contains('/plans')) return respondFixture('subscriptions_plans');
        return respondFixture('subscriptions_orders_empty');
      });
      await _pump(tester, adapter);

      expect(find.text('Bạn chưa có đơn mua gói nào.'), findsOneWidget);
    });

    testWidgets('bấm tạo liên kết web checkout thì hiện url trong dialog', (tester) async {
      final adapter = RouteAdapter((o) {
        if (o.path.contains('/me')) return respondFixture('subscriptions_me');
        if (o.path.contains('/plans')) return respondFixture('subscriptions_plans');
        if (o.path.contains('/orders')) return respondFixture('subscriptions_orders_empty');
        return respondFixture('subscriptions_web_session');
      });
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('create-web-session')));
      await tester.pumpAndSettle();

      expect(find.text('https://billing.finmate.vn/subscribe?code=abc123'), findsOneWidget);

      final req = adapter.to('/api/v1/subscriptions/web-session').single;
      expect(req.method, 'POST');
    });

    testWidgets('BE báo tính năng đang tắt thì hiện SnackBar đúng message', (tester) async {
      final adapter = RouteAdapter((o) {
        if (o.path.contains('/me')) return respondFixture('subscriptions_me');
        if (o.path.contains('/plans')) return respondFixture('subscriptions_plans');
        if (o.path.contains('/orders')) return respondFixture('subscriptions_orders_empty');
        return respondFixture('subscriptions_error_disabled', status: 400);
      });
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('create-web-session')));
      await tester.pumpAndSettle();

      expect(find.text('Tính năng đăng ký gói hiện chưa được bật.'), findsOneWidget);
    });
  });
}
