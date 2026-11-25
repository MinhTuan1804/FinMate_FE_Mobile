import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/presentation/screens/groups_screen.dart';
import '../../fixtures/fixture.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, RouteAdapter adapter, {GoRouter? router}) async {
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      groupsRepositoryProvider.overrideWithValue(GroupsRepository(apiClient: testApiClient(adapter))),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: router != null ? MaterialApp.router(routerConfig: router) : const MaterialApp(home: GroupsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('hiện danh sách nhóm với vai trò và số thành viên', (tester) async {
    await pumpScreen(tester, RouteAdapter((o) => respondFixture('groups')));

    expect(find.text('Gia đình'), findsOneWidget);
    expect(find.text('Quỹ phòng trọ'), findsOneWidget);
    expect(find.textContaining('3 thành viên'), findsOneWidget);
    expect(find.text('Trưởng nhóm'), findsOneWidget);
    expect(find.text('Thành viên'), findsOneWidget);
  });

  testWidgets('danh sách rỗng hiện thông báo chưa tham gia nhóm', (tester) async {
    await pumpScreen(tester, RouteAdapter((o) => respondJson({'success': true, 'data': []})));

    expect(find.text('Chưa tham gia nhóm nào.'), findsOneWidget);
  });

  testWidgets('nút "Tạo nhóm mới" điều hướng sang màn tạo nhóm (I2)', (tester) async {
    final adapter = RouteAdapter((o) => respondFixture('groups'));
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const GroupsScreen()),
      GoRoute(path: '/groups/create', builder: (_, __) => const Text('I2_CREATE_GROUP')),
    ]);
    await pumpScreen(tester, adapter, router: router);

    await tester.tap(find.byKey(const ValueKey('create-group')));
    await tester.pumpAndSettle();

    expect(find.text('I2_CREATE_GROUP'), findsOneWidget);
  });

  testWidgets('sắp xếp: mặc định nhóm mới nhất lên đầu, chọn Tên A–Z thì xếp theo tên', (tester) async {
    await pumpScreen(tester, RouteAdapter((o) => respondFixture('groups')));
    // "Quỹ phòng trọ" tạo sau "Gia đình" nên đứng trước theo mặc định
    expect(tester.getTopLeft(find.text('Quỹ phòng trọ')).dy, lessThan(tester.getTopLeft(find.text('Gia đình').last).dy));

    await tester.tap(find.byKey(const ValueKey('group-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tên A–Z').last);
    await tester.pumpAndSettle();

    expect(find.text('Sắp xếp: Tên A–Z'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Gia đình').last).dy, lessThan(tester.getTopLeft(find.text('Quỹ phòng trọ')).dy));
  });

  Map<String, dynamic> groupJson(String id, String name, String type, {Map<String, dynamic>? card}) => {
        'id': id,
        'name': name,
        'type': type,
        'transactionVisibility': 'Full',
        'myRole': 'Owner',
        'myPermissions': <String>[],
        'memberCount': 4,
        'createdAt': '2026-11-01T00:00:00+00:00',
        'icon': 'house',
        'card': card,
      };

  testWidgets('hero lấy tổng quan từ /groups/me/summary: phần cần đóng, cần thanh toán, hạn chốt', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.path.endsWith('/groups/me/summary')) {
        return respondJson({
          'success': true,
          'data': {
            'year': 2026,
            'month': 11,
            'totalSpentCents': 7600000,
            'activeGroupCount': 2,
            'myShareDueCents': 3633333,
            'myPayableCents': 3533333,
            'closingDate': '2026-11-30',
          },
        });
      }
      return respondJson({'success': true, 'data': [groupJson('g1', 'Phòng trọ', 'Roommates')]});
    });
    await pumpScreen(tester, adapter);

    expect(find.textContaining('7.600.000'), findsOneWidget);
    expect(find.byKey(const ValueKey('groups-debt-summary')), findsOneWidget);
    expect(find.textContaining('3.633.333'), findsOneWidget);
    expect(find.textContaining('3.533.333'), findsOneWidget);
    expect(find.text('Hạn chốt: 30/11'), findsOneWidget);
  });

  testWidgets('thẻ nhóm: tiến độ ngân sách và chip lọc theo các loại nhóm đang có', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.path.endsWith('/groups/me/summary')) return respondJson({'success': true, 'data': {'totalSpentCents': 0, 'activeGroupCount': 2}});
      return respondJson({
        'success': true,
        'data': [
          groupJson('g1', 'Phòng trọ', 'Roommates', card: {
            'fundBalanceCents': 10000000,
            'monthlySpentCents': 7600000,
            'monthlyBudgetCents': 20000000,
            'memberPreview': [
              {'userId': 'u1', 'displayName': 'Minh', 'avatarUrl': null},
            ],
          }),
          groupJson('g2', 'Team Tech', 'Colleagues'),
        ],
      });
    });
    await pumpScreen(tester, adapter);

    expect(find.text('Đã chi 38% ngân sách tháng'), findsOneWidget);
    expect(find.byKey(const ValueKey('group-budget-g1')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-filter-roommates')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-filter-colleagues')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-filter-family')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('group-filter-colleagues')));
    await tester.pumpAndSettle();
    expect(find.text('Team Tech'), findsOneWidget);
    expect(find.text('Phòng trọ'), findsNothing);
  });

  testWidgets('"Thanh toán": có số cần thanh toán và nhóm chia hóa đơn thì mở thẳng nhóm đó', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.path.endsWith('/groups/me/summary')) {
        return respondJson({'success': true, 'data': {'totalSpentCents': 100, 'activeGroupCount': 1, 'myShareDueCents': 50, 'myPayableCents': 650000, 'closingDate': '2026-12-28'}});
      }
      return respondJson({'success': true, 'data': [{...groupJson('g7', 'Phòng trọ', 'Roommates'), 'settlementModel': 'SplitBill'}]});
    });
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const GroupsScreen()),
      GoRoute(path: '/group-detail', builder: (_, state) => Text('GROUP_DETAIL ${state.extra}')),
    ]);
    await pumpScreen(tester, adapter, router: router);

    await tester.tap(find.byKey(const ValueKey('groups-pay')));
    await tester.pumpAndSettle();

    expect(find.text('GROUP_DETAIL g7'), findsOneWidget);
  });

  testWidgets('không còn nợ cần thanh toán thì không hiện nút Thanh toán; thẻ giải thích cách chia mở được hộp thoại', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.path.endsWith('/groups/me/summary')) return respondJson({'success': true, 'data': {'totalSpentCents': 0, 'activeGroupCount': 1, 'myPayableCents': 0}});
      return respondJson({'success': true, 'data': [groupJson('g1', 'Phòng trọ', 'Roommates')]});
    });
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpScreen(tester, adapter);

    expect(find.byKey(const ValueKey('groups-pay')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('fair-split-learn')));
    await tester.tap(find.byKey(const ValueKey('fair-split-learn')));
    await tester.pumpAndSettle();
    expect(find.text('Cách chia nợ'), findsOneWidget);
  });
}
