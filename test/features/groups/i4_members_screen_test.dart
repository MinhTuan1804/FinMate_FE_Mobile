import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/presentation/screens/i4_members_screen.dart';
import '../../fixtures/fixture.dart';

void main() {
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
          : MaterialApp(home: I4MembersScreen(groupId: groupId)),
    ));
    await tester.pumpAndSettle();
  }

  GoRouter routerFor(String groupId) => GoRouter(initialLocation: '/group-members', routes: [
        GoRoute(path: '/group-members', builder: (_, __) => I4MembersScreen(groupId: groupId)),
        GoRoute(path: '/group-invite', builder: (_, state) => Scaffold(body: Text('I5 ${state.extra}'))),
      ]);

  /// [groupOverride] null = `GET /groups/{id}` trả nhóm đầu tiên trong fixture `groups` (chủ nhóm u1).
  RouteAdapter membersAdapter({Map<String, dynamic>? groupOverride, bool hasFund = true}) => RouteAdapter((o) {
        if (o.path.contains('/members/') && o.method == 'PATCH') {
          return respondJson({
            'success': true,
            'data': {
              'userId': 'u2',
              'displayName': 'Người dùng B',
              'isActive': true,
              'role': 'Manager',
              'joinedAt': '2026-01-02T00:00:00+00:00',
              'permissions': null,
              'grantedPermissions': null,
              'revokedPermissions': null,
            },
          });
        }
        if (o.path.contains('/members')) return respondFixture('group_members');
        if (o.path.contains('/invitations')) return respondFixture('group_invitations');
        if (o.path.contains('/funds/') && o.path.contains('/summary')) return respondFixture('group_fund_summary');
        if (o.path.contains('/funds')) return hasFund ? respondFixture('group_funds') : respondJson({'success': true, 'data': []});
        if (o.path == '/api/v1/groups') return respondFixture('groups');
        final group = groupOverride ?? (fixtureData('groups') as List)[0] as Map<String, dynamic>;
        return respondJson({'success': true, 'data': group});
      });

  testWidgets('hiện tiêu đề + danh sách thành viên với vai trò thật', (tester) async {
    await pumpScreen(tester, membersAdapter());

    expect(find.textContaining('Thành viên nhóm (3)'), findsOneWidget);
    expect(find.text('Người dùng A'), findsOneWidget);
    expect(find.text('Người dùng B'), findsOneWidget);
    expect(find.text('Bạn'), findsOneWidget);
  });

  testWidgets('có quỹ chung: hiện số dư quỹ và "Đã góp" theo từng thành viên', (tester) async {
    await pumpScreen(tester, membersAdapter(hasFund: true));

    expect(find.text('12.850.000 ₫'), findsOneWidget);
    expect(find.textContaining('Đã góp: 5.000.000'), findsNWidgets(2));
  });

  testWidgets('chưa có quỹ chung: không hiện card quỹ, không hiện dòng "Đã góp"', (tester) async {
    await pumpScreen(tester, membersAdapter(hasFund: false));

    expect(find.textContaining('TÌNH TRẠNG QUỸ CHUNG'), findsNothing);
    expect(find.textContaining('Đã góp'), findsNothing);
  });

  testWidgets('chủ nhóm: thấy nút đổi vai trò/xóa cho thành viên khác, không thấy cho chính mình', (tester) async {
    await pumpScreen(tester, membersAdapter());

    expect(find.byKey(const ValueKey('change-role-u2')), findsOneWidget);
    expect(find.byKey(const ValueKey('remove-member-u2')), findsOneWidget);
    expect(find.byKey(const ValueKey('change-role-u1')), findsNothing);
    expect(find.byKey(const ValueKey('remove-member-u1')), findsNothing);
    expect(find.byKey(const ValueKey('transfer-ownership')), findsOneWidget);
  });

  testWidgets('thành viên thường: không thấy nút quản trị nào', (tester) async {
    final memberGroup = {...(fixtureData('groups') as List)[1] as Map<String, dynamic>};
    await pumpScreen(tester, membersAdapter(groupOverride: memberGroup), groupId: 'g2');

    expect(find.byKey(const ValueKey('change-role-u2')), findsNothing);
    expect(find.byKey(const ValueKey('remove-member-u2')), findsNothing);
    expect(find.byKey(const ValueKey('transfer-ownership')), findsNothing);
    expect(find.byKey(const ValueKey('go-invite')), findsNothing);
  });

  testWidgets('đổi vai trò thành viên: chọn vai trò mới rồi gọi PATCH', (tester) async {
    final adapter = membersAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('change-role-u2')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Quản lý')));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'PATCH');
    expect(req.path, '/api/v1/groups/g1/members/u2');
    expect(req.data, {'role': 'Manager'});
    expect(find.text('Đã đổi vai trò'), findsOneWidget);
  });

  testWidgets('xóa thành viên: xác nhận rồi gọi DELETE đúng path', (tester) async {
    final adapter = membersAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('remove-member-u2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa').last);
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'DELETE');
    expect(req.path, '/api/v1/groups/g1/members/u2');
    expect(find.text('Đã xóa thành viên'), findsOneWidget);
  });

  testWidgets('bấm "Mời thêm thành viên mới" hoặc icon trên AppBar: điều hướng sang I5', (tester) async {
    await pumpScreen(tester, membersAdapter(), router: routerFor('g1'));

    await tester.tap(find.byKey(const ValueKey('invite-more-members')));
    await tester.pumpAndSettle();

    expect(find.text('I5 g1'), findsOneWidget);
  });
}
