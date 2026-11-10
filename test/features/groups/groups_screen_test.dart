import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/groups/data/groups_repository.dart';
import 'package:finmate/features/groups/presentation/screens/groups_screen.dart';
import '../../fixtures/fixture.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, RouteAdapter adapter) async {
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      groupsRepositoryProvider.overrideWithValue(GroupsRepository(apiClient: testApiClient(adapter))),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: GroupsScreen()),
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

  testWidgets('tạo nhóm: thiếu tên thì báo lỗi, không gọi API', (tester) async {
    var posts = 0;
    final adapter = RouteAdapter((o) {
      if (o.method == 'POST') posts++;
      return respondFixture('groups');
    });
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('add-group')));
    await tester.pumpAndSettle();
    expect(find.text('Tạo nhóm'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo'));
    await tester.pumpAndSettle();

    expect(posts, 0);
    expect(find.text('Vui lòng nhập tên nhóm'), findsOneWidget);
  });

  testWidgets('tạo nhóm: nhập tên hợp lệ thì gọi POST với type mặc định Family', (tester) async {
    final adapter = RouteAdapter((o) {
      if (o.method == 'POST') return respondJson({'success': true, 'data': (fixtureData('groups') as List)[0]});
      return respondFixture('groups');
    });
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('add-group')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Tên nhóm (ví dụ: Gia đình, Quỹ phòng trọ)'), 'Nhóm mới');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo'));
    await tester.pumpAndSettle();

    final req = adapter.requests.firstWhere((r) => r.method == 'POST');
    expect(req.data, {'name': 'Nhóm mới', 'type': 'Family'});
    expect(find.text('Đã tạo nhóm'), findsOneWidget);
  });
}
