import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/presentation/screens/i7_group_settings_screen.dart';
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
          : MaterialApp(home: I7GroupSettingsScreen(groupId: groupId)),
    ));
    await tester.pumpAndSettle();
  }

  GoRouter routerFor(String groupId) => GoRouter(initialLocation: '/group-settings', routes: [
        GoRoute(path: '/group-settings', builder: (_, __) => I7GroupSettingsScreen(groupId: groupId)),
        GoRoute(path: '/group-members', builder: (_, state) => Scaffold(body: Text('I4 ${state.extra}'))),
      ]);

  /// Mô phỏng đúng stack thật I1 (`/`) → I3 (`/group-detail`) → I7 (`/group-settings`) — _dissolve/_leave
  /// gọi `context.pop()` 2 lần để quay thẳng về I1, nên cần 2 route bên dưới mới pop được như thật.
  GoRouter stackRouterFor(String groupId) => GoRouter(initialLocation: '/group-detail/group-settings', routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('I1')),
          routes: [
            GoRoute(
              path: 'group-detail',
              builder: (_, __) => const Scaffold(body: Text('I3')),
              routes: [
                GoRoute(path: 'group-settings', builder: (_, __) => I7GroupSettingsScreen(groupId: groupId)),
              ],
            ),
          ],
        ),
      ]);

  /// [hasFund] false = nhóm chưa có quỹ chung (`GET /funds` trả rỗng).
  RouteAdapter settingsAdapter({Map<String, dynamic>? groupOverride, bool hasFund = true}) => RouteAdapter((o) {
        if (o.method == 'POST' && o.path.contains('/funds')) {
          return respondJson({'success': true, 'data': (fixtureData('group_funds') as List).first});
        }
        if (o.path.contains('/funds')) {
          return hasFund ? respondFixture('group_funds') : respondJson({'success': true, 'data': []});
        }
        // Danh sách nhóm (gọi lại sau khi xóa/rời nhóm trong GroupsController.load()).
        if (o.path == '/api/v1/groups') return respondFixture('groups');
        final group = groupOverride ?? (fixtureData('groups') as List)[0] as Map<String, dynamic>;
        return respondJson({'success': true, 'data': group});
      });

  testWidgets('chủ nhóm: hiện đổi tên/hiển thị giao dịch/chuyển quyền/giải tán, không có rời nhóm', (tester) async {
    await pumpScreen(tester, settingsAdapter());

    expect(find.byKey(const ValueKey('rename-group')), findsOneWidget);
    expect(find.byKey(const ValueKey('change-visibility')), findsOneWidget);
    expect(find.byKey(const ValueKey('go-transfer-ownership')), findsOneWidget);
    expect(find.byKey(const ValueKey('dissolve-group')), findsOneWidget);
    expect(find.byKey(const ValueKey('leave-group')), findsNothing);
  });

  testWidgets('thành viên thường: không có đổi tên/chuyển quyền/giải tán, chỉ có rời nhóm', (tester) async {
    final memberGroup = {...(fixtureData('groups') as List)[1] as Map<String, dynamic>};
    await pumpScreen(tester, settingsAdapter(groupOverride: memberGroup), groupId: 'g2');

    expect(find.byKey(const ValueKey('leave-group')), findsOneWidget);
    expect(find.byKey(const ValueKey('dissolve-group')), findsNothing);
    expect(find.byKey(const ValueKey('go-transfer-ownership')), findsNothing);
    final renameFinder = find.byKey(const ValueKey('rename-group'));
    expect(tester.widget<ListTile>(renameFinder).onTap, isNull);
  });

  testWidgets('đổi tên nhóm: gọi PATCH với tên mới', (tester) async {
    final adapter = settingsAdapter();
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
    final adapter = settingsAdapter();
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('toggle-alerts-off')));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'PUT');
    expect(req.path, '/api/v1/groups/g1/alerts');
    expect(req.data, {'enabled': false});
    expect(find.text('Đã tắt cảnh báo'), findsOneWidget);
  });

  testWidgets('giải tán nhóm: xác nhận rồi gọi DELETE nhóm, quay về I1', (tester) async {
    final adapter = settingsAdapter();
    await pumpScreen(tester, adapter, router: stackRouterFor('g1'));

    await tester.tap(find.byKey(const ValueKey('dissolve-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giải tán').last);
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'DELETE' && !r.path.contains('/members'));
    expect(req.path, '/api/v1/groups/g1');
    expect(find.text('Đã giải tán nhóm'), findsOneWidget);
    expect(find.text('I1'), findsOneWidget);
  });

  testWidgets('giải tán nhóm: quỹ chưa tất toán báo lỗi rõ ràng, không rời màn', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.method == 'DELETE' && o.path == '/api/v1/groups/g1') {
        return respondJson(
          {'success': false, 'data': null, 'error': {'code': 'GROUP_FUND_NOT_SETTLED', 'message': 'Quỹ chưa tất toán'}},
          status: 422,
        );
      }
      if (o.path.contains('/funds')) return respondFixture('group_funds');
      final group = (fixtureData('groups') as List)[0] as Map<String, dynamic>;
      return respondJson({'success': true, 'data': group});
    });
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('dissolve-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giải tán').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('chưa về 0'), findsOneWidget);
    expect(find.byKey(const ValueKey('dissolve-group')), findsOneWidget);
  });

  testWidgets('rời nhóm: xác nhận rồi gọi POST leave, quay về I1', (tester) async {
    final memberGroup = {...(fixtureData('groups') as List)[1] as Map<String, dynamic>};
    final adapter = settingsAdapter(groupOverride: memberGroup, hasFund: false);
    await pumpScreen(tester, adapter, groupId: 'g2', router: stackRouterFor('g2'));

    await tester.tap(find.byKey(const ValueKey('leave-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rời nhóm').last);
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.path.contains('/leave'));
    expect(req.path, '/api/v1/groups/g2/leave');
    expect(find.text('Đã rời nhóm'), findsOneWidget);
    expect(find.text('I1'), findsOneWidget);
  });

  testWidgets('chuyển giao vai trò Trưởng nhóm: điều hướng sang I4', (tester) async {
    await pumpScreen(tester, settingsAdapter(), router: routerFor('g1'));

    await tester.tap(find.byKey(const ValueKey('go-transfer-ownership')));
    await tester.pumpAndSettle();

    expect(find.text('I4 g1'), findsOneWidget);
  });

  testWidgets('chưa có quỹ chung: hiện nút tạo quỹ cho chủ nhóm, tạo xong gọi POST funds', (tester) async {
    final adapter = settingsAdapter(hasFund: false);
    await pumpScreen(tester, adapter);

    expect(find.text('Nhóm chưa có quỹ chung nào.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('create-fund')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('create-fund-name')), 'Quỹ chung');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo quỹ'));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'POST' && r.path.contains('/funds'));
    expect(req.path, '/api/v1/groups/g1/funds');
    expect(req.data, {'name': 'Quỹ chung'});
    expect(find.text('Đã tạo quỹ chung'), findsOneWidget);
  });

  testWidgets('thành viên thường (không có ManageFunds): chưa có quỹ thì không thấy nút tạo quỹ', (tester) async {
    final memberGroup = {...(fixtureData('groups') as List)[1] as Map<String, dynamic>};
    await pumpScreen(tester, settingsAdapter(groupOverride: memberGroup, hasFund: false), groupId: 'g2');

    expect(find.text('Nhóm chưa có quỹ chung nào.'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-fund')), findsNothing);
  });

  testWidgets('đã có quỹ chung: hiện tên quỹ và số dư, không có nút tạo quỹ', (tester) async {
    await pumpScreen(tester, settingsAdapter(hasFund: true));

    expect(find.text('Quỹ chung'), findsOneWidget);
    expect(find.textContaining('12.850.000'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-fund')), findsNothing);
  });
}
