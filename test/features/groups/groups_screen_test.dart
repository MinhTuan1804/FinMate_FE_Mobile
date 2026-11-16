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
    expect(find.text('Chủ nhóm'), findsOneWidget);
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
}
