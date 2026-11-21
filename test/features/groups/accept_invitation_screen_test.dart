import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/accounts/domain/financial_account.dart';
import 'package:finmate/features/accounts/presentation/controllers/accounts_controller.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/group_invitations_repository.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/presentation/screens/accept_invitation_screen.dart';
import '../../fixtures/fixture.dart';

class _MockAccounts extends StateNotifier<AsyncValue<List<FinancialAccount>>> implements AccountsController {
  _MockAccounts(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _richPreview() => {
      'groupName': 'Phòng trọ 302',
      'groupType': 'Roommates',
      'role': 'Member',
      'invitedBy': 'Minh',
      'expiresAt': '2026-11-27T10:18:42+00:00',
      'groupIcon': 'house',
      'memberCount': 4,
      'fundBalanceCents': 12800000,
      'invitedByRole': 'Owner',
      'message': 'Vào nhóm chia tiền phòng nhé!',
    };

List<FinancialAccount> _accounts() =>
    (fixtureData('accounts') as List).map((e) => FinancialAccount.fromJson(e as Map<String, dynamic>)).toList();

void main() {
  /// Điều hướng theo path: preview/accept/decline/accounts, còn lại là danh sách nhóm.
  RouteAdapter makeAdapter({Map<String, dynamic>? preview}) => RouteAdapter((o) {
        if (o.path.endsWith('/group-invitations/preview')) return respondJson({'success': true, 'data': preview ?? _richPreview()});
        if (o.path.endsWith('/group-invitations/accept')) return respondJson({'success': true, 'data': {'groupId': 'g1'}});
        if (o.path.endsWith('/group-invitations/decline')) return respondJson({'success': true, 'data': {'groupId': 'g1', 'declinedAt': '2026-11-20T10:00:00+00:00'}});
        if (o.path.contains('/accounts')) return respondFixture('accounts');
        return respondFixture('groups');
      });

  Future<void> pumpScreen(WidgetTester tester, RouteAdapter adapter, {GoRouter? router}) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = testApiClient(adapter);
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      apiClientProvider.overrideWithValue(api),
      accountsControllerProvider.overrideWith((ref) => _MockAccounts(AsyncValue.data(_accounts()))),
      groupInvitationsRepositoryProvider.overrideWithValue(GroupInvitationsRepository(apiClient: api)),
      groupsRepositoryProvider.overrideWithValue(GroupsRepository(apiClient: api)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: router != null ? MaterialApp.router(routerConfig: router) : const MaterialApp(home: AcceptInvitationScreen()),
    ));
    await tester.pumpAndSettle();
  }

  test('extractInvitationToken lấy token từ link finmate.app/join/<token>, giữ nguyên mã trần', () {
    expect(extractInvitationToken('https://finmate.app/join/abc-123_X'), 'abc-123_X');
    expect(extractInvitationToken('  tok-123  '), 'tok-123');
  });

  testWidgets('xem trước: gửi token, hiện nhóm, vai trò, người mời, quỹ chung và lời nhắn', (tester) async {
    final adapter = makeAdapter();
    await pumpScreen(tester, adapter);

    await tester.enterText(find.byKey(const ValueKey('invitation-token')), 'tok-123');
    await tester.tap(find.byKey(const ValueKey('preview-invitation')));
    await tester.pumpAndSettle();

    final req = adapter.to('/group-invitations/preview').single;
    expect(req.data, {'token': 'tok-123'});
    expect(find.text('Phòng trọ 302'), findsOneWidget);
    expect(find.textContaining('Vai trò: Thành viên'), findsOneWidget);
    expect(find.textContaining('Minh (Trưởng nhóm) đã mời bạn tham gia'), findsOneWidget);
    expect(find.text('QUỸ CHUNG HIỆN CÓ'), findsOneWidget);
    expect(find.textContaining('Vào nhóm chia tiền phòng nhé!'), findsOneWidget);
    expect(find.textContaining('4 thành viên hiện tại'), findsOneWidget);
    expect(find.byKey(const ValueKey('accept-invitation')), findsOneWidget);
    expect(find.byKey(const ValueKey('decline-invitation')), findsOneWidget);
  });

  testWidgets('dán cả link finmate.app/join/<token> thì chỉ gửi phần token', (tester) async {
    final adapter = makeAdapter();
    await pumpScreen(tester, adapter);

    await tester.enterText(find.byKey(const ValueKey('invitation-token')), 'https://finmate.app/join/tok-777');
    await tester.tap(find.byKey(const ValueKey('preview-invitation')));
    await tester.pumpAndSettle();

    expect(adapter.to('/group-invitations/preview').single.data, {'token': 'tok-777'});
  });

  testWidgets('tham gia nhóm: gửi token + ví mặc định đã chọn rồi điều hướng tới chi tiết nhóm', (tester) async {
    final adapter = makeAdapter();
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const AcceptInvitationScreen()),
      GoRoute(path: '/group-detail', builder: (_, state) => Text('GROUP_DETAIL ${state.extra}')),
    ]);
    await pumpScreen(tester, adapter, router: router);

    await tester.enterText(find.byKey(const ValueKey('invitation-token')), 'tok-123');
    await tester.tap(find.byKey(const ValueKey('preview-invitation')));
    await tester.pumpAndSettle();

    final accounts = (fixtureData('accounts') as List).cast<Map<String, dynamic>>();
    await tester.tap(find.byKey(ValueKey('wallet-${accounts.first['id']}')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('accept-invitation')));
    // Vài khoảng rất ngắn để accept() hoàn tất và điều hướng diễn ra, nhưng vẫn ngắn hơn thời gian SnackBar tự ẩn.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final req = adapter.to('/group-invitations/accept').single;
    expect(req.data, {'token': 'tok-123', 'defaultFinancialAccountId': accounts.first['id']});
    expect(find.text('Đã tham gia nhóm'), findsOneWidget);
    expect(find.text('GROUP_DETAIL g1'), findsOneWidget);
  });

  testWidgets('từ chối lời mời: xác nhận rồi gọi POST decline với token và đóng màn', (tester) async {
    final adapter = makeAdapter();
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('HOME'))),
      GoRoute(path: '/accept-invitation', builder: (_, __) => const AcceptInvitationScreen()),
    ]);
    await pumpScreen(tester, adapter, router: router);
    router.push('/accept-invitation');
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('invitation-token')), 'tok-123');
    await tester.tap(find.byKey(const ValueKey('preview-invitation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('decline-invitation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Từ chối').last);
    await tester.pumpAndSettle();

    expect(adapter.to('/group-invitations/decline').single.data, {'token': 'tok-123'});
    expect(adapter.to('/group-invitations/accept'), isEmpty);
    expect(find.text('HOME'), findsOneWidget);
  });
}
