import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/accounts/data/accounts_repository.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/recurring/data/recurring_items_repository.dart';
import 'package:finmate/features/recurring/domain/recurring_item.dart';
import 'package:finmate/features/recurring/presentation/screens/recurring_form_screen.dart';
import '../../fixtures/fixture.dart';

Future<RouteAdapter> _pump(WidgetTester tester, {RecurringItemEntity? item}) async {
  final adapter = RouteAdapter((o) {
    if (o.path.contains('/financial-accounts')) return respondJson({'success': true, 'data': []});
    if (o.method == 'POST' || o.method == 'PATCH') return respondJson({'success': true, 'data': (fixtureData('recurring_items') as List)[0]});
    return respondFixture('recurring_items');
  });
  final container = ProviderContainer(overrides: [
    currentUserIdProvider.overrideWith((ref) => 'u1'),
    recurringItemsRepositoryProvider.overrideWithValue(RecurringItemsRepository(apiClient: testApiClient(adapter))),
    accountsRepositoryProvider.overrideWithValue(AccountsRepository(apiClient: testApiClient(adapter))),
    categoriesProvider.overrideWith((ref) async => const <Category>[]),
  ]);
  addTearDown(container.dispose);
  // 360dp: kiểm tra luôn tràn ngang (lỗi layout làm test fail qua takeException).
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: RecurringFormScreen(item: item)),
  ));
  await tester.pumpAndSettle();
  return adapter;
}

RecurringItemEntity _existing() => RecurringItemEntity.fromJson((fixtureData('recurring_items') as List)[0] as Map<String, dynamic>);

void main() {
  testWidgets('tạo: thiếu ngày đến hạn thì báo lỗi, không gọi API', (tester) async {
    final adapter = await _pump(tester);
    expect(find.text('Thêm chi phí định kỳ'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('recurring-name')), 'Internet');
    await tester.enterText(find.byKey(const ValueKey('recurring-amount')), '200000');
    await tester.tap(find.byKey(const ValueKey('recurring-save')));
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng chọn ngày đến hạn tiếp theo'), findsOneWidget);
    expect(adapter.to('/recurring-items').where((r) => r.method == 'POST'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sửa: điền sẵn dữ liệu, ẩn chiều tiền, đổi số tiền gọi PATCH', (tester) async {
    final adapter = await _pump(tester, item: _existing());
    expect(find.text('Sửa chi phí định kỳ'), findsOneWidget);
    expect(find.byKey(const ValueKey('direction-inflow')), findsNothing);
    expect(find.text('5.000.000'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('recurring-amount')), '6000000');
    await tester.tap(find.byKey(const ValueKey('recurring-save')));
    await tester.pumpAndSettle();

    final req = adapter.to('/recurring-items/r1').first;
    expect(req.method, 'PATCH');
    expect((req.data as Map)['amountCents'], 6000000);
  });

  testWidgets('sửa: bật Tạm dừng gọi POST /pause', (tester) async {
    final adapter = await _pump(tester, item: _existing());
    await tester.ensureVisible(find.byKey(const ValueKey('recurring-paused')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recurring-paused')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('recurring-save')));
    await tester.pumpAndSettle();
    expect(adapter.to('/pause'), hasLength(1));
  });
}
