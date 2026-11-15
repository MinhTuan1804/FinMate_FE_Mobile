import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/categories/data/categories_repository.dart';
import 'package:finmate/features/categories/domain/category.dart';
import 'package:finmate/features/profile/presentation/screens/category_form_screen.dart';
import '../../fixtures/fixture.dart';

void main() {
  const mine = Category(id: 'm1', name: 'Cà phê', slug: 'ca-phe', iconName: 'coffee', isSystem: false);

  Future<RouteAdapter> pump(WidgetTester tester, {Category? editing}) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final adapter = RouteAdapter((o) {
      if (o.method == 'DELETE') return respondJson({}, status: 204);
      if (o.method == 'GET') return respondFixture('categories');
      return respondJson({'success': true, 'data': (fixtureData('categories') as List).first});
    });
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => 'u1'),
      categoriesRepositoryProvider.overrideWithValue(CategoriesRepository(apiClient: testApiClient(adapter))),
    ]);
    addTearDown(container.dispose);
    final router = GoRouter(initialLocation: '/start', routes: [
      GoRoute(path: '/start', builder: (_, __) => const Text('START')),
      GoRoute(path: '/form', builder: (_, __) => CategoryFormScreen(editing: editing)),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)));
    router.push('/form');
    await tester.pumpAndSettle();
    return adapter;
  }

  testWidgets('tạo mới: thiếu tên báo lỗi; có tên và icon thì POST đúng body rồi quay lại', (tester) async {
    final adapter = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('category-save')));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập tên danh mục.'), findsOneWidget);
    expect(adapter.requests.where((r) => r.method == 'POST'), isEmpty);

    await tester.enterText(find.byKey(const ValueKey('category-name')), '  Du lịch  ');
    await tester.tap(find.byKey(const ValueKey('icon-plane')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-save')));
    await tester.pumpAndSettle();

    final post = adapter.requests.singleWhere((r) => r.method == 'POST');
    expect(post.path, '/api/v1/categories');
    expect(post.data, {'name': 'Du lịch', 'iconName': 'plane'});
    expect(find.byType(CategoryFormScreen), findsNothing);
  });

  testWidgets('sửa: điền sẵn tên, PATCH đúng id; có nút xóa kèm xác nhận gọi DELETE', (tester) async {
    final adapter = await pump(tester, editing: mine);

    expect(find.widgetWithText(TextFormField, 'Cà phê'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('category-name')), 'Cà phê sáng');
    await tester.tap(find.byKey(const ValueKey('category-save')));
    await tester.pumpAndSettle();
    final patch = adapter.requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.path, '/api/v1/categories/m1');
    expect(patch.data, {'name': 'Cà phê sáng', 'iconName': 'coffee'});
  });

  testWidgets('xóa danh mục: hỏi xác nhận rồi gọi DELETE', (tester) async {
    final adapter = await pump(tester, editing: mine);

    await tester.ensureVisible(find.byKey(const ValueKey('category-delete')));
    await tester.tap(find.byKey(const ValueKey('category-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('không thể hoàn tác'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Xóa'));
    await tester.pumpAndSettle();

    expect(adapter.requests.singleWhere((r) => r.method == 'DELETE').path, '/api/v1/categories/m1');
    expect(find.byType(CategoryFormScreen), findsNothing);
  });

  testWidgets('tạo mới không có nút xóa', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('category-delete')), findsNothing);
  });
}
