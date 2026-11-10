import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/accounts/data/accounts_repository.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/categories/presentation/categories_provider.dart';
import 'package:finmate/features/recurring/data/recurring_items_repository.dart';
import 'package:finmate/features/recurring/presentation/screens/recurring_items_screen.dart';
import '../../fixtures/fixture.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, RouteAdapter adapter) async {
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
      child: const MaterialApp(home: RecurringItemsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  RouteAdapter listAdapter({List<Map<String, dynamic>>? items}) => RouteAdapter((o) {
        if (o.path.contains('/financial-accounts')) return respondJson({'success': true, 'data': []});
        if (items != null) return respondJson({'success': true, 'data': items});
        return respondFixture('recurring_items');
      });

  testWidgets('hiện danh sách: khoản active có nút Tạm dừng, khoản suggested có nút Xác nhận/Từ chối', (tester) async {
    await pumpScreen(tester, listAdapter());

    expect(find.text('Tiền nhà'), findsOneWidget);
    expect(find.text('Lương'), findsOneWidget);
    expect(find.text('Tạm dừng'), findsOneWidget);
    expect(find.text('Xác nhận'), findsOneWidget);
    expect(find.text('Từ chối'), findsOneWidget);
  });

  testWidgets('xác nhận đề xuất: gọi POST /confirm rồi tải lại danh sách', (tester) async {
    var confirms = 0;
    final adapter = RouteAdapter((o) {
      if (o.path.contains('/financial-accounts')) return respondJson({'success': true, 'data': []});
      if (o.path.contains('/confirm')) {
        confirms++;
        return respondJson({'success': true, 'data': (fixtureData('recurring_items') as List)[1]});
      }
      return respondFixture('recurring_items');
    });
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('confirm-r2')));
    await tester.pumpAndSettle();

    expect(confirms, 1);
    expect(find.text('Đã xác nhận'), findsOneWidget);
  });

  testWidgets('từ chối đề xuất: gọi POST /reject', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.path.contains('/financial-accounts')) return respondJson({'success': true, 'data': []});
      if (o.path.contains('/reject')) return respondJson({'success': true, 'data': (fixtureData('recurring_items') as List)[1]});
      return respondFixture('recurring_items');
    });
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('reject-r2')));
    await tester.pumpAndSettle();

    expect(adapter.to('/reject'), hasLength(1));
    expect(find.text('Đã từ chối'), findsOneWidget);
  });

  testWidgets('tạm dừng khoản active: gọi POST /pause', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.path.contains('/financial-accounts')) return respondJson({'success': true, 'data': []});
      if (o.path.contains('/pause')) return respondJson({'success': true, 'data': (fixtureData('recurring_items') as List)[0]});
      return respondFixture('recurring_items');
    });
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('pause-r1')));
    await tester.pumpAndSettle();

    expect(adapter.to('/pause'), hasLength(1));
    expect(find.text('Đã tạm dừng'), findsOneWidget);
  });

  testWidgets('khoản đang paused: hiện nút Tiếp tục, bấm gọi POST /resume', (tester) async {
    final paused = {...(fixtureData('recurring_items') as List)[0] as Map<String, dynamic>, 'status': 'paused'};
    final adapter = RouteAdapter((o) {
      if (o.path.contains('/financial-accounts')) return respondJson({'success': true, 'data': []});
      if (o.path.contains('/resume')) return respondJson({'success': true, 'data': paused});
      return respondJson({'success': true, 'data': [paused]});
    });
    await pumpScreen(tester, adapter);

    expect(find.text('Tiếp tục'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('resume-r1')));
    await tester.pumpAndSettle();

    expect(adapter.to('/resume'), hasLength(1));
    expect(find.text('Đã tiếp tục'), findsOneWidget);
  });

  testWidgets('hủy khoản: xác nhận rồi gọi DELETE', (tester) async {
    var deletes = 0;
    final adapter = RouteAdapter((o) {
      if (o.path.contains('/financial-accounts')) return respondJson({'success': true, 'data': []});
      if (o.method == 'DELETE') {
        deletes++;
        return respondJson({'success': true, 'data': null});
      }
      return respondFixture('recurring_items');
    });
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('cancel-r1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy khoản'));
    await tester.pumpAndSettle();

    expect(deletes, 1);
    expect(find.text('Đã hủy khoản định kỳ'), findsOneWidget);
  });

  testWidgets('tạo khoản định kỳ: thiếu ngày đến hạn thì báo lỗi, không gọi API', (tester) async {
    var posts = 0;
    final adapter = RouteAdapter((o) {
      if (o.path.contains('/financial-accounts')) return respondJson({'success': true, 'data': []});
      if (o.method == 'POST') {
        posts++;
      }
      return respondFixture('recurring_items');
    });
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('add-recurring')));
    await tester.pumpAndSettle();
    expect(find.text('Thêm khoản định kỳ'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Tên (ví dụ: Tiền nhà, Lương tháng)'), 'Internet');
    await tester.enterText(find.widgetWithText(TextField, 'Số tiền (VNĐ)'), '200.000');
    await tester.tap(find.text('Tạo'));
    await tester.pumpAndSettle();

    expect(posts, 0);
    expect(find.text('Vui lòng chọn ngày đến hạn tiếp theo'), findsOneWidget);
  });

  testWidgets('sửa khoản định kỳ: đổi số tiền (giữ ngày đến hạn đã có), gọi PATCH', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.path.contains('/financial-accounts')) return respondJson({'success': true, 'data': []});
      if (o.method == 'PATCH') return respondJson({'success': true, 'data': (fixtureData('recurring_items') as List)[0]});
      return respondFixture('recurring_items');
    });
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('edit-r1')));
    await tester.pumpAndSettle();
    expect(find.text('Sửa khoản định kỳ'), findsOneWidget);
    // Chiều tiền không hiện khi sửa (API không cho đổi)
    expect(find.text('Chiều tiền'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Số tiền (VNĐ)'), '6.000.000');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    final req = adapter.to('/recurring-items/r1').first;
    expect(req.method, 'PATCH');
    expect((req.data as Map)['amountCents'], 6000000);
    expect(find.text('Đã lưu khoản định kỳ'), findsOneWidget);
  });
}
