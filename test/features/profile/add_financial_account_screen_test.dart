import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/accounts/data/accounts_repository.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/profile/presentation/screens/add_financial_account_screen.dart';
import '../../fixtures/fixture.dart';

void main() {
  Future<RouteAdapter> pump(WidgetTester tester, {RouteAdapter? adapter}) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final a = adapter ??
        RouteAdapter((o) {
          if (o.path.contains('/providers')) return respondFixture('account_providers');
          if (o.method == 'POST') return respondJson({'success': true, 'data': (fixtureData('accounts') as List).first});
          return respondFixture('accounts');
        });
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      accountsRepositoryProvider.overrideWithValue(AccountsRepository(apiClient: testApiClient(a))),
    ]);
    addTearDown(container.dispose);
    final router = GoRouter(initialLocation: '/start', routes: [
      GoRoute(path: '/start', builder: (_, __) => const Text('START')),
      GoRoute(path: '/add', builder: (_, __) => const AddFinancialAccountScreen()),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)));
    router.push('/add');
    await tester.pumpAndSettle();
    return a;
  }

  testWidgets('đổi loại sang ví điện tử chỉ liệt kê nguồn thuộc loại đó', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('provider-bank')));
    await tester.pumpAndSettle();
    expect(find.text('MB Bank'), findsWidgets);
    expect(find.text('MoMo'), findsNothing);
    await tester.tapAt(const Offset(5, 5)); // đóng danh sách
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('type-eWallet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('provider-eWallet')));
    await tester.pumpAndSettle();
    expect(find.text('MoMo'), findsWidgets);
    expect(find.text('MB Bank'), findsNothing);
  });

  testWidgets('thiếu tên thì báo lỗi tại ô và không gọi server', (tester) async {
    final adapter = await pump(tester);

    await tester.ensureVisible(find.byKey(const ValueKey('account-submit')));
    await tester.tap(find.byKey(const ValueKey('account-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng nhập tên gợi nhớ.'), findsOneWidget);
    expect(adapter.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('thêm tiền mặt: gửi đúng body (tên, loại Cash, số dư nguyên đồng) rồi quay lại', (tester) async {
    final adapter = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('type-cash')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('account-name')), 'Ví cầm tay');
    await tester.enterText(find.byKey(const ValueKey('account-balance')), '1.500.000');
    await tester.ensureVisible(find.byKey(const ValueKey('account-submit')));
    await tester.tap(find.byKey(const ValueKey('account-submit')));
    await tester.pumpAndSettle();

    final post = adapter.requests.singleWhere((r) => r.method == 'POST');
    expect(post.path, '/api/v1/financial-accounts');
    expect(post.data, {'accountName': 'Ví cầm tay', 'accountType': 'Cash', 'initialBalanceCents': 1500000});
    expect(find.byType(AddFinancialAccountScreen), findsNothing, reason: 'sau khi thêm xong phải quay lại màn trước');
  });
}
