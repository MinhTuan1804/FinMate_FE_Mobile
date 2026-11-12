import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/accounts/data/accounts_repository.dart';
import 'package:finmate/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import '../../fixtures/fixture.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, RouteAdapter adapter) async {
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      accountsRepositoryProvider.overrideWithValue(AccountsRepository(apiClient: testApiClient(adapter))),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AccountsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('hiện danh sách tài khoản với số dư', (tester) async {
    final adapter = RouteAdapter((o) => respondFixture('accounts'));
    await pumpScreen(tester, adapter);

    expect(find.text('Vietcombank'), findsOneWidget);
    expect(find.textContaining('30.955.000'), findsOneWidget);
  });

  testWidgets('bấm "Xem số dư mới nhất" gọi API balance rồi tải lại danh sách', (tester) async {
    var listCalls = 0;
    final adapter = RouteAdapter((o) {
      if (o.path.contains('/balance')) return respondFixture('account_balance');
      listCalls++;
      return respondFixture('accounts');
    });
    await pumpScreen(tester, adapter);
    expect(listCalls, 1);

    await tester.tap(find.text('Xem số dư mới nhất').first);
    await tester.pumpAndSettle();

    expect(listCalls, 2, reason: 'phải tải lại danh sách để số trên thẻ cũng cập nhật, không chỉ snackbar');
    expect(find.textContaining('31.055.000'), findsOneWidget);
  });

  testWidgets('bật/tắt công tắc theo dõi gọi PATCH monitoring', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.method == 'PATCH') {
        final updated = {...(fixtureData('accounts') as List)[1] as Map<String, dynamic>, 'isMonitored': false};
        return respondJson({'success': true, 'data': updated});
      }
      return respondFixture('accounts');
    });
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('monitoring-ca6ba2c5-38ea-4af3-a664-a79a191a3ca7')));
    await tester.pumpAndSettle();

    expect(adapter.to('/monitoring'), hasLength(1));
  });

  testWidgets('xóa tài khoản: xác nhận rồi gọi DELETE', (tester) async {
    var deletes = 0;
    final adapter = RouteAdapter((o) {
      if (o.method == 'DELETE') {
        deletes++;
        return respondJson({'success': true, 'data': null});
      }
      return respondFixture('accounts');
    });
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('delete-78b154c6-c8d8-4b6d-9367-981772ce5382')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa').last);
    await tester.pumpAndSettle();

    expect(deletes, 1);
  });
}
