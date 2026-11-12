import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/data/categories_repository.dart';
import 'package:finmate/features/categories/presentation/screens/categories_screen.dart';
import '../../fixtures/fixture.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, RouteAdapter adapter) async {
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      categoriesRepositoryProvider.overrideWithValue(CategoriesRepository(apiClient: testApiClient(adapter))),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CategoriesScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('hiện danh sách danh mục, không có nút sửa/xóa cho danh mục hệ thống', (tester) async {
    final adapter = RouteAdapter((o) => respondFixture('categories'));
    await pumpScreen(tester, adapter);

    await tester.scrollUntilVisible(find.text('Ăn uống'), 100);
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.text('Danh mục hệ thống'), findsWidgets);
    expect(find.byKey(const ValueKey('delete-412878cb-aced-4b3f-a2c9-637838245e6f')), findsNothing);
  });

  testWidgets('bấm + rồi nhập tên gọi POST tạo danh mục', (tester) async {
    var posts = 0;
    final adapter = RouteAdapter((o) {
      if (o.method == 'POST') {
        posts++;
        final created = {...(fixtureData('categories') as List)[0] as Map<String, dynamic>, 'id': 'new-1', 'name': 'Thú cưng', 'isSystem': false};
        return respondJson({'success': true, 'data': created});
      }
      return respondFixture('categories');
    });
    await pumpScreen(tester, adapter);

    await tester.tap(find.byKey(const ValueKey('add-category')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Thú cưng');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(posts, 1);
  });

  testWidgets('xóa danh mục tùy chỉnh: xác nhận rồi gọi DELETE', (tester) async {
    var deletes = 0;
    final custom = {...(fixtureData('categories') as List)[0] as Map<String, dynamic>, 'id': 'custom-1', 'name': 'Thú cưng', 'isSystem': false};
    final adapter = RouteAdapter((o) {
      if (o.method == 'GET') {
        return respondJson({'success': true, 'data': [...(fixtureData('categories') as List), custom]});
      }
      deletes++;
      return respondJson({'success': true, 'data': null});
    });
    await pumpScreen(tester, adapter);

    await tester.scrollUntilVisible(find.byKey(const ValueKey('delete-custom-1')), 100);
    await tester.tap(find.byKey(const ValueKey('delete-custom-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa').last);
    await tester.pumpAndSettle();

    expect(deletes, 1);
  });
}
