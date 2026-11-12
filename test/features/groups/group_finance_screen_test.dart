import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/presentation/screens/group_finance_screen.dart';
import '../../fixtures/fixture.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, RouteAdapter adapter, {String groupId = 'g1'}) async {
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      apiClientProvider.overrideWithValue(testApiClient(adapter)),
    ]);
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: GroupFinanceScreen(groupId: groupId)),
    ));
    await tester.pumpAndSettle();
  }

  RouteAdapter financeAdapter() => RouteAdapter((o) {
        if (o.path.contains('/financial-accounts')) return respondFixture('accounts');
        if (o.path == '/api/v1/categories') return respondFixture('categories');
        if (o.path.contains('/reports/monthly')) return respondFixture('group_monthly_report');
        if (o.path.contains('/goals/') && o.path.contains('/contributions')) {
          return respondFixture('group_goal_contributions');
        }
        if (o.path.contains('/goals/') && o.path.contains('/cancel')) return respondJson({'success': true, 'data': null});
        if (o.path.contains('/goals/') && o.path.contains('/contribute')) {
          return respondJson({'success': true, 'data': (fixtureData('group_goals') as List)[0]});
        }
        if (o.path.contains('/goals')) {
          if (o.method == 'GET') return respondFixture('group_goals');
          if (o.method == 'POST') return respondJson({'success': true, 'data': (fixtureData('group_goals') as List)[0]});
          if (o.method == 'PATCH') return respondJson({'success': true, 'data': (fixtureData('group_goals') as List)[0]});
          return respondJson({'success': true, 'data': null});
        }
        if (o.path.contains('/budgets')) {
          if (o.method == 'GET') return respondFixture('group_budgets');
          if (o.method == 'POST') return respondJson({'success': true, 'data': (fixtureData('group_budgets') as List)[0]});
          if (o.method == 'PATCH') return respondJson({'success': true, 'data': (fixtureData('group_budgets') as List)[0]});
          return respondJson({'success': true, 'data': null});
        }
        if (o.path.contains('/share-rules')) {
          if (o.method == 'GET') return respondFixture('group_share_rules');
          if (o.method == 'POST') return respondJson({'success': true, 'data': (fixtureData('group_share_rules') as List)[0]});
          return respondJson({'success': true, 'data': null});
        }
        if (o.path.contains('/transactions')) {
          if (o.method == 'GET') return respondFixture('group_transactions');
          return respondJson({'success': true, 'data': null});
        }
        if (o.path.contains('/categories')) {
          if (o.method == 'GET') return respondFixture('group_categories');
          if (o.method == 'POST') return respondJson({'success': true, 'data': (fixtureData('group_categories') as List)[0]});
          return respondJson({'success': true, 'data': null});
        }
        return respondJson({'success': true, 'data': null});
      });

  testWidgets('hiện báo cáo tháng, danh mục nhóm, quy tắc tự chia sẻ và giao dịch đã chia sẻ', (tester) async {
    await pumpScreen(tester, financeAdapter());

    expect(find.text('Tháng 11/2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('report-total-spent')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-total-income')), findsOneWidget);
    expect(find.byKey(const ValueKey('category-gc1')), findsOneWidget);
    expect(find.byKey(const ValueKey('category-gc2')), findsOneWidget);
    expect(find.byKey(const ValueKey('share-rule-gsr1')), findsOneWidget);
    expect(find.byKey(const ValueKey('share-rule-gsr2')), findsOneWidget);
    expect(find.textContaining('Tài khoản: Vietcombank'), findsOneWidget);
    expect(find.textContaining('Danh mục: Di chuyển'), findsOneWidget);
    expect(find.byKey(const ValueKey('transaction-gtx1')), findsOneWidget);
    expect(find.byKey(const ValueKey('transaction-gtx2')), findsOneWidget);
    expect(find.byKey(const ValueKey('budget-gb1')), findsOneWidget);
    expect(find.byKey(const ValueKey('budget-gb2')), findsOneWidget);
    expect(find.text('Ngân sách tổng'), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-gg1')), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-gg2')), findsOneWidget);
    expect(find.text('Du lịch hè'), findsOneWidget);
  });

  testWidgets('thêm danh mục: gọi POST với tên', (tester) async {
    final adapter = financeAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('add-category')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Tên danh mục'), 'Giải trí');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Thêm'));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.contains('/groups/g1/categories'));
    expect(req.path, '/api/v1/groups/g1/categories');
    expect(req.data, {'name': 'Giải trí'});
    expect(find.text('Đã thêm danh mục'), findsOneWidget);
  });

  testWidgets('xóa danh mục: xác nhận rồi gọi DELETE đúng path', (tester) async {
    final adapter = financeAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('delete-category-gc1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa').last);
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'DELETE' && r.path.contains('/groups/g1/categories/'));
    expect(req.path, '/api/v1/groups/g1/categories/gc1');
    expect(find.text('Đã xóa danh mục'), findsOneWidget);
  });

  testWidgets('đổi danh mục giao dịch: chọn danh mục khác rồi gọi PATCH', (tester) async {
    final adapter = financeAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('reclassify-gtx2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Di chuyển').last);
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'PATCH');
    expect(req.path, '/api/v1/groups/g1/transactions/gtx2');
    expect(req.data, {'groupCategoryId': 'gc2'});
    expect(find.text('Đã đổi danh mục'), findsOneWidget);
  });

  testWidgets('bỏ chia sẻ giao dịch: xác nhận rồi gọi DELETE đúng path', (tester) async {
    final adapter = financeAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('remove-transaction-gtx1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ chia sẻ').last);
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'DELETE' && r.path.contains('/transactions/'));
    expect(req.path, '/api/v1/groups/g1/transactions/gtx1');
    expect(find.text('Đã bỏ chia sẻ giao dịch'), findsOneWidget);
  });

  testWidgets('thêm quy tắc tự chia sẻ theo tài khoản: gọi POST với financialAccountId', (tester) async {
    final adapter = financeAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('add-share-rule')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-rule-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vietcombank').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-share-rule')));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.contains('/share-rules'));
    expect(req.path, '/api/v1/groups/g1/share-rules');
    expect(req.data, {'financialAccountId': '78b154c6-c8d8-4b6d-9367-981772ce5382', 'categoryId': null});
    expect(find.text('Đã tạo quy tắc tự chia sẻ'), findsOneWidget);
  });

  testWidgets('xóa quy tắc tự chia sẻ: xác nhận rồi gọi DELETE đúng path', (tester) async {
    final adapter = financeAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('delete-share-rule-gsr1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa').last);
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'DELETE' && r.path.contains('/share-rules/'));
    expect(req.path, '/api/v1/groups/g1/share-rules/gsr1');
    expect(find.text('Đã xóa quy tắc'), findsOneWidget);
  });

  testWidgets('thêm ngân sách tổng: gọi POST với categoryId/groupCategoryId null', (tester) async {
    final adapter = financeAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('add-budget')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Hạn mức (₫)'), '2000000');
    await tester.tap(find.byKey(const ValueKey('create-budget')));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.contains('/budgets'));
    expect(req.path, '/api/v1/groups/g1/budgets');
    expect(req.data, {'categoryId': null, 'groupCategoryId': null, 'limitCents': 2000000});
    expect(find.text('Đã tạo ngân sách'), findsOneWidget);
  });

  testWidgets('chạm vào ngân sách: đổi hạn mức gọi PATCH', (tester) async {
    final adapter = financeAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('budget-gb1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Hạn mức (₫)'), '3000000');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu'));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'PATCH' && r.path.contains('/budgets/'));
    expect(req.path, '/api/v1/groups/g1/budgets/gb1');
    expect(req.data, {'limitCents': 3000000});
    expect(find.text('Đã đổi hạn mức'), findsOneWidget);
  });

  testWidgets('xóa ngân sách: xác nhận rồi gọi DELETE đúng path', (tester) async {
    final adapter = financeAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('delete-budget-gb1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa').last);
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'DELETE' && r.path.contains('/budgets/'));
    expect(req.path, '/api/v1/groups/g1/budgets/gb1');
    expect(find.text('Đã xóa ngân sách'), findsOneWidget);
  });

  testWidgets('thêm mục tiêu nhóm: gọi POST với name/targetCents', (tester) async {
    final adapter = financeAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('add-goal')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Tên mục tiêu'), 'Mua xe');
    await tester.enterText(find.widgetWithText(TextField, 'Số tiền mục tiêu (₫)'), '20000000');
    await tester.tap(find.byKey(const ValueKey('create-goal')));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.contains('/goals') && !r.path.contains('/contribute'));
    expect(req.path, '/api/v1/groups/g1/goals');
    expect(req.data, {'name': 'Mua xe', 'targetCents': 20000000});
    expect(find.text('Đã tạo mục tiêu'), findsOneWidget);
  });

  testWidgets('góp tiền vào mục tiêu: gọi POST .../contribute với amountCents', (tester) async {
    final adapter = financeAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('contribute-goal-gg1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Số tiền (₫)'), '500000');
    await tester.tap(find.byKey(const ValueKey('submit-contribute')));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.contains('/contribute'));
    expect(req.path, '/api/v1/groups/g1/goals/gg1/contribute');
    expect(req.data, {'amountCents': 500000});
    expect(find.text('Đã góp tiền vào mục tiêu'), findsOneWidget);
  });

  testWidgets('chạm vào mục tiêu: hiện lịch sử góp tiền', (tester) async {
    final adapter = financeAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('goal-gg1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('contribution-ggc1')), findsOneWidget);
    expect(find.byKey(const ValueKey('contribution-ggc2')), findsOneWidget);
    // Thu hẹp vào đúng ListTile trong dialog: thẻ báo cáo tháng phía sau cũng có dòng
    // "Người dùng A: chi ... · thu ..." chứa cùng tên thành viên.
    expect(
      find.descendant(of: find.byKey(const ValueKey('contribution-ggc1')), matching: find.textContaining('Người dùng A')),
      findsOneWidget,
    );
  });

  testWidgets('hủy mục tiêu: xác nhận rồi gọi POST .../cancel', (tester) async {
    final adapter = financeAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('cancel-goal-gg1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy mục tiêu').last);
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.contains('/cancel'));
    expect(req.path, '/api/v1/groups/g1/goals/gg1/cancel');
    expect(find.text('Đã hủy mục tiêu'), findsOneWidget);
  });
}
