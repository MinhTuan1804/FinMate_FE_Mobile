import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/presentation/screens/i5_invite_members_screen.dart';
import '../../fixtures/fixture.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, RouteAdapter adapter, {String groupId = 'g1'}) async {
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
      child: MaterialApp(home: I5InviteMembersScreen(groupId: groupId)),
    ));
    await tester.pumpAndSettle();
  }

  RouteAdapter inviteAdapter({
    Map<String, dynamic>? groupOverride,
    Map<String, dynamic>? invitationCreateResponse,
    List<dynamic>? invitationsOverride,
  }) =>
      RouteAdapter((o) {
        if (o.path.contains('/invitations') && o.method == 'POST') {
          return respondJson({
            'success': true,
            'data': invitationCreateResponse ??
                {
                  'id': 'inv3',
                  'email': null,
                  'role': 'Member',
                  'expiresAt': '2026-12-10T00:00:00+00:00',
                  'createdAt': '2026-11-06T00:00:00+00:00',
                  'token': 'mot-ma-bi-mat',
                  'emailSent': null,
                },
          });
        }
        if (o.path.contains('/invitations')) {
          return respondJson({'success': true, 'data': invitationsOverride ?? fixtureData('group_invitations')});
        }
        if (o.path == '/api/v1/groups') return respondFixture('groups');
        final group = groupOverride ?? (fixtureData('groups') as List)[0] as Map<String, dynamic>;
        return respondJson({'success': true, 'data': group});
      });

  testWidgets('chủ nhóm: thấy tên nhóm + 3 vai trò mời được (trừ Chủ nhóm)', (tester) async {
    await pumpScreen(tester, inviteAdapter());

    expect(find.text('Gia đình'), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-role-Manager')), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-role-Member')), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-role-Viewer')), findsOneWidget);
  });

  testWidgets('vai trò Member: chỉ mời được Viewer (thấp hơn mình)', (tester) async {
    final memberGroup = {...(fixtureData('groups') as List)[1] as Map<String, dynamic>};
    await pumpScreen(tester, inviteAdapter(groupOverride: memberGroup), groupId: 'g2');

    expect(find.byKey(const ValueKey('invite-role-Viewer')), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-role-Member')), findsNothing);
    expect(find.byKey(const ValueKey('invite-role-Manager')), findsNothing);
  });

  testWidgets('tạo lời mời qua link (không nhập email): gọi POST rồi hiện mã QR + mã text', (tester) async {
    final adapter = inviteAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('invite-role-Member')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('submit-invite')));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.contains('/invitations'));
    expect(req.path, '/api/v1/groups/g1/invitations');
    expect(req.data, {'role': 'Member'});
    expect(find.text('mot-ma-bi-mat'), findsOneWidget);
    expect(find.byKey(const ValueKey('copy-invite-code')), findsOneWidget);
    expect(find.byKey(const ValueKey('share-invite-code')), findsOneWidget);
  });

  testWidgets('tạo lời mời qua email: gọi POST kèm email, không hiện mã QR', (tester) async {
    final adapter = inviteAdapter(invitationCreateResponse: {
      'id': 'inv4',
      'email': 'ban@example.com',
      'role': 'Member',
      'expiresAt': '2026-12-10T00:00:00+00:00',
      'createdAt': '2026-11-06T00:00:00+00:00',
      'token': null,
      'emailSent': true,
    });
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('invite-role-Member')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('invite-email')), 'ban@example.com');
    await tester.tap(find.byKey(const ValueKey('submit-invite')));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.contains('/invitations'));
    expect(req.data, {'email': 'ban@example.com', 'role': 'Member'});
    expect(find.text('Đã tạo lời mời, email sẽ được gửi'), findsOneWidget);
    expect(find.byKey(const ValueKey('copy-invite-code')), findsNothing);
  });

  testWidgets('hiện danh sách lời mời đang chờ từ fixture', (tester) async {
    await pumpScreen(tester, inviteAdapter());

    expect(find.text('ban@example.com'), findsOneWidget);
    expect(find.text('Mời qua link'), findsOneWidget);
  });

  testWidgets('hủy lời mời: xác nhận rồi gọi DELETE đúng path', (tester) async {
    final adapter = inviteAdapter();
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
