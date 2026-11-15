import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/profile/presentation/screens/subscription_screen.dart';
import '../../fixtures/fixture.dart';

void main() {
  Future<void> pump(WidgetTester tester, RouteAdapter adapter, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
      child: const MaterialApp(home: SubscriptionScreen()),
    ));
    await tester.pumpAndSettle();
  }

  RouteAdapter okAdapter() => RouteAdapter((o) {
        if (o.path.contains('/plans')) return respondFixture('subscriptions_plans');
        if (o.path.contains('/orders')) return respondFixture('subscriptions_orders');
        return respondFixture('subscriptions_me');
      });

  testWidgets('hiện gói hiện tại thật, giá theo năm mặc định kèm % tiết kiệm tính từ giá thật', (tester) async {
    await pump(tester, okAdapter());

    expect(find.text('Gói dịch vụ FinMate'), findsOneWidget);
    expect(find.text('Bạn đang dùng gói miễn phí'), findsOneWidget);
    expect(find.text('49.000.000 ₫'), findsWidgets);
    expect(find.text('/ năm'), findsOneWidget);
    expect(find.text('-16%'), findsOneWidget);
  });

  testWidgets('chuyển sang theo tháng đổi giá và đơn vị trên thẻ gói', (tester) async {
    await pump(tester, okAdapter());

    await tester.tap(find.byKey(const ValueKey('cycle-month')));
    await tester.pumpAndSettle();

    expect(find.text('4.900.000 ₫'), findsWidgets); // thêm một lần ở lịch sử đơn mua
    expect(find.text('/ tháng'), findsOneWidget);
  });

  testWidgets('lịch sử thanh toán hiện đơn thật; lỗi tải gói hiện Thử lại', (tester) async {
    await pump(tester, okAdapter());
    expect(find.textContaining('FM261110ABCDEF'), findsOneWidget);
    expect(find.text('Đã thanh toán'), findsOneWidget);

    var fail = true;
    await pump(tester, RouteAdapter((o) {
      if (o.path.contains('/plans') && fail) throwNetworkDown(o);
      if (o.path.contains('/plans')) return respondFixture('subscriptions_plans');
      if (o.path.contains('/orders')) return respondFixture('subscriptions_orders');
      return respondFixture('subscriptions_me');
    }));
    expect(find.text('Thử lại'), findsOneWidget);
    fail = false;
  });

  testWidgets('ở 320dp không tràn bố cục', (tester) async {
    await pump(tester, okAdapter(), width: 320);
    expect(tester.takeException(), isNull);
  });
}
