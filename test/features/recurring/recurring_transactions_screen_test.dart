import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:finmate/features/accounts/data/accounts_repository.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/planning/presentation/screens/recurring_transactions_screen.dart';
import 'package:finmate/features/recurring/data/recurring_items_repository.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';
import '../../fixtures/fixture.dart';

Future<void> _pump(WidgetTester tester, RouteAdapter adapter) async {
  final container = ProviderContainer(overrides: [
    currentUserIdProvider.overrideWith((ref) => 'u1'),
    recurringItemsRepositoryProvider.overrideWithValue(RecurringItemsRepository(apiClient: testApiClient(adapter))),
    accountsRepositoryProvider.overrideWithValue(AccountsRepository(apiClient: testApiClient(adapter))),
    categoriesProvider.overrideWith((ref) async => const <Category>[]),
  ]);
  addTearDown(container.dispose);
  tester.view.physicalSize = const Size(360, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const RecurringTransactionsScreen()),
        GoRoute(
          path: '/planning/recurring/form',
          builder: (_, state) => Scaffold(body: Text('FORM:${(state.extra as RecurringItemEntity?)?.name ?? 'new'}')),
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
}

RecurringItemEntity _item(RecurringCadence cadence, int amount) => RecurringItemEntity(
      id: 'x',
      direction: RecurringDirection.outflow,
      name: 'x',
      amountCents: BigInt.from(amount),
      cadence: cadence,
      nextDueDate: DateTime(2026, 12, 1),
      status: RecurringStatus.active,
    );

void main() {
  test('monthlyEquivalent quy đổi tuần/năm về tháng bằng số nguyên', () {
    expect(monthlyEquivalent(_item(RecurringCadence.monthly, 5000000)), BigInt.from(5000000));
    expect(monthlyEquivalent(_item(RecurringCadence.yearly, 1200000)), BigInt.from(100000));
    expect(monthlyEquivalent(_item(RecurringCadence.weekly, 120000)), BigInt.from(520000));
  });

  testWidgets('hiện tổng chi cố định từ API; khoản đề xuất có nút Xác nhận và gọi /confirm', (tester) async {
    var confirms = 0;
    final adapter = RouteAdapter((o) {
      if (o.path.contains('/financial-accounts')) return respondJson({'success': true, 'data': []});
      if (o.path.contains('/confirm')) {
        confirms++;
        return respondJson({'success': true, 'data': (fixtureData('recurring_items') as List)[1]});
      }
      return respondFixture('recurring_items');
    });
    await _pump(tester, adapter);

    expect(find.text('Tiền nhà'), findsOneWidget);
    expect(find.text('Lương'), findsOneWidget);
    // Chỉ khoản chi đang hoạt động (Tiền nhà 5.000.000) tính vào tổng; lương (thu) thì không.
    expect(find.text('5.000.000 ₫'), findsWidgets);

    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(confirms, 1);
  });

  testWidgets('thẻ tổng và chip lọc có số đếm; lọc Đề xuất chỉ còn khoản đề xuất (360dp, không tràn)', (tester) async {
    await _pump(tester, RouteAdapter((o) => respondFixture('recurring_items')));

    expect(find.text('1 khoản hoạt động'), findsOneWidget);
    expect(find.text('Tất cả (2)'), findsOneWidget);
    expect(find.text('Đề xuất (1)'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('recurring-filter-suggested')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recurring-filter-suggested')));
    await tester.tap(find.byKey(const ValueKey('recurring-filter-suggested')));
    await tester.pumpAndSettle();
    expect(find.text('Lương'), findsOneWidget);
    expect(find.text('Tiền nhà'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('khoản chi đến hạn trong 7 ngày hiện nhãn còn N ngày', (tester) async {
    final item = {
      ...(fixtureData('recurring_items') as List)[0] as Map<String, dynamic>,
      'nextDueDate': DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 3))),
    };
    await _pump(tester, RouteAdapter((o) => respondJson({'success': true, 'data': [item]})));
    expect(find.text('Sắp đến hạn (còn 3 ngày)'), findsOneWidget);
  });

  testWidgets('nút Thêm mở form mới; bấm thẻ mở form sửa với khoản đã chọn', (tester) async {
    await _pump(tester, RouteAdapter((o) => respondFixture('recurring_items')));

    await tester.tap(find.byKey(const ValueKey('recurring-add')));
    await tester.pumpAndSettle();
    expect(find.text('FORM:new'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiền nhà'));
    await tester.pumpAndSettle();
    expect(find.text('FORM:Tiền nhà'), findsOneWidget);
  });

  testWidgets('lỗi tải hiện thông điệp, Thử lại tải lại được', (tester) async {
    var fail = true;
    final adapter = RouteAdapter((o) {
      if (o.path.contains('/financial-accounts')) return respondJson({'success': true, 'data': []});
      if (fail) throwNetworkDown(o);
      return respondFixture('recurring_items');
    });
    await _pump(tester, adapter);

    expect(find.text('Thử lại'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Tiền nhà'), findsOneWidget);
  });

  testWidgets('danh sách rỗng hiện hướng dẫn thêm khoản', (tester) async {
    await _pump(tester, RouteAdapter((o) => respondJson({'success': true, 'data': []})));
    expect(find.textContaining('Chưa có khoản định kỳ nào'), findsOneWidget);
  });
}
