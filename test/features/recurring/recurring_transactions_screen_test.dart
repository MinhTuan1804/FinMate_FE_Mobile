import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: RecurringTransactionsScreen()),
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
