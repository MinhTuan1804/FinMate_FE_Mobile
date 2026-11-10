import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/group_invitations_repository.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/presentation/screens/accept_invitation_screen.dart';
import '../../fixtures/fixture.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, RouteAdapter adapter, {GoRouter? router}) async {
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      groupInvitationsRepositoryProvider.overrideWithValue(GroupInvitationsRepository(apiClient: testApiClient(adapter))),
      groupsRepositoryProvider.overrideWithValue(GroupsRepository(apiClient: testApiClient(adapter))),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: router != null
          ? MaterialApp.router(routerConfig: router)
          : const MaterialApp(home: AcceptInvitationScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('xem trước: gửi token, hiện tên nhóm/vai trò/người mời', (tester) async {
    final adapter = RouteAdapter((o) => respondFixture('group_invitation_preview'));
    await pumpScreen(tester, adapter);

    await tester.enterText(find.byKey(const ValueKey('invitation-token')), 'tok-123');
    await tester.tap(find.byKey(const ValueKey('preview-invitation')));
    await tester.pumpAndSettle();

    final req = adapter.requests.single;
    expect(req.path, '/api/v1/group-invitations/preview');
    expect(req.data, {'token': 'tok-123'});
    expect(find.text('Gia đình'), findsOneWidget);
    expect(find.textContaining('Vai trò: Thành viên'), findsOneWidget);
    expect(find.textContaining('Được mời bởi: Người dùng A'), findsOneWidget);
    expect(find.byKey(const ValueKey('accept-invitation')), findsOneWidget);
  });

  testWidgets('tham gia nhóm: gọi accept rồi điều hướng tới chi tiết nhóm', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.path.contains('/accept')) return respondJson({'success': true, 'data': {'groupId': 'g1'}});
      if (o.path.contains('/preview')) return respondFixture('group_invitation_preview');
      return respondFixture('groups');
    });
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const AcceptInvitationScreen()),
      GoRoute(path: '/group-detail', builder: (_, state) => Text('GROUP_DETAIL ${state.extra}')),
    ]);
    await pumpScreen(tester, adapter, router: router);

    await tester.enterText(find.byKey(const ValueKey('invitation-token')), 'tok-123');
    await tester.tap(find.byKey(const ValueKey('preview-invitation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('accept-invitation')));
    // Vài khoảng rất ngắn để accept() (gọi API bất đồng bộ) hoàn tất và điều hướng diễn ra,
    // nhưng vẫn ngắn hơn hẳn thời gian SnackBar tự ẩn (mặc định ~4s) để còn bắt được text.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final req = adapter.requests.firstWhere((r) => r.path.contains('/accept'));
    expect(req.data, {'token': 'tok-123'});
    expect(find.text('Đã tham gia nhóm'), findsOneWidget);
    expect(find.text('GROUP_DETAIL g1'), findsOneWidget);
  });
}
