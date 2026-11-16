import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/presentation/screens/i2_create_group_screen.dart';
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
      child:
          router != null ? MaterialApp.router(routerConfig: router) : const MaterialApp(home: I2CreateGroupScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('thiếu tên thì báo lỗi, không gọi API', (tester) async {
    var posts = 0;
    final adapter = RouteAdapter((o) {
      if (o.method == 'POST') posts++;
      return respondFixture('groups');
    });
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('submit-create-group')));
    await tester.pumpAndSettle();

    expect(posts, 0);
    expect(find.text('Vui lòng nhập tên nhóm'), findsOneWidget);
  });

  testWidgets('nhập tên + chọn loại "Khác" thì gọi POST đúng dữ liệu rồi vào thẳng I3', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.method == 'POST') return respondJson({'success': true, 'data': (fixtureData('groups') as List)[0]});
      return respondFixture('groups');
    });
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const I2CreateGroupScreen()),
      GoRoute(path: '/group-detail', builder: (_, state) => Text('GROUP_DETAIL ${state.extra}')),
    ]);
    await pumpScreen(tester, adapter, router: router);

    await tester.enterText(find.byKey(const ValueKey('group-name-field')), 'Nhóm mới');
    await tester.tap(find.byKey(const ValueKey('group-type-Other')));
    await tester.tap(find.byKey(const ValueKey('submit-create-group')));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'POST');
    expect(req.data, {'name': 'Nhóm mới', 'type': 'Other'});
    final created = (fixtureData('groups') as List)[0] as Map<String, dynamic>;
    expect(find.text('GROUP_DETAIL ${created['id']}'), findsOneWidget);
  });
}
