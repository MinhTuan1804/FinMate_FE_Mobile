import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/presentation/screens/group_detail_screen.dart';
import '../../fixtures/fixture.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, RouteAdapter adapter, {String groupId = 'g1'}) async {
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      groupsRepositoryProvider.overrideWithValue(GroupsRepository(apiClient: testApiClient(adapter))),
    ]);
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: GroupDetailScreen(groupId: groupId)),
    ));
    await tester.pumpAndSettle();
  }

  RouteAdapter detailAdapter({Map<String, dynamic>? groupOverride, List<dynamic>? invitationsOverride}) => RouteAdapter((o) {
        if (o.path.contains('/members')) return respondFixture('group_members');
        if (o.path.contains('/activities')) return respondFixture('group_activities');
        if (o.path.contains('/invitations')) {
          if (o.method == 'GET') return respondJson({'success': true, 'data': invitationsOverride ?? fixtureData('group_invitations')});
          if (o.method == 'POST') return respondJson({'success': true, 'data': (fixtureData('group_invitations') as List)[0]});
          return respondJson({'success': true, 'data': null});
        }
        // Danh sách nhóm (gọi lại sau khi xóa/rời nhóm trong GroupsController.load())
        if (o.path == '/api/v1/groups') return respondFixture('groups');
        final group = groupOverride ?? (fixtureData('groups') as List)[0] as Map<String, dynamic>;
        return respondJson({'success': true, 'data': group});
      });

  testWidgets('hiện thông tin nhóm (chủ nhóm): tên, vai trò, thành viên, hoạt động', (tester) async {
    await pumpScreen(tester, detailAdapter());

    expect(find.text('Gia đình'), findsWidgets);
    expect(find.textContaining('Vai trò của bạn: Chủ nhóm'), findsOneWidget);
    expect(find.text('Thành viên (2)'), findsOneWidget);
    expect(find.text('Người dùng A'), findsOneWidget);
    expect(find.text('Người dùng B'), findsOneWidget);
    expect(find.text('Tạo nhóm'), findsOneWidget);
    expect(find.text('Thành viên tham gia'), findsOneWidget);
    // Lời mời đang chờ: chủ nhóm mới thấy mục này
    expect(find.text('Lời mời đang chờ'), findsOneWidget);
    expect(find.text('ban@example.com'), findsOneWidget);
    expect(find.text('Mời qua link'), findsOneWidget);
    // Chủ nhóm: có nút xóa nhóm, không có nút rời nhóm
    expect(find.byKey(const ValueKey('delete-group')), findsOneWidget);
    expect(find.byKey(const ValueKey('leave-group')), findsNothing);
    expect(find.byKey(const ValueKey('open-group-finance')), findsOneWidget);
  });

  testWidgets('thành viên thường: không có nút đổi vai trò/xóa thành viên, có nút rời nhóm', (tester) async {
    final memberGroup = {...(fixtureData('groups') as List)[1] as Map<String, dynamic>};
    await pumpScreen(tester, detailAdapter(groupOverride: memberGroup), groupId: 'g2');

    expect(find.byKey(const ValueKey('leave-group')), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-group')), findsNothing);
    expect(find.byKey(const ValueKey('change-role-u2')), findsNothing);
    expect(find.byKey(const ValueKey('remove-member-u2')), findsNothing);
  });

  testWidgets('đổi tên nhóm: gọi PATCH với tên mới', (tester) async {
    final adapter = detailAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('rename-group')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Tên nhóm'), 'Gia đình (mới)');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu'));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'PATCH');
    expect(req.path, '/api/v1/groups/g1');
    expect(req.data, {'name': 'Gia đình (mới)'});
    expect(find.text('Đã đổi tên nhóm'), findsOneWidget);
  });

  testWidgets('bật/tắt cảnh báo: gọi PUT với enabled tương ứng', (tester) async {
    final adapter = detailAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('toggle-alerts-off')));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'PUT');
    expect(req.path, '/api/v1/groups/g1/alerts');
    expect(req.data, {'enabled': false});
    expect(find.text('Đã tắt cảnh báo'), findsOneWidget);
  });

  testWidgets('xóa thành viên: xác nhận rồi gọi DELETE đúng path', (tester) async {
    final adapter = detailAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('remove-member-u2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'DELETE');
    expect(req.path, '/api/v1/groups/g1/members/u2');
    expect(find.text('Đã xóa thành viên'), findsOneWidget);
  });

  testWidgets('xóa nhóm: xác nhận rồi gọi DELETE nhóm', (tester) async {
    final adapter = detailAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('delete-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa').last);
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'DELETE' && !r.path.contains('/members'));
    expect(req.path, '/api/v1/groups/g1');
  });

  testWidgets('mời thành viên: không nhập email thì tạo lời mời qua link, hiện mã lời mời', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.path.contains('/members')) return respondFixture('group_members');
      if (o.path.contains('/activities')) return respondFixture('group_activities');
      if (o.path.contains('/invitations') && o.method == 'POST') {
        return respondJson({
          'success': true,
          'data': {'id': 'inv3', 'email': null, 'role': 'Member', 'expiresAt': '2026-12-10T00:00:00+00:00', 'createdAt': '2026-11-06T00:00:00+00:00', 'token': 'mot-ma-bi-mat', 'emailSent': null},
        });
      }
      if (o.path.contains('/invitations')) return respondJson({'success': true, 'data': fixtureData('group_invitations')});
      if (o.path == '/api/v1/groups') return respondFixture('groups');
      return respondJson({'success': true, 'data': (fixtureData('groups') as List)[0]});
    });
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('invite-member')));
    await tester.pumpAndSettle();
    expect(find.text('Mời thành viên'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Mời'));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.contains('/invitations'));
    expect(req.path, '/api/v1/groups/g1/invitations');
    expect(req.data, {'role': 'Member'});
    expect(find.text('Mã lời mời'), findsOneWidget);
    expect(find.text('mot-ma-bi-mat'), findsOneWidget);
  });

  testWidgets('hủy lời mời: xác nhận rồi gọi DELETE đúng path', (tester) async {
    final adapter = detailAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('revoke-invitation-inv1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy lời mời').last);
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'DELETE' && r.path.contains('/invitations'));
    expect(req.path, '/api/v1/groups/g1/invitations/inv1');
    expect(find.text('Đã hủy lời mời'), findsOneWidget);
  });
}
