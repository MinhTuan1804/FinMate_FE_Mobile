import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/accounts/data/accounts_repository.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/profile/presentation/screens/financial_accounts_screen.dart';
import '../../fixtures/fixture.dart';

void main() {
  Future<void> pump(WidgetTester tester, RouteAdapter adapter, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      accountsRepositoryProvider.overrideWithValue(AccountsRepository(apiClient: testApiClient(adapter))),
    ]);
    addTearDown(container.dispose);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const FinancialAccountsScreen()),
      GoRoute(path: '/profile/financial-accounts/add', builder: (_, __) => const Text('ADD_PAGE')),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
  }

  RouteAdapter listAdapter() => RouteAdapter((o) {
        if (o.method == 'DELETE') return respondJson({}, status: 204);
        return respondFixture('accounts');
      });

  testWidgets('hiện tổng số dư thật, gom theo loại và trạng thái từng ví', (tester) async {
    await pump(tester, listAdapter());

    expect(find.text('34.955.000 ₫'), findsOneWidget); // 30.955.000 + 4.000.000
    expect(find.text('Ngân hàng liên kết'), findsOneWidget);
    expect(find.text('Tiền mặt'), findsWidgets);
    expect(find.text('Vietcombank'), findsWidgets);
    expect(find.text('Tự động đồng bộ'), findsOneWidget);
    expect(find.text('Tự kiểm đếm'), findsOneWidget);
  });

  testWidgets('nút mắt ẩn rồi hiện lại số dư', (tester) async {
    await pump(tester, listAdapter());

    await tester.tap(find.byKey(const ValueKey('toggle-hide')));
    await tester.pumpAndSettle();
    expect(find.text('34.955.000 ₫'), findsNothing);
    expect(find.text('••••••••'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('toggle-hide')));
    await tester.pumpAndSettle();
    expect(find.text('34.955.000 ₫'), findsOneWidget);
  });

  testWidgets('xóa ví: hỏi xác nhận rồi gọi DELETE', (tester) async {
    final adapter = listAdapter();
    await pump(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('menu-78b154c6-c8d8-4b6d-9367-981772ce5382')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(find.textContaining('không thể hoàn tác'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Xóa'));
    await tester.pumpAndSettle();

    expect(adapter.requests.where((r) => r.method == 'DELETE').single.path, '/api/v1/financial-accounts/78b154c6-c8d8-4b6d-9367-981772ce5382');
  });

  testWidgets('đổi tên: bấm Lưu rồi dialog đóng KHÔNG crash "TextEditingController used after being disposed" (regression)', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.method == 'PATCH') {
        final updated = {...(fixtureData('accounts') as List)[0] as Map<String, dynamic>, 'accountName': 'Tên mới'};
        return respondJson({'success': true, 'data': updated});
      }
      return respondFixture('accounts');
    });
    await pump(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('menu-78b154c6-c8d8-4b6d-9367-981772ce5382')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi tên'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tên mới');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    // CỐ Ý không pumpAndSettle ngay — bơm từng khung hình nhỏ ngay sau khi Navigator.pop() trả về,
    // đúng lúc AlertDialog còn đang chạy hiệu ứng đóng (fade/scale out) và TextField vẫn còn mounted.
    // Đây chính là khung thời gian mà controller bị dispose sớm (trước khi sửa) sẽ crash.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(adapter.requests.where((r) => r.method == 'PATCH').single.data, {'accountName': 'Tên mới'});
  });

  testWidgets('lỗi tải hiện thông điệp và Thử lại', (tester) async {
    var fail = true;
    final adapter = RouteAdapter((o) {
      if (fail) throwNetworkDown(o);
      return respondFixture('accounts');
    });
    await pump(tester, adapter);

    expect(find.text('Thử lại'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('34.955.000 ₫'), findsOneWidget);
  });

  testWidgets('danh sách rỗng hiện hướng dẫn; nút thêm mở màn thêm tài khoản; 320dp không tràn', (tester) async {
    await pump(tester, RouteAdapter((o) => respondJson({'success': true, 'data': []})), width: 320);
    expect(find.textContaining('Chưa có tài khoản nào'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const ValueKey('add-account-bottom')));
    await tester.tap(find.byKey(const ValueKey('add-account-bottom')));
    await tester.pumpAndSettle();
    expect(find.text('ADD_PAGE'), findsOneWidget);
  });
}
