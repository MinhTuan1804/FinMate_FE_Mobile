import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/presentation/screens/group_detail_screen.dart';
import '../../fixtures/fixture.dart';

void main() {
  /// [router] chỉ cần khi test bấm vào nút điều hướng (mời thành viên/thành viên nhóm) — các test
  /// khác chỉ pump thẳng `GroupDetailScreen` trong `MaterialApp` thường, không cần router.
  Future<void> pumpScreen(WidgetTester tester, RouteAdapter adapter, {String groupId = 'g1', GoRouter? router}) async {
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      apiClientProvider.overrideWithValue(testApiClient(adapter)),
      groupsRepositoryProvider.overrideWithValue(GroupsRepository(apiClient: testApiClient(adapter))),
    ]);
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: router != null
          ? MaterialApp.router(routerConfig: router)
          : MaterialApp(home: GroupDetailScreen(groupId: groupId)),
    ));
    await tester.pumpAndSettle();
  }

  GoRouter routerFor(String groupId) => GoRouter(initialLocation: '/group-detail', routes: [
        GoRoute(path: '/group-detail', builder: (_, __) => GroupDetailScreen(groupId: groupId)),
        GoRoute(path: '/group-members', builder: (_, state) => Scaffold(body: Text('I4 ${state.extra}'))),
        GoRoute(path: '/group-invite', builder: (_, state) => Scaffold(body: Text('I5 ${state.extra}'))),
        GoRoute(path: '/group-settings', builder: (_, state) => Scaffold(body: Text('I7 ${state.extra}'))),
      ]);

  /// [fundId] null = nhóm chưa có quỹ chung (`GET /funds` trả rỗng).
  RouteAdapter detailAdapter({
    Map<String, dynamic>? groupOverride,
    bool hasFund = false,
  }) =>
      RouteAdapter((o) {
        if (o.path.contains('/members')) return respondFixture('group_members');
        if (o.path.contains('/activities')) return respondFixture('group_activities');
        if (o.path.contains('/invitations')) return respondFixture('group_invitations');
        if (o.path.contains('/transactions')) return respondFixture('group_transactions');
        if (o.path.contains('/budgets')) return respondFixture('group_budgets');
        if (o.path.contains('/goals')) return respondFixture('group_goals');
        if (o.path == '/api/v1/categories') return respondFixture('categories');
        if (o.path.contains('/categories')) return respondFixture('group_categories');
        if (o.path.contains('/funds/') && o.path.contains('/entries') && o.method == 'POST') {
          return respondJson({
            'success': true,
            'data': {
              'entry': {
                'id': 'fe3',
                'kind': 'Contribution',
                'amountCents': 200000,
                'transactedAt': '2026-11-16T00:00:00+00:00',
                'memberUserId': 'u1',
                'memberName': 'Người dùng A',
              },
              'fund': fixtureData('group_funds') as List,
              'alreadyExisted': false,
            },
          });
        }
        if (o.path.contains('/funds/') && o.path.contains('/summary')) return respondFixture('group_fund_summary');
        if (o.path.contains('/funds/') && o.path.contains('/entries')) return respondFixture('group_fund_entries');
        if (o.path.contains('/funds')) {
          return hasFund ? respondFixture('group_funds') : respondJson({'success': true, 'data': []});
        }
        // Danh sách nhóm (gọi lại sau khi xóa/rời nhóm trong GroupsController.load())
        if (o.path == '/api/v1/groups') return respondFixture('groups');
        final group = groupOverride ?? (fixtureData('groups') as List)[0] as Map<String, dynamic>;
        return respondJson({'success': true, 'data': group});
      });

  testWidgets('hiện tên nhóm, quỹ chung và ngân sách tổng trên hero card', (tester) async {
    await pumpScreen(tester, detailAdapter(hasFund: true));

    expect(find.text('Gia đình'), findsOneWidget);
    expect(find.text('3 thành viên'), findsOneWidget);
    expect(find.text('12.850.000 ₫'), findsOneWidget);
    expect(find.textContaining('Đã chi tháng này'), findsOneWidget);
  });

  testWidgets('chưa có quỹ chung: hero card báo chưa có quỹ, tab Quỹ chung báo tương tự', (tester) async {
    await pumpScreen(tester, detailAdapter(hasFund: false));

    expect(find.text('Nhóm chưa có quỹ chung nào.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('detail-tab-fund')));
    await tester.pumpAndSettle();

    expect(find.textContaining('chưa có quỹ chung nào'), findsWidgets);
  });

  testWidgets('tab Quỹ chung: hiện sổ quỹ và phần đã góp theo thành viên khi có quỹ', (tester) async {
    await pumpScreen(tester, detailAdapter(hasFund: true));

    await tester.tap(find.byKey(const ValueKey('detail-tab-fund')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Đã góp: 5.000.000'), findsNWidgets(2));
    expect(find.text('Siêu thị WinMart'), findsOneWidget);
  });

  testWidgets('tab Ngân sách và Mục tiêu hiện đúng danh sách thật', (tester) async {
    await pumpScreen(tester, detailAdapter());

    await tester.tap(find.byKey(const ValueKey('detail-tab-budgets')));
    await tester.pumpAndSettle();
    expect(find.text('Di chuyển'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('detail-tab-goals')));
    await tester.pumpAndSettle();
    expect(find.text('Du lịch hè'), findsOneWidget);
  });

  testWidgets('thành viên thường: không có icon mời thành viên trên AppBar', (tester) async {
    final memberGroup = {...(fixtureData('groups') as List)[1] as Map<String, dynamic>};
    await pumpScreen(tester, detailAdapter(groupOverride: memberGroup), groupId: 'g2');

    // Thành viên thường không có icon mời trên AppBar (chỉ chủ nhóm/người có quyền InviteMembers).
    expect(find.byKey(const ValueKey('invite-member')), findsNothing);
    // Icon cài đặt nhóm (→ I7) luôn hiện — I7 tự ẩn các hành động chỉ-chủ-nhóm bên trong nó.
    expect(find.byKey(const ValueKey('open-group-settings')), findsOneWidget);
  });

  testWidgets('bấm icon cài đặt nhóm trên AppBar: điều hướng sang I7 (mang theo groupId)', (tester) async {
    await pumpScreen(tester, detailAdapter(), router: routerFor('g1'));

    await tester.tap(find.byKey(const ValueKey('open-group-settings')));
    await tester.pumpAndSettle();

    expect(find.text('I7 g1'), findsOneWidget);
  });

  testWidgets('bấm icon mời thành viên trên AppBar: điều hướng sang I5 (mang theo groupId)', (tester) async {
    await pumpScreen(tester, detailAdapter(), router: routerFor('g1'));

    await tester.tap(find.byKey(const ValueKey('invite-member')));
    await tester.pumpAndSettle();

    expect(find.text('I5 g1'), findsOneWidget);
  });

  testWidgets('bấm tiêu đề số thành viên trên AppBar: điều hướng sang I4 (mang theo groupId)', (tester) async {
    await pumpScreen(tester, detailAdapter(), router: routerFor('g1'));

    await tester.tap(find.byKey(const ValueKey('go-members')));
    await tester.pumpAndSettle();

    expect(find.text('I4 g1'), findsOneWidget);
  });

  testWidgets('nạp quỹ nhóm: gọi POST entries với kind Contribution', (tester) async {
    final adapter = detailAdapter(hasFund: true);
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('fund-contribute')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('contribute-amount')), '200000');
    await tester.tap(find.byKey(const ValueKey('submit-contribute')));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.contains('/funds/') && r.path.contains('/entries'));
    expect(req.path, '/api/v1/groups/g1/funds/gf1/entries');
    expect(req.data, {'kind': 'Contribution', 'amountCents': 200000});
    expect(find.text('Đã nạp quỹ nhóm'), findsOneWidget);
  });

  testWidgets('chưa có quỹ: bấm nạp quỹ báo cần tạo quỹ trước, không mở form', (tester) async {
    await pumpScreen(tester, detailAdapter(hasFund: false));

    await tester.tap(find.byKey(const ValueKey('fund-contribute')));
    await tester.pumpAndSettle();

    expect(find.textContaining('tạo quỹ trước trong Cài đặt nhóm'), findsOneWidget);
    expect(find.byKey(const ValueKey('contribute-amount')), findsNothing);
  });

  testWidgets('ghi khoản chi từ quỹ: gọi POST entries với kind Expense và categoryId', (tester) async {
    final adapter = detailAdapter(hasFund: true);
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('fund-record-expense')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '150000');
    await tester.tap(find.byKey(const ValueKey('expense-category-system')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Di chuyển').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('expense-merchant')), 'Hãng taxi');
    await tester.tap(find.byKey(const ValueKey('submit-expense')));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.contains('/funds/') && r.path.contains('/entries'));
    expect(req.path, '/api/v1/groups/g1/funds/gf1/entries');
    expect(req.data, {
      'kind': 'Expense',
      'amountCents': 150000,
      'categoryId': '97ce1e37-b3f6-4394-8ff7-b1dd50ddea83',
      'merchantName': 'Hãng taxi',
    });
    expect(find.text('Đã ghi khoản chi từ quỹ'), findsOneWidget);
  });

  testWidgets('ghi khoản chi: chưa chọn danh mục thì báo lỗi, không gọi POST', (tester) async {
    final adapter = detailAdapter(hasFund: true);
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('fund-record-expense')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '150000');
    await tester.tap(find.byKey(const ValueKey('submit-expense')));
    await tester.pumpAndSettle();

    expect(find.text('Chọn danh mục'), findsOneWidget);
    expect(adapter.requests.where((r) => r.method == 'POST' && r.path.contains('/entries')), isEmpty);
  });
}
